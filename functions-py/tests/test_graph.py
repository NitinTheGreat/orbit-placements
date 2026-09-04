from __future__ import annotations

from datetime import datetime, timezone

import pytest

from orbit.graph import build_graph
from orbit.state import IngestionState
from orbit.store import Deps

FIXED_NOW = datetime(2026, 9, 2, 12, 0, tzinfo=timezone.utc)
CUTOFF_MS = int(datetime(2026, 1, 1, tzinfo=timezone.utc).timestamp() * 1000)
AFTER_CUTOFF_MS = int(datetime(2026, 8, 1, tzinfo=timezone.utc).timestamp() * 1000)
BEFORE_CUTOFF_MS = int(datetime(2025, 6, 1, tzinfo=timezone.utc).timestamp() * 1000)

SHORTLIST_BODY = """
<p>Dear Students,</p>
<p>The following students are shortlisted for the Technical Round 1 of the
Rubrik drive. Category: Super Dream. CTC: 32 LPA.</p>
<p>23BCT0098 Nitin Kumar Pandey</p>
<p>21BCE1234 Someone Else</p>
"""


class FakeGmail:
    def __init__(self, body=SHORTLIST_BODY, attachments=None, attachment_bytes=b""):
        self.body = body
        self.attachments = attachments or []
        self.attachment_bytes = attachment_bytes
        self.full_calls = 0
        self.attachment_calls = 0

    def get_full_message(self, message_id):
        self.full_calls += 1
        return {"body": self.body, "attachments": self.attachments}

    def get_attachment(self, message_id, attachment_id):
        self.attachment_calls += 1
        return self.attachment_bytes


class FakeStore:
    def __init__(self, companies=None, statuses=None, broadcasts=None):
        self.companies = companies or {}
        self.statuses = statuses or {}
        self.broadcasts = broadcasts or {}
        self.put_status_calls = []
        self.upsert_calls = []

    def get_broadcast_company(self, digest):
        return self.broadcasts.get(digest)

    def put_broadcast_company(self, digest, company_id):
        self.broadcasts[digest] = company_id

    def get_company(self, company_id):
        return self.companies.get(company_id)

    def find_company_by_name(self, name):
        for company_id, company in self.companies.items():
            if company.get("name") == name:
                return company_id
        return None

    def upsert_company(self, company_id, payload, now):
        resolved = company_id or f"company-{len(self.companies) + 1}"
        self.companies[resolved] = {**self.companies.get(resolved, {}), **payload}
        self.upsert_calls.append((resolved, payload))
        return resolved

    def get_status(self, student_id, company_id):
        return self.statuses.get(f"{student_id}_{company_id}")

    def put_status(self, student_id, company_id, payload):
        self.statuses[f"{student_id}_{company_id}"] = payload
        self.put_status_calls.append(payload)


class RecordingExtractor:
    def __init__(self, result=None):
        self.calls = 0
        self.result = result or {
            "is_placement_mail": True,
            "company": {
                "name": "Rubrik",
                "category": "Super Dream",
                "ctc": "32 LPA",
                "eligible_branches": ["CSE"],
            },
            "round": {
                "name": "Technical Round 1",
                "type": "interview",
                "is_new_round": True,
                "result": "invited",
            },
            "requirements": [
                {
                    "type": "google_form",
                    "label": "Fill the registration form",
                    "required": True,
                }
            ],
        }

    def __call__(self, sender, subject, body):
        self.calls += 1
        return self.result


def make_deps(store=None, gmail=None, extractor=None):
    return Deps(
        store=store or FakeStore(),
        gmail=gmail or FakeGmail(),
        extractor=extractor or RecordingExtractor(),
        now=lambda: FIXED_NOW,
    )


def base_state(**overrides) -> IngestionState:
    state: IngestionState = {
        "student_id": "student-1",
        "student_identifiers": ["L5P2U7S5", "23BCT0098"],
        "message_id": "msg-1",
        "sender": "VITians CDC 2027 <vitianscdc2027@vitstudent.ac.in>",
        "subject": "Rubrik shortlist for Technical Round 1",
        "internal_date_ms": AFTER_CUTOFF_MS,
        "cutoff_ms": CUTOFF_MS,
        "allowed_sender_patterns": [r"vitianscdc\d{4}@vitstudent\.ac\.in"],
    }
    state.update(overrides)
    return state


def test_cutoff_rejects_old_mail_before_any_fetch():
    gmail = FakeGmail()
    extractor = RecordingExtractor()
    graph = build_graph(make_deps(gmail=gmail, extractor=extractor))

    result = graph.invoke(base_state(internal_date_ms=BEFORE_CUTOFF_MS))

    assert result["halt_reason"] == "before_cutoff"
    assert result["halted_at"] == "cheap_filter"
    assert gmail.full_calls == 0
    assert extractor.calls == 0


def test_unrelated_sender_rejected():
    gmail = FakeGmail()
    graph = build_graph(make_deps(gmail=gmail))

    result = graph.invoke(
        base_state(sender="newsletter@shopping.com", subject="Your order shipped")
    )

    assert result["halt_reason"] == "sender_not_allowed"
    assert gmail.full_calls == 0


def test_dedup_shortcut_skips_the_llm_call():
    from orbit.cleaning import clean_body, content_hash

    digest = content_hash(clean_body(SHORTLIST_BODY))
    store = FakeStore(
        companies={"company-1": {"name": "Rubrik", "rounds": [
            {"id": "technical-round-1", "name": "Technical Round 1", "order": 1,
             "type": "interview"}
        ]}},
        broadcasts={digest: "company-1"},
    )
    extractor = RecordingExtractor()
    graph = build_graph(make_deps(store=store, extractor=extractor))

    result = graph.invoke(base_state())

    assert extractor.calls == 0
    assert result["company_id"] == "company-1"
    assert result["matched"] is True
    assert store.put_status_calls


def test_no_identifier_match_ends_without_writing_status():
    store = FakeStore()
    graph = build_graph(make_deps(store=store))

    result = graph.invoke(base_state(student_identifiers=["22BCE9999"]))

    assert result["matched"] is False
    assert result["halt_reason"] == "student_not_named"
    assert result["halted_at"] == "not_listed_check"
    assert store.put_status_calls == []
    assert store.upsert_calls, "company directory should still be written"


def test_explicit_opt_out_suppresses_the_status_write():
    store = FakeStore(
        statuses={
            "student-1_company-1": {
                "studentId": "student-1",
                "companyId": "company-1",
                "optedIn": False,
                "roundHistory": [],
            }
        }
    )
    graph = build_graph(make_deps(store=store))

    result = graph.invoke(base_state())

    assert result["halt_reason"] == "opted_out"
    assert result["opted_in"] is False
    assert store.put_status_calls == []


def test_unset_opt_in_becomes_true_on_a_real_match():
    store = FakeStore()
    graph = build_graph(make_deps(store=store))

    result = graph.invoke(base_state())

    assert result["matched"] is True
    written = store.put_status_calls[-1]
    assert written["optedIn"] is True
    assert written["source"] == "gmail_ingestion"
    assert written["currentRoundId"] == "technical-round-1"
    assert written["overallStatus"] == "active"
    assert written["roundHistory"][0]["result"] == "invited"


def test_attachment_match_when_body_has_no_identifier():
    body = "<p>Please find the shortlist for Rubrik attached.</p>"
    csv_bytes = b"RegNo,Name\n23BCT0098,Nitin Kumar Pandey\n"
    gmail = FakeGmail(
        body=body,
        attachments=[{"filename": "shortlist.csv", "attachmentId": "att-1"}],
        attachment_bytes=csv_bytes,
    )
    store = FakeStore()
    graph = build_graph(make_deps(store=store, gmail=gmail))

    result = graph.invoke(base_state())

    assert result["matched"] is True
    assert result["match_source"] == "attachment"
    assert gmail.attachment_calls == 1


def test_rejection_sets_overall_status_rejected():
    extractor = RecordingExtractor(
        {
            "is_placement_mail": True,
            "company": {"name": "Rubrik"},
            "round": {
                "name": "Technical Round 1",
                "type": "interview",
                "is_new_round": False,
                "result": "rejected",
            },
            "requirements": [],
        }
    )
    store = FakeStore()
    graph = build_graph(make_deps(store=store, extractor=extractor))

    graph.invoke(base_state())

    written = store.put_status_calls[-1]
    assert written["overallStatus"] == "rejected"
    assert written["currentRoundId"] is None


def test_creating_the_first_round_bumps_company_status():
    store = FakeStore()
    graph = build_graph(make_deps(store=store))

    graph.invoke(base_state())

    _, payload = store.upsert_calls[-1]
    assert payload["status"] == "in_progress"
    assert payload["rounds"][0]["id"] == "technical-round-1"
    assert payload["rounds"][0]["order"] == 1
    assert (
        payload["requirements"][0]["id"]
        == "google-form-fill-the-registration-form"
    )


def test_repeat_result_for_same_round_overwrites_in_place():
    store = FakeStore(
        companies={
            "company-1": {
                "name": "Rubrik",
                "rounds": [
                    {"id": "technical-round-1", "name": "Technical Round 1",
                     "order": 1, "type": "interview"}
                ],
            }
        },
        statuses={
            "student-1_company-1": {
                "studentId": "student-1",
                "companyId": "company-1",
                "roundHistory": [
                    {"roundId": "technical-round-1", "result": "invited"}
                ],
                "optedIn": True,
            }
        },
    )
    extractor = RecordingExtractor(
        {
            "is_placement_mail": True,
            "company": {"name": "Rubrik"},
            "round": {
                "name": "Technical Round 1",
                "type": "interview",
                "is_new_round": False,
                "result": "cleared",
            },
            "requirements": [],
        }
    )
    graph = build_graph(make_deps(store=store, extractor=extractor))

    graph.invoke(base_state())

    written = store.put_status_calls[-1]
    assert len(written["roundHistory"]) == 1
    assert written["roundHistory"][0]["result"] == "cleared"
    assert written["overallStatus"] == "selected"


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))


def test_a_round_records_the_date_it_actually_happens():
    import copy
    from orbit.store import merge_rounds
    from datetime import datetime, timezone

    when = datetime(2026, 9, 12, 9, 0, tzinfo=timezone.utc)
    rounds, rid, created = merge_rounds([], "Online test", "oa", FIXED_NOW, when)
    assert created is True
    assert rounds[0]["scheduledDate"] == when

    again, rid2, created2 = merge_rounds(rounds, "Online test", "oa", FIXED_NOW, None)
    assert created2 is False
    assert again[0]["scheduledDate"] == when


def test_a_later_mail_fills_in_a_missing_scheduled_date():
    from orbit.store import merge_rounds
    from datetime import datetime, timezone

    rounds, _, _ = merge_rounds([], "Online test", "oa", FIXED_NOW, None)
    assert rounds[0].get("scheduledDate") is None

    when = datetime(2026, 9, 12, 9, 0, tzinfo=timezone.utc)
    filled, _, created = merge_rounds(rounds, "Online test", "oa", FIXED_NOW, when)
    assert created is False
    assert filled[0]["scheduledDate"] == when


def test_the_extraction_schema_exposes_scheduled_date():
    from orbit.extraction import RoundInfo

    assert "scheduled_date" in RoundInfo.model_fields
    assert RoundInfo().scheduled_date is None
