from __future__ import annotations

import re
from typing import Iterable

COMPUTER_SCIENCE = "computer_science"
INFORMATION_TECHNOLOGY = "information_technology"
ELECTRICAL = "electrical"
MECHANICAL = "mechanical"
POSTGRADUATE = "postgraduate"

UNDERGRADUATE = "undergraduate"
POSTGRADUATE_LEVEL = "postgraduate"

ELIGIBLE = "eligible"
NOT_OPEN = "not_open"
UNKNOWN = "unknown"

_REG_NO = re.compile(r"^(\d{2})([A-Z]{3})(\d{4})$")
_SEPARATORS = re.compile(r"[^a-z0-9]+")
_EXCLUSION = re.compile(r"\b(except|excluding|other than)\b")
_OPEN_TO_ALL = re.compile(r"\ball\b")
_WHITESPACE = re.compile(r"\s+")

LEVEL_KEYWORDS: dict[str, list[str]] = {
    POSTGRADUATE_LEVEL: [
        "m tech",
        "mtech",
        "m e",
        "mca",
        "msc",
        "m sc",
        "mba",
        "pg",
        "postgraduate",
        "post graduate",
        "masters",
    ],
    UNDERGRADUATE: [
        "b tech",
        "btech",
        "b e",
        "ug",
        "undergraduate",
        "under graduate",
        "bachelor",
        "bachelors",
    ],
}

FAMILY_KEYWORDS: dict[str, list[str]] = {
    COMPUTER_SCIENCE: [
        "cse",
        "cs",
        "computer science",
        "computer sciences",
        "computing",
        "aiml",
        "ai ml",
        "data science",
        "ds",
    ],
    INFORMATION_TECHNOLOGY: ["it", "information technology"],
    ELECTRICAL: [
        "ece",
        "ecm",
        "eee",
        "eie",
        "electrical",
        "electronics",
        "electronics and communication",
        "electronics communication",
        "electronics and telecommunication",
        "electrical and electronics",
        "instrumentation",
        "electronics and instrumentation",
    ],
    MECHANICAL: ["mech", "mechanical", "mechatronics", "automotive"],
    POSTGRADUATE: ["m tech", "mtech", "mca", "msc"],
}


def branch_code_from_reg_no(reg_no: str | None) -> str | None:
    if not reg_no:
        return None
    cleaned = _WHITESPACE.sub("", reg_no).upper()
    match = _REG_NO.match(cleaned)
    return match.group(2) if match else None


def branch_family_for_code(code: str | None) -> str | None:
    if not code:
        return None
    upper = code.strip().upper()
    if not upper:
        return None
    if upper == "BIT":
        return INFORMATION_TECHNOLOGY
    if upper.startswith("BC"):
        return COMPUTER_SCIENCE
    if upper.startswith("BE"):
        return ELECTRICAL
    if upper.startswith("BM"):
        return MECHANICAL
    if upper.startswith("M"):
        return POSTGRADUATE
    return None


def branch_family_for_reg_no(reg_no: str | None) -> str | None:
    return branch_family_for_code(branch_code_from_reg_no(reg_no))


def degree_level_for_code(code: str | None) -> str | None:
    if not code:
        return None
    upper = code.strip().upper()
    if not upper:
        return None
    if upper.startswith("B"):
        return UNDERGRADUATE
    if upper.startswith("M"):
        return POSTGRADUATE_LEVEL
    return None


def degree_level_for_reg_no(reg_no: str | None) -> str | None:
    return degree_level_for_code(branch_code_from_reg_no(reg_no))


def _normalise(value: str) -> str:
    return f" {_SEPARATORS.sub(' ', value.lower()).strip()} "


def _mentions(normalised: str, keyword: str) -> bool:
    return f" {_SEPARATORS.sub(' ', keyword)} " in normalised


def families_mentioned_in(text: str) -> set[str]:
    normalised = _normalise(text)
    found: set[str] = set()
    for family, keywords in FAMILY_KEYWORDS.items():
        for keyword in keywords:
            if _mentions(normalised, keyword):
                found.add(family)
                break
    return found


def levels_mentioned_in(text: str) -> set[str]:
    normalised = _normalise(text)
    found: set[str] = set()
    for level, keywords in LEVEL_KEYWORDS.items():
        for keyword in keywords:
            if _mentions(normalised, keyword):
                found.add(level)
                break
    return found


def _branch_outcome(family: str, lowered: str) -> str:
    exclusion = _EXCLUSION.search(lowered)

    if exclusion:
        excluded = families_mentioned_in(lowered[exclusion.end() :])
        if not excluded:
            return UNKNOWN
        if family in excluded:
            return NOT_OPEN
        base = lowered[: exclusion.start()]
        return ELIGIBLE if _OPEN_TO_ALL.search(base) else UNKNOWN

    mentioned = families_mentioned_in(lowered)
    if not mentioned:
        return UNKNOWN
    return ELIGIBLE if family in mentioned else NOT_OPEN


def branch_relevance(
    family: str | None,
    eligible_branches: Iterable[str] | None,
    level: str | None = None,
) -> str:
    if not family:
        return UNKNOWN

    level_admitted = False
    level_excluded = False
    branch_excluded = False

    for entry in eligible_branches or []:
        if not entry or not entry.strip():
            continue
        lowered = entry.lower()
        levels = levels_mentioned_in(lowered)

        if level is not None and levels and level not in levels:
            level_excluded = True
            continue
        level_admitted = True

        if family == POSTGRADUATE:
            continue

        outcome = _branch_outcome(family, lowered)
        if outcome == ELIGIBLE:
            return ELIGIBLE
        if outcome == NOT_OPEN:
            branch_excluded = True

    if level_admitted:
        return NOT_OPEN if branch_excluded else UNKNOWN
    return NOT_OPEN if level_excluded else UNKNOWN


def branch_relevance_for_reg_no(
    reg_no: str | None, eligible_branches: Iterable[str] | None
) -> str:
    return branch_relevance(
        branch_family_for_reg_no(reg_no),
        eligible_branches,
        degree_level_for_reg_no(reg_no),
    )


def is_confident_mismatch(
    reg_no: str | None, eligible_branches: Iterable[str] | None
) -> bool:
    return branch_relevance_for_reg_no(reg_no, eligible_branches) == NOT_OPEN


def reg_no_from_identifiers(identifiers: Iterable[str] | None) -> str | None:
    for identifier in identifiers or []:
        if branch_code_from_reg_no(identifier):
            return identifier
    return None
