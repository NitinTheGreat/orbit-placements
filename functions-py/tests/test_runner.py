from __future__ import annotations

from datetime import datetime, timezone

import pytest

from orbit.config import IngestionConfig, load_config
from orbit.matching import DEFAULT_SENDER_PATTERNS, extract_addresses, sender_allowed
from orbit.runner import (
    TokenRevoked,
    collect_message_ids,
    dry_run,
    is_history_too_old,
    is_revoked_error,
)

CUTOFF_MS = int(datetime(2026, 9, 1, tzinfo=timezone.utc).timestamp() * 1000)
AFTER_MS = int(datetime(2026, 9, 1, 17, 13, tzinfo=timezone.utc).timestamp() * 1000)
BEFORE_MS = int(datetime(2026, 8, 1, tzinfo=timezone.utc).timestamp() * 1000)

CONFIG = IngestionConfig(
    cutoff_ms=CUTOFF_MS,
    allowed_sender_patterns=[
        r"vitianscdc2027@vitstudent\.ac\.in",
        r"vitianscdc\d{4}@vitstudent\.ac\.in",
    ],
    from_defaults=False,
)


class FakeResp:
    def __init__(self, status):
        self.status = status


class HttpError(Exception):
    def __init__(self, status, message="boom"):
        super().__init__(message)
        self.resp = FakeResp(status)


class FakeGmail:
    def __init__(self, history=None, scan=None, history_error=None, metadata=None):
        self._history = history or ([], "900")
        self._scan = scan or ([], "901")
        self._history_error = history_error
        self._metadata = metadata or {}
        self.scan_calls = []

    def list_new_message_ids(self, start_history_id):
        if self._history_error:
            raise self._history_error
        return self._history

    def scan_recent_message_ids(self, after, senders=None):
        self.scan_calls.append({"after": after, "senders": senders})
        return self._scan

    def get_metadata(self, message_id):
        return self._metadata[message_id]


class FakeStore:
    def __init__(self, processed=()):
        self.processed = set(processed)

    def is_processed(self, message_id):
        return message_id in self.processed


def test_sender_matches_the_real_cdc_group_address():
    header = "VITians CDC 2027 via vitianscdc2027 <vitianscdc2027@vitstudent.ac.in>"
    assert extract_addresses(header) == ["vitianscdc2027@vitstudent.ac.in"]
    assert sender_allowed(header, CONFIG.allowed_sender_patterns) is True


def test_sender_matches_other_cdc_years_through_the_generalised_pattern():
    header = "<vitianscdc2026@vitstudent.ac.in>"
    assert sender_allowed(header, CONFIG.allowed_sender_patterns) is True


def test_display_name_alone_does_not_pass():
    header = "vitianscdc2027 <randomsender@gmail.com>"
    assert sender_allowed(header, CONFIG.allowed_sender_patterns) is False


def test_unrelated_sender_is_rejected():
    header = "Amazon <shipment-tracking@amazon.in>"
    assert sender_allowed(header, CONFIG.allowed_sender_patterns) is False


def test_missing_config_falls_back_and_warns(caplog):
    with caplog.at_level("WARNING"):
        config = load_config(None)
    assert config.from_defaults is True
    assert config.allowed_sender_patterns == list(DEFAULT_SENDER_PATTERNS)
    assert "config/ingestion is missing" in caplog.text


def test_config_without_patterns_warns_but_keeps_cutoff(caplog):
    with caplog.at_level("WARNING"):
        config = load_config({"cutoffDate": "2026-09-01T00:00:00+05:30"})
    assert config.allowed_sender_patterns == list(DEFAULT_SENDER_PATTERNS)
    assert "no allowedSenderPatterns" in caplog.text


def test_history_too_old_falls_back_to_a_bounded_scan():
    gmail = FakeGmail(
        history_error=HttpError(404), scan=(["m1", "m2"], "950")
    )

    ids, latest, source = collect_message_ids(gmail, CONFIG, "123")

    assert source == "scan"
    assert ids == ["m1", "m2"]
    assert latest == "950"
    assert gmail.scan_calls[0]["senders"] == [
        "vitianscdc2027@vitstudent.ac.in",
        "vitstudent.ac.in",
    ]


def test_history_path_used_when_history_id_is_still_valid():
    gmail = FakeGmail(history=(["m9"], "999"))

    ids, latest, source = collect_message_ids(gmail, CONFIG, "123")

    assert (ids, latest, source) == (["m9"], "999", "history")
    assert gmail.scan_calls == []


def test_revoked_token_raises_rather_than_falling_back():
    gmail = FakeGmail(history_error=HttpError(401, "invalid_grant"))

    with pytest.raises(TokenRevoked):
        collect_message_ids(gmail, CONFIG, "123")

    assert gmail.scan_calls == []


def test_revoked_detection_covers_both_signals():
    assert is_revoked_error(HttpError(401)) is True
    assert is_revoked_error(Exception("invalid_grant: expired")) is True
    assert is_revoked_error(HttpError(404)) is False
    assert is_history_too_old(HttpError(404)) is True


def test_dry_run_counts_and_samples_rejections():
    metadata = {
        "m1": {
            "sender": "VITians CDC via <vitianscdc2027@vitstudent.ac.in>",
            "subject": "Superjoin drive",
            "internal_date_ms": AFTER_MS,
        },
        "m2": {
            "sender": "Amazon <ship@amazon.in>",
            "subject": "Your order",
            "internal_date_ms": AFTER_MS,
        },
        "m3": {
            "sender": "<vitianscdc2027@vitstudent.ac.in>",
            "subject": "Old drive",
            "internal_date_ms": BEFORE_MS,
        },
        "m4": {
            "sender": "<vitianscdc2027@vitstudent.ac.in>",
            "subject": "Seen already",
            "internal_date_ms": AFTER_MS,
        },
    }
    gmail = FakeGmail(history=(["m1", "m2", "m3", "m4"], "990"), metadata=metadata)
    store = FakeStore(processed={"m4"})

    result = dry_run(gmail, store, CONFIG, "123")

    assert result["counts"] == {
        "seen": 4,
        "passed_filter": 1,
        "rejected_sender": 1,
        "rejected_cutoff": 1,
        "already_processed": 1,
        "gone": 0,
    }
    reasons = {sample["reason"] for sample in result["rejected_sample"]}
    assert reasons == {"sender_not_allowed", "before_cutoff"}
    assert result["rejected_sample"][0]["addresses"] == "ship@amazon.in"


def test_dry_run_writes_nothing():
    gmail = FakeGmail(history=([], "990"))
    store = FakeStore()

    result = dry_run(gmail, store, CONFIG, "123")

    assert result["counts"]["seen"] == 0
    assert not hasattr(store, "put_status")


class _Resp:
    def __init__(self, status):
        self.status = status


class _HttpError(Exception):
    def __init__(self, status):
        super().__init__(f"HttpError {status}")
        self.resp = _Resp(status)


class RecordingStore(FakeStore):
    def __init__(self, processed=()):
        super().__init__(processed)
        self.outcomes = {}

    def mark_processed(self, message_id, student_id, outcome):
        self.processed.add(message_id)
        self.outcomes[message_id] = outcome

    def get_company(self, company_id):
        return None

    def find_company_by_name(self, name):
        return None

    def get_broadcast_company(self, digest):
        return None

    def put_broadcast_company(self, digest, company_id):
        return None

    def upsert_company(self, company_id, payload, now):
        return company_id or "company-1"

    def get_status(self, student_id, company_id):
        return None

    def put_status(self, student_id, company_id, payload):
        return None


class MissingMessageGmail:
    def __init__(self, missing, metadata=None):
        self.missing = set(missing)
        self.metadata = metadata or {
            "sender": "VITians CDC 2027 <vitianscdc2027@vitstudent.ac.in>",
            "subject": "Drive",
            "internal_date_ms": 0,
        }
        self.asked = []

    def get_metadata(self, message_id):
        self.asked.append(message_id)
        if message_id in self.missing:
            raise _HttpError(404)
        return self.metadata

    def get_full_message(self, message_id):
        return {"body": "", "attachments": []}

    def get_attachment(self, message_id, attachment_id):
        return b""


def test_a_deleted_message_does_not_break_the_whole_sync():
    from orbit.runner import run_messages
    from tests.test_graph import make_deps

    store = RecordingStore()
    gmail = MissingMessageGmail(missing={"gone-1"})
    deps = make_deps(store=store, gmail=gmail)

    counts = run_messages(
        deps,
        CONFIG,
        "student-1",
        ["23BCT0098"],
        ["gone-1", "alive-1"],
    )

    assert counts["gone"] == 1
    assert gmail.asked == ["gone-1", "alive-1"]
    assert store.outcomes["gone-1"] == "message_gone"


def test_a_deleted_message_is_never_retried():
    from orbit.runner import run_messages
    from tests.test_graph import make_deps

    store = RecordingStore()
    gmail = MissingMessageGmail(missing={"gone-1"})
    deps = make_deps(store=store, gmail=gmail)

    run_messages(deps, CONFIG, "student-1", ["23BCT0098"], ["gone-1"])
    second = run_messages(deps, CONFIG, "student-1", ["23BCT0098"], ["gone-1"])

    assert second["skipped"] == 1
    assert gmail.asked == ["gone-1"]


def test_a_real_failure_still_surfaces():
    import pytest

    from orbit.runner import run_messages
    from tests.test_graph import make_deps

    class BrokenGmail(MissingMessageGmail):
        def get_metadata(self, message_id):
            raise _HttpError(500)

    deps = make_deps(store=RecordingStore(), gmail=BrokenGmail(missing=set()))
    with pytest.raises(Exception):
        run_messages(deps, CONFIG, "student-1", ["23BCT0098"], ["boom"])
