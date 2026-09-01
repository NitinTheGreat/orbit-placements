from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Protocol

from .slugs import slugify, unique_slug

COMPANIES = "companies"
STUDENT_STATUS = "studentCompanyStatus"
PROCESSED = "processedMessages"
BROADCASTS = "broadcastHashes"
CONFIG_DOC = "config/ingestion"


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


def build_requirements(raw: list[dict[str, Any]]) -> list[dict[str, Any]]:
    requirements: list[dict[str, Any]] = []
    for item in raw:
        label = (item.get("label") or "").strip()
        if not label:
            continue
        requirement_id = unique_slug(label, [r["id"] for r in requirements])
        requirements.append(
            {
                "id": requirement_id,
                "type": item.get("type") or "other",
                "label": label,
                "url": item.get("url"),
                "required": bool(item.get("required", True)),
            }
        )
    return requirements


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
