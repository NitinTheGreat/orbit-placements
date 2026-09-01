from __future__ import annotations

import re

_NORMALISE = re.compile(r"[^a-z0-9]+")

PLACEMENT_SENDER_HINTS = (
    "placement",
    "tpo",
    "career",
    "cdc",
    "vit.ac.in",
    "vitstudent.ac.in",
)

PLACEMENT_SUBJECT_HINTS = (
    "placement",
    "drive",
    "shortlist",
    "shortlisted",
    "interview",
    "online assessment",
    "oa ",
    "ppt",
    "pre-placement",
    "recruitment",
    "hiring",
    "internship",
    "offer",
    "selected",
    "registration",
)


def normalise_identifier(value: str) -> str:
    return _NORMALISE.sub("", (value or "").lower())


def looks_like_placement_mail(sender: str, subject: str) -> bool:
    lowered_sender = (sender or "").lower()
    lowered_subject = (subject or "").lower()
    if any(hint in lowered_sender for hint in PLACEMENT_SENDER_HINTS):
        return True
    return any(hint in lowered_subject for hint in PLACEMENT_SUBJECT_HINTS)


def find_identifier(haystack: str, identifiers: list[str]) -> str | None:
    normalised_haystack = normalise_identifier(haystack)
    if not normalised_haystack:
        return None
    for identifier in identifiers:
        needle = normalise_identifier(identifier)
        if len(needle) < 4:
            continue
        if needle in normalised_haystack:
            return identifier
    return None
