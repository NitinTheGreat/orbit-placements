from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Iterable

from .branches import is_confident_mismatch
from .derived import action_needed, application_complete, completed_required_count

DAILY_LIMIT = 20
MAX_FREE_TEXT = 400
MAX_COMPANIES_IN_CONTEXT = 40
MAX_HISTORY_TURNS = 6
MAX_HISTORY_CHARS = 4000
MAX_STORED_ANSWER_CHARS = 1200

SYSTEM_PROMPT = (
    "You are Orbit's assistant. You answer one question about this single "
    "student's own placement drives, using only the context given below. "
    "The context is the complete set of data you have. If the context does "
    "not contain what is needed to answer, say plainly that you do not know "
    "or that Orbit has not seen it yet. Never invent a company, a deadline, "
    "a requirement, or a result. Never mention another student. Keep the "
    "answer under five sentences, in plain prose, no headings and no "
    "markdown. Refer to dates the way the context does."
)

PRESETS: dict[str, str] = {
    "due_24h": "What is due in the next 24 hours?",
    "missing_now": "What am I missing right now?",
    "changed_since_yesterday": "What has changed since yesterday?",
    "active_drives": "Which drives am I actively in?",
    "new_unreviewed": "New companies I have not reviewed",
}


class AssistantError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass(frozen=True)
class AssistantRequest:
    question: str
    preset_id: str | None


def resolve_question(
    preset_id: Any, free_text: Any
) -> AssistantRequest:
    if isinstance(preset_id, str) and preset_id:
        if preset_id not in PRESETS:
            raise AssistantError("invalid-argument", "That is not a question I know.")
        return AssistantRequest(question=PRESETS[preset_id], preset_id=preset_id)

    if isinstance(free_text, str) and free_text.strip():
        trimmed = free_text.strip()
        if len(trimmed) > MAX_FREE_TEXT:
            raise AssistantError(
                "invalid-argument", "That question is too long. Keep it short."
            )
        return AssistantRequest(question=trimmed, preset_id=None)

    raise AssistantError("invalid-argument", "Ask something first.")


def day_key(now: datetime) -> str:
    return now.astimezone(timezone.utc).strftime("%Y-%m-%d")


def within_daily_limit(usage: dict[str, Any] | None, now: datetime) -> bool:
    record = usage or {}
    if record.get("day") != day_key(now):
        return True
    return int(record.get("count", 0)) < DAILY_LIMIT


def next_usage(usage: dict[str, Any] | None, now: datetime) -> dict[str, Any]:
    record = usage or {}
    today = day_key(now)
    count = int(record.get("count", 0)) if record.get("day") == today else 0
    return {"day": today, "count": count + 1, "updatedAt": now}


def _stamp(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000, tz=timezone.utc).strftime(
            "%Y-%m-%d %H:%M UTC"
        )
    return str(value)


def _requirement_lines(
    company: dict[str, Any], completed: set[str]
) -> list[str]:
    lines = []
    for requirement in company.get("requirements", []) or []:
        rid = requirement.get("id")
        if not rid:
            continue
        state = "done" if rid in completed else "not done"
        needed = "required" if requirement.get("required") else "optional"
        label = requirement.get("label") or rid
        lines.append(f"{label} ({needed}, {state})")
    return lines


def build_context(
    *,
    student: dict[str, Any],
    companies: Iterable[dict[str, Any]],
    statuses_by_company: dict[str, dict[str, Any]],
    now: datetime,
) -> str:
    reg_no = student.get("regNo")
    blocks: list[str] = [
        f"Today is {_stamp(now)}.",
        f"The student's registration number is {reg_no or 'unknown'}.",
        "",
        "Their drives:",
    ]

    included = 0
    for company in companies:
        if included >= MAX_COMPANIES_IN_CONTEXT:
            break
        company_id = company.get("id")
        status = statuses_by_company.get(company_id) or {}

        if status.get("optedIn") is False:
            continue
        if not status and is_confident_mismatch(
            reg_no, company.get("eligibleBranches")
        ):
            continue

        included += 1
        completed = set(status.get("completedRequirementIds") or [])
        done, total = completed_required_count(
            company.get("requirements", []) or [], completed
        )
        complete = application_complete(
            company.get("requirements", []) or [], completed
        )
        needs = action_needed(
            opted_in=status.get("optedIn"),
            complete=complete,
            status=company.get("status", "registration_open"),
            registration_deadline=company.get("registrationDeadline"),
            now=now,
        )

        rounds = [
            f"{r.get('name')} (order {r.get('order')})"
            for r in company.get("rounds", []) or []
        ]
        history = [
            f"{h.get('roundId')}: {h.get('result')}"
            for h in status.get("roundHistory") or []
        ]
        requirements = _requirement_lines(company, completed)

        blocks.append(
            "\n".join(
                [
                    f"- {company.get('name') or 'Unnamed drive'}",
                    f"  drive status: {company.get('status')}",
                    f"  registration deadline: "
                    f"{_stamp(company.get('registrationDeadline')) or 'not stated'}",
                    f"  CTC: {company.get('ctc') or 'not stated'}; "
                    f"stipend: {company.get('stipend') or 'not stated'}",
                    f"  eligible branches: "
                    f"{', '.join(company.get('eligibleBranches') or []) or 'not stated'}",
                    f"  steps: {'; '.join(requirements) or 'none listed'}",
                    f"  required steps done: {done} of {total}",
                    f"  needs action from the student: {'yes' if needs else 'no'}",
                    f"  tracking: {status.get('optedIn') if status else 'not set'}",
                    f"  overall status: {status.get('overallStatus') or 'active'}",
                    f"  rounds: {'; '.join(rounds) or 'none'}",
                    f"  this student's rounds: {'; '.join(history) or 'none'}",
                    f"  first seen: {_stamp(company.get('createdAt')) or 'unknown'}",
                    f"  last updated from mail: "
                    f"{_stamp((company.get('lastUpdatedFrom') or {}).get('date')) or 'unknown'}",
                ]
            )
        )

    if included == 0:
        blocks.append("(no drives)")

    return "\n".join(blocks)


def trim_history(history: Any) -> list[dict[str, str]]:
    if not isinstance(history, list):
        return []

    turns: list[dict[str, str]] = []
    for entry in history:
        if not isinstance(entry, dict):
            continue
        asked = entry.get("question")
        replied = entry.get("answer")
        if not isinstance(asked, str) or not isinstance(replied, str):
            continue
        asked, replied = asked.strip(), replied.strip()
        if not asked or not replied:
            continue
        turns.append(
            {
                "question": asked[:MAX_FREE_TEXT],
                "answer": replied[:MAX_STORED_ANSWER_CHARS],
            }
        )

    turns = turns[-MAX_HISTORY_TURNS:]
    while (
        turns
        and sum(len(t["question"]) + len(t["answer"]) for t in turns)
        > MAX_HISTORY_CHARS
    ):
        turns.pop(0)
    return turns


def append_turn(
    history: Any, question: str, answer: str
) -> list[dict[str, str]]:
    kept = trim_history(history)
    kept.append({"question": question, "answer": answer})
    return trim_history(kept)


def render_history(history: list[dict[str, str]]) -> str:
    if not history:
        return ""
    lines = ["EARLIER IN THIS CONVERSATION"]
    for turn in history:
        lines.append(f"  the student asked: {turn['question']}")
        lines.append(f"  you answered: {turn['answer']}")
    return "\n".join(lines)


def build_prompt(
    question: str,
    context: str,
    history: list[dict[str, str]] | None = None,
) -> str:
    parts = [SYSTEM_PROMPT]
    earlier = render_history(history or [])
    if earlier:
        parts.append(
            earlier
            + "\n\nA follow-up may point back at those answers, so resolve it "
            "against them. Never treat anything above as a source of facts "
            "about drives; the CONTEXT below is the only source."
        )
    parts.append(f"CONTEXT\n{context}")
    parts.append(f"QUESTION\n{question}")
    return "\n\n".join(parts)


def recently_created(company: dict[str, Any], now: datetime) -> bool:
    created = company.get("createdAt")
    if isinstance(created, (int, float)):
        created = datetime.fromtimestamp(created / 1000, tz=timezone.utc)
    if not isinstance(created, datetime):
        return False
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)
    return now - created <= timedelta(days=3)


class GeminiAnswerer:
    def __init__(self, client=None, model: str | None = None):
        import os

        self._client = client
        self._model = model or os.environ.get(
            "ORBIT_ASSISTANT_MODEL", "gemini-3.7-flash"
        )

    def _ensure_client(self):
        if self._client is None:
            import os

            from google import genai

            self._client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))
        return self._client

    def __call__(
        self,
        question: str,
        context: str,
        history: list[dict[str, str]] | None = None,
    ) -> str:
        from google.genai import types

        client = self._ensure_client()
        response = client.models.generate_content(
            model=self._model,
            contents=build_prompt(question, context, history),
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                temperature=0.2,
                max_output_tokens=400,
                automatic_function_calling=types.AutomaticFunctionCallingConfig(
                    disable=True
                ),
            ),
        )
        text = (getattr(response, "text", None) or "").strip()
        if not text:
            raise AssistantError("internal", "No answer came back. Try again.")
        return text
