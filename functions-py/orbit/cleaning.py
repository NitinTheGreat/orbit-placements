from __future__ import annotations

import hashlib
import re

_TAG = re.compile(r"<[^>]+>")
_STYLE_BLOCK = re.compile(r"<(script|style)[^>]*>.*?</\1>", re.IGNORECASE | re.DOTALL)
_WHITESPACE = re.compile(r"[ \t ]+")
_BLANK_LINES = re.compile(r"\n{3,}")
_EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+")
_REG_NO = re.compile(r"\b\d{2}[A-Za-z]{3}\d{4}\b")

_ENTITIES = {
    "&nbsp;": " ",
    "&amp;": "&",
    "&lt;": "<",
    "&gt;": ">",
    "&quot;": '"',
    "&#39;": "'",
    "&apos;": "'",
}

_BOILERPLATE_MARKERS = (
    "this email and any files transmitted",
    "confidentiality notice",
    "disclaimer:",
    "please consider the environment",
    "unsubscribe",
    "sent from my",
    "-----original message-----",
)

_SALUTATION = re.compile(
    r"^\s*(dear|hi|hello|greetings)\b.*$", re.IGNORECASE | re.MULTILINE
)


def strip_html(raw: str) -> str:
    if not raw:
        return ""
    text = _STYLE_BLOCK.sub(" ", raw)
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"</(p|div|tr|li|h[1-6])>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"</t[dh]>", "\t", text, flags=re.IGNORECASE)
    text = _TAG.sub(" ", text)
    for entity, replacement in _ENTITIES.items():
        text = text.replace(entity, replacement)
    return text


def normalise(text: str) -> str:
    lines = []
    for line in text.splitlines():
        cleaned = _WHITESPACE.sub(" ", line).strip()
        lines.append(cleaned)
    joined = "\n".join(lines)
    return _BLANK_LINES.sub("\n\n", joined).strip()


def strip_boilerplate(text: str) -> str:
    kept = []
    for line in text.splitlines():
        lowered = line.lower().strip()
        if any(marker in lowered for marker in _BOILERPLATE_MARKERS):
            break
        kept.append(line)
    return "\n".join(kept).strip()


def clean_body(raw: str) -> str:
    return strip_boilerplate(normalise(strip_html(raw)))


def hashable_body(cleaned: str) -> str:
    without_salutation = _SALUTATION.sub("", cleaned)
    without_emails = _EMAIL.sub("", without_salutation)
    without_regnos = _REG_NO.sub("", without_emails)
    return normalise(without_regnos)


def content_hash(cleaned: str) -> str:
    return hashlib.sha256(hashable_body(cleaned).encode("utf-8")).hexdigest()
