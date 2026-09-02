from __future__ import annotations

import re

MONTHLY = "monthly"
TOTAL = "total"
UNSPECIFIED = "unspecified"

_MONTHLY_PATTERNS = (
    r"per\s*month",
    r"/\s*month",
    r"\bp\.?\s?m\.?\b",
    r"\bmonthly\b",
    r"a\s+month",
    r"/\s*mo\b",
    r"\bpermonth\b",
)

_TOTAL_PATTERNS = (
    r"\btotal\b",
    r"\blump\s*sum\b",
    r"\bconsolidated\b",
    r"\bctc[\s-]*inclusive\b",
    r"\bfor\s+the\s+(entire\s+)?(internship|duration)\b",
    r"\bover\s+\d+\s*months?\b",
)


def infer_stipend_period(stipend: str | None) -> str:
    text = (stipend or "").strip().lower()
    if not text:
        return UNSPECIFIED
    for pattern in _MONTHLY_PATTERNS:
        if re.search(pattern, text):
            return MONTHLY
    for pattern in _TOTAL_PATTERNS:
        if re.search(pattern, text):
            return TOTAL
    return UNSPECIFIED
