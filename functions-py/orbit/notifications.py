from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Iterable

from .derived import action_needed, application_complete, deadline_in_future

TRIGGER_ACTION_NEEDED = "action_needed"
TRIGGER_DEADLINE_HOUR = "deadline_hour"
TRIGGER_ROUND_RESULT = "round_result"
TRIGGER_NEW_ROUND = "new_round"
TRIGGER_NEW_COMPANY = "new_company"

NOTIFIED_RESULTS = ("cleared", "rejected", "not_listed")
URGENT_WINDOW = timedelta(hours=1)

CHANNEL_DEFAULT = "orbit_updates"
CHANNEL_URGENT = "orbit_deadlines"


@dataclass(frozen=True)
class Notification:
    trigger: str
    key: str
    title: str
    body: str
    company_id: str
    urgent: bool = False


def _as_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000, tz=timezone.utc)
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value)
        except ValueError:
            return None
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    return None


def _deadline_stamp(company: dict[str, Any] | None) -> str:
    moment = _as_datetime((company or {}).get("registrationDeadline"))
    return "none" if moment is None else str(int(moment.timestamp()))


def outstanding_required_ids(
    company: dict[str, Any] | None, status: dict[str, Any] | None
) -> list[str]:
    completed = set((status or {}).get("completedRequirementIds") or [])
    return sorted(
        r["id"]
        for r in (company or {}).get("requirements", [])
        if r.get("id") and r.get("required", False) and r["id"] not in completed
    )


def needs_action(
    company: dict[str, Any] | None,
    status: dict[str, Any] | None,
    now: datetime,
) -> bool:
    if company is None:
        return False
    return action_needed(
        opted_in=(status or {}).get("optedIn"),
        complete=application_complete(
            company.get("requirements", []),
            (status or {}).get("completedRequirementIds") or [],
        ),
        status=company.get("status", "registration_open"),
        registration_deadline=company.get("registrationDeadline"),
        now=now,
    )


def _closes_within_the_hour(company: dict[str, Any] | None, now: datetime) -> bool:
    deadline = _as_datetime((company or {}).get("registrationDeadline"))
    if deadline is None:
        return False
    if not deadline_in_future(deadline, now):
        return False
    return deadline - now <= URGENT_WINDOW


def _history_by_round(status: dict[str, Any] | None) -> dict[str, str]:
    entries = (status or {}).get("roundHistory") or []
    return {
        entry["roundId"]: entry.get("result")
        for entry in entries
        if entry.get("roundId")
    }


def _round_name(company: dict[str, Any] | None, round_id: str) -> str:
    for entry in (company or {}).get("rounds", []):
        if entry.get("id") == round_id:
            return entry.get("name") or "the next round"
    return "the next round"


def _company_name(*companies: dict[str, Any] | None) -> str:
    for company in companies:
        name = (company or {}).get("name")
        if name:
            return name
    return "A drive"


def _result_copy(name: str, round_name: str, result: str) -> tuple[str, str]:
    if result == "cleared":
        return (f"{name}: you are through", f"You cleared {round_name}.")
    if result == "rejected":
        return (f"{name}: not selected", f"The {round_name} result is out.")
    return (f"{name}: not shortlisted", f"You are not on the {round_name} list.")


def plan_new_company(
    company: dict[str, Any] | None, now: datetime
) -> list[Notification]:
    if company is None:
        return []
    if company.get("status") in ("closed", "results_declared"):
        return []

    company_id = company.get("id") or ""
    name = _company_name(company)
    deadline = _as_datetime(company.get("registrationDeadline"))
    if deadline is not None and not deadline_in_future(deadline, now):
        return []

    return [
        Notification(
            trigger=TRIGGER_NEW_COMPANY,
            key=f"{TRIGGER_NEW_COMPANY}:{company_id}",
            title=f"{name} just opened",
            body=(
                "A new drive landed in your placement mail."
                if deadline is None
                else "A new drive landed. Check what it needs from you."
            ),
            company_id=company_id,
        )
    ]


def plan_notifications(
    *,
    before_status: dict[str, Any] | None,
    after_status: dict[str, Any] | None,
    before_company: dict[str, Any] | None,
    after_company: dict[str, Any] | None,
    now: datetime,
) -> list[Notification]:
    company_id = (after_company or before_company or {}).get("id") or ""
    name = _company_name(after_company, before_company)
    planned: list[Notification] = []

    if (after_status or {}).get("optedIn") is False:
        return planned

    was = needs_action(before_company, before_status, now)
    is_now = needs_action(after_company, after_status, now)

    if is_now and not was:
        outstanding = outstanding_required_ids(after_company, after_status)
        count = len(outstanding)
        planned.append(
            Notification(
                trigger=TRIGGER_ACTION_NEEDED,
                key=f"{TRIGGER_ACTION_NEEDED}:{'|'.join(outstanding)}",
                title=f"{name} needs you",
                body=(
                    "One step left before the deadline."
                    if count == 1
                    else f"{count} steps left before the deadline."
                ),
                company_id=company_id,
            )
        )

    if is_now and _closes_within_the_hour(after_company, now):
        planned.append(
            Notification(
                trigger=TRIGGER_DEADLINE_HOUR,
                key=f"{TRIGGER_DEADLINE_HOUR}:{_deadline_stamp(after_company)}",
                title=f"{name} closes within the hour",
                body="Your registration is still unfinished.",
                company_id=company_id,
                urgent=True,
            )
        )

    before_history = _history_by_round(before_status)
    after_history = _history_by_round(after_status)

    for round_id, result in after_history.items():
        if result not in NOTIFIED_RESULTS:
            continue
        if before_history.get(round_id) == result:
            continue
        round_name = _round_name(after_company or before_company, round_id)
        title, body = _result_copy(name, round_name, result)
        planned.append(
            Notification(
                trigger=TRIGGER_ROUND_RESULT,
                key=f"{TRIGGER_ROUND_RESULT}:{round_id}:{result}",
                title=title,
                body=body,
                company_id=company_id,
            )
        )

    after_round = (after_status or {}).get("currentRoundId")
    before_round = (before_status or {}).get("currentRoundId")
    if after_round and after_round != before_round and after_round not in before_history:
        planned.append(
            Notification(
                trigger=TRIGGER_NEW_ROUND,
                key=f"{TRIGGER_NEW_ROUND}:{after_round}",
                title=f"{name}: {_round_name(after_company, after_round)}",
                body="A new round is on your timeline.",
                company_id=company_id,
            )
        )

    return planned


def undelivered(
    planned: Iterable[Notification], already_sent: Iterable[str]
) -> list[Notification]:
    seen = set(already_sent or [])
    fresh: list[Notification] = []
    for notification in planned:
        if notification.key in seen:
            continue
        seen.add(notification.key)
        fresh.append(notification)
    return fresh
