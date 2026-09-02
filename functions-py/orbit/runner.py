from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from .config import IngestionConfig
from .graph import build_graph
from .matching import extract_addresses, sender_allowed
from .state import IngestionState
from .store import Deps

logger = logging.getLogger("orbit.runner")

SCAN_WINDOW_DAYS = 14


class TokenRevoked(Exception):
    pass


def is_revoked_error(error: Exception) -> bool:
    text = str(error).lower()
    if "invalid_grant" in text or "invalid grant" in text:
        return True
    status = getattr(getattr(error, "resp", None), "status", None)
    return status == 401


def is_missing_message_error(error: Exception) -> bool:
    status = getattr(getattr(error, "resp", None), "status", None)
    return status == 404


def is_history_too_old(error: Exception) -> bool:
    status = getattr(getattr(error, "resp", None), "status", None)
    if status == 404:
        return True
    return "startHistoryId" in str(error) and "not found" in str(error).lower()


def collect_message_ids(
    gmail: Any, config: IngestionConfig, history_id: str | None
) -> tuple[list[str], str | None, str]:
    if history_id:
        try:
            ids, latest = gmail.list_new_message_ids(str(history_id))
            return ids, latest, "history"
        except Exception as error:
            if is_revoked_error(error):
                raise TokenRevoked(str(error)) from error
            if not is_history_too_old(error):
                raise
            logger.warning(
                "historyId %s too old, falling back to a bounded scan", history_id
            )

    after = int(
        max(
            datetime.fromtimestamp(config.cutoff_ms / 1000, tz=timezone.utc),
            datetime.now(timezone.utc) - timedelta(days=SCAN_WINDOW_DAYS),
        ).timestamp()
    )
    senders = [_sender_query_term(p) for p in config.allowed_sender_patterns]
    try:
        ids, latest = gmail.scan_recent_message_ids(
            after, [s for s in senders if s]
        )
    except Exception as error:
        if is_revoked_error(error):
            raise TokenRevoked(str(error)) from error
        raise
    return ids, latest, "scan"


def _sender_query_term(pattern: str) -> str:
    literal = pattern.replace("\\.", ".").replace("\\", "")
    if any(ch in literal for ch in "[]()|+*?{}^$"):
        domain = literal.split("@")[-1]
        return domain if "@" not in domain else ""
    return literal


def build_state(
    student_id: str,
    identifiers: list[str],
    message_id: str,
    metadata: dict,
    config: IngestionConfig,
) -> IngestionState:
    return {
        "student_id": student_id,
        "student_identifiers": identifiers,
        "message_id": message_id,
        "sender": metadata.get("sender", ""),
        "subject": metadata.get("subject", ""),
        "internal_date_ms": metadata.get("internal_date_ms", 0),
        "cutoff_ms": config.cutoff_ms,
        "allowed_sender_patterns": config.allowed_sender_patterns,
    }


def run_messages(
    deps: Deps,
    config: IngestionConfig,
    student_id: str,
    identifiers: list[str],
    message_ids: list[str],
) -> dict[str, int]:
    graph = build_graph(deps)
    counts = {"processed": 0, "skipped": 0, "written": 0, "gone": 0}

    for message_id in message_ids:
        if deps.store.is_processed(message_id):
            counts["skipped"] += 1
            continue

        try:
            metadata = deps.gmail.get_metadata(message_id)
            state = build_state(student_id, identifiers, message_id, metadata, config)
            result = graph.invoke(state)
        except Exception as error:
            if is_revoked_error(error):
                raise TokenRevoked(str(error)) from error
            if not is_missing_message_error(error):
                raise
            logger.info("message %s is gone from the mailbox, skipping", message_id)
            deps.store.mark_processed(message_id, student_id, "message_gone")
            counts["gone"] += 1
            continue

        outcome = result.get("halt_reason") or "written"
        if outcome == "written":
            counts["written"] += 1
        deps.store.mark_processed(message_id, student_id, outcome)
        counts["processed"] += 1

    return counts


def dry_run(
    gmail: Any, store: Any, config: IngestionConfig, history_id: str | None
) -> dict[str, Any]:
    message_ids, _, source = collect_message_ids(gmail, config, history_id)

    counts = {
        "seen": len(message_ids),
        "passed_filter": 0,
        "rejected_sender": 0,
        "rejected_cutoff": 0,
        "already_processed": 0,
        "gone": 0,
    }
    rejected_samples: list[dict[str, str]] = []

    for message_id in message_ids:
        if store.is_processed(message_id):
            counts["already_processed"] += 1
            continue
        try:
            metadata = gmail.get_metadata(message_id)
        except Exception as error:
            if not is_missing_message_error(error):
                raise
            counts["gone"] += 1
            continue
        sender = metadata.get("sender", "")
        subject = metadata.get("subject", "")

        if metadata.get("internal_date_ms", 0) < config.cutoff_ms:
            counts["rejected_cutoff"] += 1
            reason = "before_cutoff"
        elif not sender_allowed(sender, config.allowed_sender_patterns):
            counts["rejected_sender"] += 1
            reason = "sender_not_allowed"
        else:
            counts["passed_filter"] += 1
            continue

        if len(rejected_samples) < 10:
            rejected_samples.append(
                {
                    "from": sender,
                    "addresses": ", ".join(extract_addresses(sender)),
                    "subject": subject,
                    "reason": reason,
                }
            )

    return {
        "source": source,
        "counts": counts,
        "rejected_sample": rejected_samples,
        "config": {
            "cutoff_ms": config.cutoff_ms,
            "allowed_sender_patterns": config.allowed_sender_patterns,
            "from_defaults": config.from_defaults,
        },
    }
