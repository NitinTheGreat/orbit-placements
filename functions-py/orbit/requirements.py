from __future__ import annotations

import re
from datetime import datetime
from typing import Any, Iterable

from .slugs import unique_slug

LABEL_OVERLAP_THRESHOLD = 0.6

_PUNCTUATION = re.compile(r"[^a-z0-9\s]+")

_STOPWORDS = frozenset(
    {
        "a",
        "an",
        "and",
        "are",
        "as",
        "at",
        "be",
        "by",
        "for",
        "from",
        "in",
        "is",
        "of",
        "on",
        "or",
        "the",
        "this",
        "that",
        "to",
        "with",
        "you",
        "your",
        "please",
        "kindly",
        "all",
        "students",
    }
)


def normalise_url(url: Any) -> str:
    if not url:
        return ""
    text = str(url).strip().lower()
    text = text.split("#", 1)[0].split("?", 1)[0]
    return text.rstrip("/")


def label_tokens(label: Any) -> set[str]:
    text = _PUNCTUATION.sub(" ", str(label or "").lower())
    return {
        token
        for token in text.split()
        if len(token) > 1 and token not in _STOPWORDS
    }


def labels_match(left: Any, right: Any) -> bool:
    a, b = label_tokens(left), label_tokens(right)
    if not a or not b:
        return False
    overlap = len(a & b) / min(len(a), len(b))
    return overlap > LABEL_OVERLAP_THRESHOLD


def requirement_type(item: dict[str, Any]) -> str:
    return item.get("type") or "other"


def requirement_id(kind: str, label: str, taken: Iterable[str]) -> str:
    return unique_slug(f"{kind or 'other'} {label}", taken)


def find_matching_requirement(
    existing: list[dict[str, Any]], item: dict[str, Any]
) -> dict[str, Any] | None:
    kind = requirement_type(item)
    same_type = [e for e in existing if requirement_type(e) == kind]

    incoming_url = normalise_url(item.get("url"))
    if incoming_url:
        for candidate in same_type:
            if normalise_url(candidate.get("url")) == incoming_url:
                return candidate

    for candidate in same_type:
        if labels_match(candidate.get("label"), item.get("label")):
            return candidate

    return None


def absorb(current: dict[str, Any], item: dict[str, Any]) -> None:
    if not current.get("label"):
        current["label"] = item.get("label")
    if not current.get("url") and item.get("url"):
        current["url"] = item["url"]
    current["required"] = bool(item.get("required", current.get("required")))
    current["type"] = requirement_type(item) or requirement_type(current)


def build_requirements(
    raw: list[dict[str, Any]],
    now: datetime | None = None,
    message_id: str | None = None,
) -> list[dict[str, Any]]:
    requirements: list[dict[str, Any]] = []
    for item in raw:
        label = (item.get("label") or "").strip()
        if not label:
            continue
        kind = requirement_type(item)
        candidate = {
            "type": kind,
            "label": label,
            "url": item.get("url"),
            "required": bool(item.get("required", True)),
        }
        existing = find_matching_requirement(requirements, candidate)
        if existing is not None:
            absorb(existing, candidate)
            continue
        requirements.append(
            {
                "id": requirement_id(kind, label, [r["id"] for r in requirements]),
                "type": kind,
                "label": label,
                "url": item.get("url"),
                "required": bool(item.get("required", True)),
                "addedAt": now,
                "sourceMessageId": message_id,
            }
        )
    return requirements


def merge_requirements(
    existing: list[dict[str, Any]], incoming: list[dict[str, Any]]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    merged = [dict(item) for item in existing]
    newly_required: list[dict[str, Any]] = []

    for item in incoming:
        current = find_matching_requirement(merged, item)
        if current is None:
            fresh = dict(item)
            fresh["id"] = requirement_id(
                requirement_type(item), item.get("label", ""), [r["id"] for r in merged]
            )
            merged.append(fresh)
            if fresh.get("required"):
                newly_required.append(fresh)
            continue
        was_required = bool(current.get("required"))
        absorb(current, item)
        if current["required"] and not was_required:
            newly_required.append(current)

    return merged, newly_required


def dedupe_requirements(
    requirements: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[str]]:
    merged: list[dict[str, Any]] = []
    removed: list[str] = []
    for item in requirements:
        current = find_matching_requirement(merged, item)
        if current is None:
            fresh = dict(item)
            fresh["id"] = requirement_id(
                requirement_type(fresh),
                fresh.get("label", ""),
                [r["id"] for r in merged],
            )
            merged.append(fresh)
            continue
        removed.append(item.get("id", ""))
        absorb(current, item)
        if item.get("addedAt") and (
            not current.get("addedAt") or item["addedAt"] < current["addedAt"]
        ):
            current["addedAt"] = item["addedAt"]
            current["sourceMessageId"] = item.get("sourceMessageId")
    return merged, removed
