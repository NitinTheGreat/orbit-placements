from __future__ import annotations

import base64
import json
import os
from datetime import datetime, timedelta, timezone

import firebase_admin
from firebase_admin import firestore as admin_firestore
from firebase_functions import https_fn, options, pubsub_fn
from firebase_functions.params import SecretParam, StringParam

from orbit.extraction import AnthropicExtractor
from orbit.firestore_store import FirestoreStore
from orbit.gmail_client import GmailClient, build_service
from orbit.graph import build_graph
from orbit.state import IngestionState
from orbit.store import Deps, utc_now

GMAIL_OAUTH_CLIENT_ID = StringParam("GMAIL_OAUTH_CLIENT_ID")
GMAIL_PUBSUB_TOPIC = StringParam("GMAIL_PUBSUB_TOPIC")
GMAIL_OAUTH_CLIENT_SECRET = SecretParam("GMAIL_OAUTH_CLIENT_SECRET")
ANTHROPIC_API_KEY = SecretParam("ANTHROPIC_API_KEY")

ALLOWED_EMAIL_DOMAIN = "@vitstudent.ac.in"
SYNC_COOLDOWN_SECONDS = 30
DEFAULT_CUTOFF_ISO = "2026-01-01T00:00:00+00:00"

firebase_admin.initialize_app()

_cutoff_ms: int | None = None


def _store() -> FirestoreStore:
    return FirestoreStore(admin_firestore.client())


def _cutoff(store: FirestoreStore) -> int:
    global _cutoff_ms
    if _cutoff_ms is None:
        raw = (store.get_config() or {}).get("cutoffDate")
        if isinstance(raw, datetime):
            parsed = raw
        else:
            parsed = datetime.fromisoformat(str(raw or DEFAULT_CUTOFF_ISO))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        _cutoff_ms = int(parsed.timestamp() * 1000)
    return _cutoff_ms


def _identifiers(student: dict) -> list[str]:
    values = [student.get("neoId"), student.get("regNo")]
    return [v for v in values if v]


def _run_for_messages(
    store: FirestoreStore,
    gmail: GmailClient,
    student_id: str,
    student: dict,
    message_ids: list[str],
) -> dict[str, int]:
    deps = Deps(
        store=store,
        gmail=gmail,
        extractor=AnthropicExtractor(),
        now=utc_now,
    )
    graph = build_graph(deps)
    cutoff = _cutoff(store)
    identifiers = _identifiers(student)
    counts = {"processed": 0, "skipped": 0, "written": 0}

    for message_id in message_ids:
        if store.is_processed(message_id):
            counts["skipped"] += 1
            continue

        metadata = gmail.get_metadata(message_id)
        state: IngestionState = {
            "student_id": student_id,
            "student_identifiers": identifiers,
            "message_id": message_id,
            "sender": metadata["sender"],
            "subject": metadata["subject"],
            "internal_date_ms": metadata["internal_date_ms"],
            "cutoff_ms": cutoff,
        }
        result = graph.invoke(state)
        outcome = result.get("halt_reason") or "written"
        if outcome == "written":
            counts["written"] += 1
        store.mark_processed(message_id, student_id, outcome)
        counts["processed"] += 1

    return counts


def _gmail_for(store: FirestoreStore, student_id: str) -> GmailClient | None:
    token_doc = (
        admin_firestore.client()
        .collection("gmailTokens")
        .document(student_id)
        .get()
    )
    if not token_doc.exists:
        return None
    refresh_token = (token_doc.to_dict() or {}).get("refreshToken")
    if not refresh_token:
        return None
    service = build_service(
        refresh_token,
        GMAIL_OAUTH_CLIENT_ID.value(),
        GMAIL_OAUTH_CLIENT_SECRET.value(),
    )
    return GmailClient(service)


def _collect_message_ids(
    gmail: GmailClient, store: FirestoreStore, student_id: str, student: dict
) -> tuple[list[str], str | None]:
    history_id = (student.get("gmailSync") or {}).get("historyId")
    if history_id:
        try:
            return gmail.list_new_message_ids(str(history_id))
        except Exception:
            pass
    after = int((utc_now() - timedelta(days=7)).timestamp())
    return gmail.scan_recent_message_ids(after)


@pubsub_fn.on_message_published(
    topic="gmail-notifications",
    secrets=[GMAIL_OAUTH_CLIENT_SECRET, ANTHROPIC_API_KEY],
    region="us-central1",
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
        return
    student_id, student = found

    gmail = _gmail_for(store, student_id)
    if gmail is None:
        return

    message_ids, latest_history_id = _collect_message_ids(
        gmail, store, student_id, student
    )
    _run_for_messages(store, gmail, student_id, student, message_ids)
    if latest_history_id:
        store.set_gmail_history_id(student_id, str(latest_history_id))


@https_fn.on_call(
    secrets=[GMAIL_OAUTH_CLIENT_SECRET, ANTHROPIC_API_KEY],
    region="us-central1",
    memory=options.MemoryOption.MB_512,
    timeout_sec=300,
)
def syncNow(req: https_fn.CallableRequest) -> dict:
    auth = req.auth
    if auth is None:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first."
        )
    email = (auth.token or {}).get("email", "")
    if not email.lower().endswith(ALLOWED_EMAIL_DOMAIN):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            f"Only {ALLOWED_EMAIL_DOMAIN} accounts can sync.",
        )

    student_id = auth.uid
    store = _store()
    student = store.get_student(student_id)
    if not student:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            "Finish onboarding before syncing.",
        )

    now = utc_now()
    last_sync = (student.get("gmailSync") or {}).get("lastSyncAt")
    if isinstance(last_sync, datetime):
        elapsed = (now - last_sync).total_seconds()
        if elapsed < SYNC_COOLDOWN_SECONDS:
            raise https_fn.HttpsError(
                https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                f"Just synced. Try again in {int(SYNC_COOLDOWN_SECONDS - elapsed)}s.",
            )

    admin_firestore.client().collection("students").document(student_id).set(
        {"gmailSync": {"lastSyncAt": now}}, merge=True
    )

    gmail = _gmail_for(store, student_id)
    if gmail is None:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            "Connect Gmail before syncing.",
        )

    message_ids, latest_history_id = _collect_message_ids(
        gmail, store, student_id, student
    )
    counts = _run_for_messages(store, gmail, student_id, student, message_ids)
    if latest_history_id:
        store.set_gmail_history_id(student_id, str(latest_history_id))

    return {"scanned": len(message_ids), **counts}
