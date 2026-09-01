from __future__ import annotations

import re

_NORMALISE = re.compile(r"[^a-z0-9]+")
_EMAIL_IN_HEADER = re.compile(r"[\w.+-]+@[\w.-]+\.\w+")

DEFAULT_SENDER_PATTERNS = (
    r"vitianscdc\d{4}@vitstudent\.ac\.in",
    r"vitianscdc2027@vitstudent\.ac\.in",
)


def normalise_identifier(value: str) -> str:
    return _NORMALISE.sub("", (value or "").lower())


def extract_addresses(from_header: str) -> list[str]:
    return [match.lower() for match in _EMAIL_IN_HEADER.findall(from_header or "")]


def sender_allowed(from_header: str, patterns: list[str]) -> bool:
    addresses = extract_addresses(from_header)
    if not addresses:
        return False
    for raw in patterns:
        try:
            expression = re.compile(raw, re.IGNORECASE)
        except re.error:
            continue
        for address in addresses:
            if expression.fullmatch(address) or expression.search(address):
                return True
    return False


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
