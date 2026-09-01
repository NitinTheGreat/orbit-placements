from __future__ import annotations

import re
from collections.abc import Iterable

_NON_ALNUM = re.compile(r"[^a-z0-9]+")
_TRIM = re.compile(r"^-+|-+$")


def slugify(value: str) -> str:
    lowered = (value or "").lower().strip()
    slug = _TRIM.sub("", _NON_ALNUM.sub("-", lowered))
    return slug or "round"


def unique_slug(value: str, taken: Iterable[str]) -> str:
    existing = set(taken)
    base = slugify(value)
    if base not in existing:
        return base
    suffix = 2
    while f"{base}-{suffix}" in existing:
        suffix += 1
    return f"{base}-{suffix}"
