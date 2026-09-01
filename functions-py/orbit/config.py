from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone

from .matching import DEFAULT_SENDER_PATTERNS

logger = logging.getLogger("orbit.config")

DEFAULT_CUTOFF_ISO = "2026-09-01T00:00:00+05:30"


@dataclass(frozen=True)
class IngestionConfig:
    cutoff_ms: int
    allowed_sender_patterns: list[str]
    from_defaults: bool


def _parse_cutoff(raw: object) -> datetime:
    if isinstance(raw, datetime):
        parsed = raw
    else:
        parsed = datetime.fromisoformat(str(raw or DEFAULT_CUTOFF_ISO))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def load_config(raw: dict | None) -> IngestionConfig:
    if not raw:
        logger.warning(
            "config/ingestion is missing; falling back to built-in sender "
            "patterns %s and cutoff %s. Ingestion will silently ignore mail "
            "from any other sender until the document is created.",
            list(DEFAULT_SENDER_PATTERNS),
            DEFAULT_CUTOFF_ISO,
        )
        return IngestionConfig(
            cutoff_ms=int(_parse_cutoff(None).timestamp() * 1000),
            allowed_sender_patterns=list(DEFAULT_SENDER_PATTERNS),
            from_defaults=True,
        )

    patterns = raw.get("allowedSenderPatterns")
    if not patterns:
        logger.warning(
            "config/ingestion has no allowedSenderPatterns; falling back to "
            "built-in patterns %s.",
            list(DEFAULT_SENDER_PATTERNS),
        )
        patterns = list(DEFAULT_SENDER_PATTERNS)

    return IngestionConfig(
        cutoff_ms=int(_parse_cutoff(raw.get("cutoffDate")).timestamp() * 1000),
        allowed_sender_patterns=[str(p) for p in patterns],
        from_defaults=False,
    )
