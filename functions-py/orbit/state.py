from __future__ import annotations

from typing import Any, TypedDict


class IngestionState(TypedDict, total=False):
    student_id: str
    student_identifiers: list[str]
    message_id: str
    sender: str
    subject: str
    internal_date_ms: int
    cutoff_ms: int
    allowed_sender_patterns: list[str]
    body_text: str
    hash_text: str
    body_hash: str
    attachments: list[dict[str, Any]]
    known_company_id: str | None
    extraction: dict[str, Any] | None
    company_id: str | None
    round_id: str | None
    matched: bool
    match_source: str | None
    opted_in: bool | None
    not_listed: bool
    halted_at: str | None
    halt_reason: str | None


def halt(state: IngestionState, node: str, reason: str) -> IngestionState:
    return {**state, "halted_at": node, "halt_reason": reason}
