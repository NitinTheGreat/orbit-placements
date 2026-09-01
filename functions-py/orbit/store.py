from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Protocol

from .requirements import (
    build_requirements,
    dedupe_requirements,
    merge_requirements,
    requirement_id,
)
from .slugs import slugify, unique_slug

COMPANIES = "companies"
STUDENT_STATUS = "studentCompanyStatus"
PROCESSED = "processedMessages"
BROADCASTS = "broadcastHashes"
CONFIG_DOC = "config/ingestion"


IST = timezone(timedelta(hours=5, minutes=30))


def parse_mail_datetime(value: Any) -> datetime | None:
    if value is None or isinstance(value, datetime):
        return value
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000, tz=timezone.utc)
    text = str(value).strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    for candidate in (text, f"{text}T00:00:00"):
        try:
            parsed = datetime.fromisoformat(candidate)
        except ValueError:
            continue
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=IST)
        return parsed.astimezone(timezone.utc)
    return None


def status_doc_id(student_id: str, company_id: str) -> str:
    return f"{student_id}_{company_id}"


def resolve_current_round_id(
    history: list[dict[str, Any]], rounds: list[dict[str, Any]]
) -> str | None:
    order_by_id = {r["id"]: r.get("order", 0) for r in rounds}
    best_id: str | None = None
    best_order: int | None = None
    for entry in history:
        if entry.get("result") == "rejected":
            continue
        round_id = entry.get("roundId")
        if round_id not in order_by_id:
            continue
        order = order_by_id[round_id]
        if best_order is None or order > best_order:
            best_order = order
            best_id = round_id
    return best_id


def resolve_overall_status(
    history: list[dict[str, Any]], rounds: list[dict[str, Any]]
) -> str:
    if any(entry.get("result") == "rejected" for entry in history):
        return "rejected"
    if rounds:
        final = max(rounds, key=lambda r: r.get("order", 0))
        for entry in history:
            if entry.get("roundId") == final["id"] and entry.get("result") == "cleared":
                return "selected"
    return "active"


def merge_round_history(
    history: list[dict[str, Any]],
    round_id: str,
    result: str,
    message_id: str,
    now: datetime,
) -> list[dict[str, Any]]:
    merged = [dict(entry) for entry in history]
    for entry in merged:
        if entry.get("roundId") == round_id:
            entry["result"] = result
            entry["updatedAt"] = now
            entry["sourceMessageId"] = message_id
            return merged
    merged.append(
        {
            "roundId": round_id,
            "result": result,
            "updatedAt": now,
            "sourceMessageId": message_id,
        }
    )
    return merged


def merge_rounds(
    existing: list[dict[str, Any]], name: str, round_type: str, now: datetime
) -> tuple[list[dict[str, Any]], str, bool]:
    target = slugify(name)
    for entry in existing:
        if entry.get("id") == target or entry.get("name", "").lower() == name.lower():
            return existing, entry["id"], False
    rounds = [dict(entry) for entry in existing]
    round_id = unique_slug(name, [r.get("id", "") for r in rounds])
    next_order = max((r.get("order", 0) for r in rounds), default=0) + 1
    rounds.append(
        {
            "id": round_id,
            "name": name,
            "order": next_order,
            "type": round_type or "other",
            "announcedAt": now,
        }
    )
    return rounds, round_id, True


class Clock(Protocol):
    def __call__(self) -> datetime: ...


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


@dataclass
class Deps:
    store: Any
    gmail: Any
    extractor: Any
    now: Clock = utc_now
