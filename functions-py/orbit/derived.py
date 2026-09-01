from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Iterable

ACTIONABLE_STATUSES = ("registration_open", "in_progress")


def required_ids(requirements: Iterable[dict[str, Any]]) -> list[str]:
    return [
        r["id"]
        for r in requirements
        if r.get("id") and r.get("required", False)
    ]


def application_complete(
    requirements: Iterable[dict[str, Any]], completed_ids: Iterable[str]
) -> bool:
    completed = set(completed_ids or [])
    return all(rid in completed for rid in required_ids(requirements))


def completed_required_count(
    requirements: Iterable[dict[str, Any]], completed_ids: Iterable[str]
) -> tuple[int, int]:
    ids = required_ids(requirements)
    completed = set(completed_ids or [])
    return sum(1 for rid in ids if rid in completed), len(ids)


def deadline_in_future(deadline: Any, now: datetime | None = None) -> bool:
    if deadline is None:
        return False
    reference = now or datetime.now(timezone.utc)
    if isinstance(deadline, (int, float)):
        deadline = datetime.fromtimestamp(deadline / 1000, tz=timezone.utc)
    if isinstance(deadline, str):
        try:
            deadline = datetime.fromisoformat(deadline)
        except ValueError:
            return False
    if deadline.tzinfo is None:
        deadline = deadline.replace(tzinfo=timezone.utc)
    if reference.tzinfo is None:
        reference = reference.replace(tzinfo=timezone.utc)
    return deadline > reference


def action_needed(
    *,
    opted_in: bool | None,
    complete: bool,
    status: str,
    registration_deadline: Any,
    now: datetime | None = None,
) -> bool:
    if opted_in is False:
        return False
    if complete:
        return False
    if status not in ACTIONABLE_STATUSES:
        return False
    return deadline_in_future(registration_deadline, now)
