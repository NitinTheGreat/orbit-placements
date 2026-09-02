from __future__ import annotations

import base64
import json
import logging
from datetime import datetime
from zoneinfo import ZoneInfo

import firebase_admin
from firebase_admin import firestore as admin_firestore
from firebase_functions import (
    firestore_fn,
    https_fn,
    options,
    pubsub_fn,
    scheduler_fn,
)
from firebase_functions.params import SecretParam, StringParam

from orbit.config import IngestionConfig, load_config
from orbit.extraction import GeminiExtractor
from orbit.firestore_store import FirestoreStore
from orbit.gmail_client import GmailClient, build_service
from orbit.branches import is_confident_mismatch
from orbit.notifications import plan_new_company, plan_notifications, undelivered
from orbit.push import send as send_push
from orbit.push import send_widget_refresh
from orbit.push import student_tokens, trim_keys
from orbit.runner import (
    TokenRevoked,
    collect_message_ids,
    dry_run,
    is_revoked_error,
    run_messages,
)
from orbit.store import Deps, utc_now

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("orbit")

GMAIL_OAUTH_CLIENT_ID = StringParam("GMAIL_OAUTH_CLIENT_ID")
GMAIL_PUBSUB_TOPIC = StringParam("GMAIL_PUBSUB_TOPIC")
GMAIL_OAUTH_CLIENT_SECRET = SecretParam("GMAIL_OAUTH_CLIENT_SECRET")
GEMINI_API_KEY = SecretParam("GEMINI_API_KEY")

ALLOWED_EMAIL_DOMAIN = "@vitstudent.ac.in"
SYNC_COOLDOWN_SECONDS = 30
REGION = "us-central1"

firebase_admin.initialize_app()

_config: IngestionConfig | None = None


def _store() -> FirestoreStore:
    return FirestoreStore(admin_firestore.client())


def _ingestion_config(store: FirestoreStore) -> IngestionConfig:
    global _config
    if _config is None:
        _config = load_config(store.get_config())
    return _config


def _identifiers(student: dict) -> list[str]:
    return [v for v in (student.get("neoId"), student.get("regNo")) if v]


def _gmail_for(student_id: str) -> GmailClient | None:
    token_doc = (
        admin_firestore.client().collection("gmailTokens").document(student_id).get()
    )
    if not token_doc.exists:
        return None
    refresh_token = (token_doc.to_dict() or {}).get("refreshToken")
    if not refresh_token:
        return None
    return GmailClient(
        build_service(
            refresh_token,
            GMAIL_OAUTH_CLIENT_ID.value,
            GMAIL_OAUTH_CLIENT_SECRET.value,
        )
    )


def _deps(store: FirestoreStore, gmail: GmailClient) -> Deps:
    return Deps(
        store=store, gmail=gmail, extractor=GeminiExtractor(), now=utc_now
    )


def _needs_reconnect(store: FirestoreStore, student_id: str, reason: str) -> None:
    logger.error(
        "gmail_needs_reconnect student=%s reason=%s", student_id, reason[:200]
    )
    store.mark_needs_reconnect(student_id, reason)


def _sync_student(
    store: FirestoreStore, student_id: str, student: dict
) -> dict[str, int]:
    gmail = _gmail_for(student_id)
    if gmail is None:
        _needs_reconnect(store, student_id, "no refresh token stored")
        return {"processed": 0, "skipped": 0, "written": 0}

    config = _ingestion_config(store)
    history_id = (student.get("gmailSync") or {}).get("historyId")

    try:
        message_ids, latest_history_id, _ = collect_message_ids(
            gmail, config, history_id
        )
        counts = run_messages(
            _deps(store, gmail),
            config,
            student_id,
            _identifiers(student),
            message_ids,
        )
    except TokenRevoked as error:
        _needs_reconnect(store, student_id, str(error))
        return {"processed": 0, "skipped": 0, "written": 0}
    except Exception as error:
        if is_revoked_error(error):
            _needs_reconnect(store, student_id, str(error))
            return {"processed": 0, "skipped": 0, "written": 0}
        raise

    store.mark_synced(student_id, latest_history_id)
    return counts


@pubsub_fn.on_message_published(
    topic="gmail-notifications",
    secrets=[GMAIL_OAUTH_CLIENT_SECRET, GEMINI_API_KEY],
    region=REGION,
    memory=options.MemoryOption.MB_512,
    timeout_sec=540,
)
def ingestGmailNotification(event: pubsub_fn.CloudEvent) -> None:
    raw = event.data.message.data
    payload = json.loads(base64.b64decode(raw).decode("utf-8")) if raw else {}
    email = payload.get("emailAddress", "")
    if not email.lower().endswith(ALLOWED_EMAIL_DOMAIN):
        return

    store = _store()
    found = store.find_student_by_email(email)
    if not found:
        logger.warning("push for unknown mailbox %s", email)
        return

    student_id, student = found
    counts = _sync_student(store, student_id, student)
    logger.info("push sync student=%s counts=%s", student_id, counts)


@https_fn.on_call(
    secrets=[GMAIL_OAUTH_CLIENT_SECRET, GEMINI_API_KEY],
    region=REGION,
    memory=options.MemoryOption.MB_512,
    timeout_sec=300,
)
def syncNow(req: https_fn.CallableRequest) -> dict:
    student_id, student, store = _require_student(req)

    now = utc_now()
    last_sync = (student.get("gmailSync") or {}).get("lastSyncedAt")
    if isinstance(last_sync, datetime):
        elapsed = (now - last_sync).total_seconds()
        if elapsed < SYNC_COOLDOWN_SECONDS:
            raise https_fn.HttpsError(
                https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                f"Just checked. Try again in {int(SYNC_COOLDOWN_SECONDS - elapsed)}s.",
            )

    counts = _sync_student(store, student_id, student)
    return counts


@https_fn.on_call(
    secrets=[GMAIL_OAUTH_CLIENT_SECRET],
    region=REGION,
    memory=options.MemoryOption.MB_512,
    timeout_sec=300,
)
def dryRunFilter(req: https_fn.CallableRequest) -> dict:
    student_id, student, store = _require_student(req)

    gmail = _gmail_for(student_id)
    if gmail is None:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            "Connect Gmail before running a dry run.",
        )

    config = _ingestion_config(store)
    history_id = (student.get("gmailSync") or {}).get("historyId")
    if req.data and req.data.get("fullScan"):
        history_id = None

    return dry_run(gmail, store, config, history_id)


@scheduler_fn.on_schedule(
    schedule="every 2 hours",
    secrets=[GMAIL_OAUTH_CLIENT_SECRET, GEMINI_API_KEY],
    region=REGION,
    memory=options.MemoryOption.MB_512,
    timeout_sec=540,
)
def reconcileInboxes(event: scheduler_fn.ScheduledEvent) -> None:
    store = _store()
    students = store.connected_students()
    logger.info("reconciliation sweep over %d connected student(s)", len(students))

    for student_id, student in students:
        try:
            counts = _sync_student(store, student_id, student)
            logger.info("sweep student=%s counts=%s", student_id, counts)
        except Exception as error:
            logger.exception("sweep failed for student=%s: %s", student_id, error)


@scheduler_fn.on_schedule(
    schedule="every day 03:00",
    timezone=ZoneInfo("Asia/Kolkata"),
    secrets=[GMAIL_OAUTH_CLIENT_SECRET],
    region=REGION,
    memory=options.MemoryOption.MB_256,
    timeout_sec=540,
)
def renewGmailWatches(event: scheduler_fn.ScheduledEvent) -> None:
    store = _store()
    topic = GMAIL_PUBSUB_TOPIC.value
    students = store.connected_students()
    logger.info("renewing watches for %d connected student(s)", len(students))

    for student_id, _ in students:
        gmail = _gmail_for(student_id)
        if gmail is None:
            _needs_reconnect(store, student_id, "no refresh token stored")
            continue
        try:
            result = gmail.watch(topic)
        except Exception as error:
            if is_revoked_error(error):
                _needs_reconnect(store, student_id, str(error))
                continue
            logger.exception("watch renewal failed student=%s", student_id)
            continue

        expiration = result.get("expiration")
        if expiration:
            store.set_watch_expiration(student_id, int(expiration))
        logger.info(
            "watch renewed student=%s expiration=%s", student_id, expiration
        )


def _require_student(
    req: https_fn.CallableRequest,
) -> tuple[str, dict, FirestoreStore]:
    auth = req.auth
    if auth is None:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first."
        )
    email = (auth.token or {}).get("email", "")
    if not email.lower().endswith(ALLOWED_EMAIL_DOMAIN):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            f"Only {ALLOWED_EMAIL_DOMAIN} accounts can do this.",
        )

    store = _store()
    student = store.get_student(auth.uid)
    if not student:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            "Finish onboarding first.",
        )
    return auth.uid, student, store


def _with_id(snapshot) -> dict | None:
    if snapshot is None or not snapshot.exists:
        return None
    data = snapshot.to_dict() or {}
    data.setdefault("id", snapshot.id)
    return data


def _suppressed_for_branch(
    store: FirestoreStore, student_id: str, company: dict | None
) -> bool:
    if not company:
        return False
    student = store.get_student(student_id) or {}
    return is_confident_mismatch(
        student.get("regNo"), company.get("eligibleBranches")
    )


def _deliver(
    store: FirestoreStore,
    student_id: str,
    company_id: str,
    planned: list,
) -> None:
    if not planned:
        return

    already = store.get_notified_keys(student_id, company_id)
    fresh = undelivered(planned, already)
    if not fresh:
        return

    student = store.get_student(student_id)
    tokens = student_tokens(student)
    if not tokens:
        logger.info("notify_skipped_no_tokens student=%s company=%s", student_id, company_id)
        return

    sent, stale = send_push(tokens, fresh)
    if stale:
        store.drop_fcm_tokens(student_id, stale)
    send_widget_refresh([t for t in tokens if t not in stale])
    store.put_notified_keys(
        student_id,
        company_id,
        trim_keys(already + [n.key for n in fresh]),
        utc_now(),
    )
    logger.info(
        "notify student=%s company=%s triggers=%s sent=%s",
        student_id,
        company_id,
        [n.trigger for n in fresh],
        sent,
    )


def _notify(
    store: FirestoreStore,
    student_id: str,
    company_id: str,
    *,
    before_status: dict | None,
    after_status: dict | None,
    before_company: dict | None,
    after_company: dict | None,
) -> None:
    _deliver(
        store,
        student_id,
        company_id,
        plan_notifications(
            before_status=before_status,
            after_status=after_status,
            before_company=before_company,
            after_company=after_company,
            now=utc_now(),
        ),
    )


@firestore_fn.on_document_written(
    document="studentCompanyStatus/{statusId}",
    region=REGION,
    memory=options.MemoryOption.MB_256,
)
def notifyOnStatusChange(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot | None]],
) -> None:
    before = _with_id(event.data.before)
    after = _with_id(event.data.after)
    current = after or before
    if not current:
        return

    student_id = current.get("studentId")
    company_id = current.get("companyId")
    if not student_id or not company_id:
        return

    store = _store()
    company = store.get_company(company_id)
    if company is not None:
        company.setdefault("id", company_id)

    _notify(
        store,
        student_id,
        company_id,
        before_status=before,
        after_status=after,
        before_company=company,
        after_company=company,
    )


@firestore_fn.on_document_written(
    document="companies/{companyId}",
    region=REGION,
    memory=options.MemoryOption.MB_256,
)
def notifyOnCompanyChange(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot | None]],
) -> None:
    before = _with_id(event.data.before)
    after = _with_id(event.data.after)
    if after is None:
        return

    company_id = event.params["companyId"]
    after.setdefault("id", company_id)
    if before is not None:
        before.setdefault("id", company_id)

    is_create = before is None
    store = _store()

    for student_id in store.tracked_student_ids():
        if _suppressed_for_branch(store, student_id, after):
            logger.info(
                "notify_suppressed_off_branch student=%s company=%s",
                student_id,
                company_id,
            )
            continue

        if is_create:
            _deliver(
                store,
                student_id,
                company_id,
                plan_new_company(after, utc_now()),
            )

        status = store.get_status(student_id, company_id)
        _notify(
            store,
            student_id,
            company_id,
            before_status=status,
            after_status=status,
            before_company=before,
            after_company=after,
        )
