from __future__ import annotations

import copy

from orbit.graph import build_graph
from orbit.store import resolve_current_round_id, resolve_overall_status

from .test_graph import (
    FIXED_NOW,
    FakeStore,
    RecordingExtractor,
    base_state,
    make_deps,
)

OTHER_STUDENT_BODY = """
<p>Dear Students,</p>
<p>This is the final shortlist for the Technical Round 1 of the Rubrik
drive. Only the following students may attend.</p>
<p>21BCE1234 Someone Else</p>
"""

ROUNDS = [{"id": "technical-round-1", "name": "Technical Round 1", "order": 1}]


def roster_extractor(roster_type):
    extractor = RecordingExtractor()
    extractor.result = copy.deepcopy(extractor.result)
    extractor.result["round"]["roster_type"] = roster_type
    return extractor


def prior_status(history):
    return {
        "studentId": "student-1",
        "companyId": "company-1",
        "roundHistory": history,
        "overallStatus": "active",
        "optedIn": None,
        "source": "gmail_ingestion",
    }


def store_with_prior(history, **status_overrides):
    status = prior_status(history)
    status.update(status_overrides)
    return FakeStore(
        companies={"company-1": {"name": "Rubrik", "rounds": list(ROUNDS)}},
        statuses={"student-1_company-1": status},
    )


def run(store, roster_type):
    graph = build_graph(
        make_deps(store=store, extractor=roster_extractor(roster_type))
    )
    return graph.invoke(
        base_state(student_identifiers=["22BCE9999"], known_company_id=None)
    )


def written(store):
    return store.statuses.get("student-1_company-1")


PRIOR = [
    {
        "roundId": "technical-round-1",
        "result": "invited",
        "sourceMessageId": "msg-0",
    }
]


def test_complete_final_roster_writes_not_listed():
    store = store_with_prior(PRIOR)

    result = run(store, "complete_final")

    assert result["matched"] is False
    assert result.get("not_listed") is True
    entry = written(store)["roundHistory"][0]
    assert entry["result"] == "not_listed"
    assert entry["sourceMessageId"] == "msg-1"
    assert entry["updatedAt"] == FIXED_NOW


def test_partial_roster_never_writes_not_listed():
    store = store_with_prior(PRIOR)

    result = run(store, "partial_or_unclear")

    assert result.get("not_listed") is not True
    assert result["halt_reason"] == "roster_not_final"
    assert store.put_status_calls == []
    assert written(store)["roundHistory"][0]["result"] == "invited"


def test_absent_roster_type_never_writes_not_listed():
    store = store_with_prior(PRIOR)

    result = run(store, None)

    assert result["halt_reason"] == "student_not_named"
    assert store.put_status_calls == []


def test_no_prior_status_doc_never_writes_not_listed():
    store = FakeStore(
        companies={"company-1": {"name": "Rubrik", "rounds": list(ROUNDS)}}
    )

    result = run(store, "complete_final")

    assert result["halt_reason"] == "no_prior_engagement"
    assert store.put_status_calls == []


def test_prior_doc_with_empty_history_never_writes_not_listed():
    store = store_with_prior([])

    result = run(store, "complete_final")

    assert result["halt_reason"] == "no_prior_engagement"
    assert store.put_status_calls == []


def test_opted_out_student_is_left_alone():
    store = store_with_prior(PRIOR, optedIn=False)

    result = run(store, "complete_final")

    assert result["halt_reason"] == "opted_out"
    assert store.put_status_calls == []


def test_a_cleared_round_is_never_downgraded():
    store = store_with_prior(
        [{"roundId": "technical-round-1", "result": "cleared"}]
    )

    result = run(store, "complete_final")

    assert result["halt_reason"] == "already_cleared"
    assert store.put_status_calls == []


def test_not_listed_on_an_earlier_round_keeps_the_later_one():
    store = store_with_prior(
        [
            {"roundId": "technical-round-1", "result": "cleared"},
            {"roundId": "hr-round", "result": "invited"},
        ]
    )
    store.companies["company-1"]["rounds"] = [
        {"id": "technical-round-1", "name": "Technical Round 1", "order": 1},
        {"id": "hr-round", "name": "HR Round", "order": 2},
    ]

    result = run(store, "complete_final")

    assert result["halt_reason"] == "already_cleared"


class TestOverallStatusDerivation:
    rounds = [
        {"id": "oa", "name": "OA", "order": 1},
        {"id": "final", "name": "Final interview", "order": 2},
    ]

    def test_not_listed_on_the_final_round_ends_tracking(self):
        history = [
            {"roundId": "oa", "result": "cleared"},
            {"roundId": "final", "result": "not_listed"},
        ]
        assert resolve_overall_status(history, self.rounds) == "rejected"

    def test_not_listed_on_an_earlier_round_does_not_end_tracking(self):
        history = [{"roundId": "oa", "result": "not_listed"}]
        assert resolve_overall_status(history, self.rounds) == "active"

    def test_cleared_on_the_final_round_still_wins(self):
        history = [{"roundId": "final", "result": "cleared"}]
        assert resolve_overall_status(history, self.rounds) == "selected"

    def test_an_explicit_rejection_still_wins_everywhere(self):
        history = [
            {"roundId": "oa", "result": "rejected"},
            {"roundId": "final", "result": "cleared"},
        ]
        assert resolve_overall_status(history, self.rounds) == "rejected"

    def test_not_listed_is_skipped_when_picking_the_current_round(self):
        history = [
            {"roundId": "oa", "result": "cleared"},
            {"roundId": "final", "result": "not_listed"},
        ]
        assert resolve_current_round_id(history, self.rounds) == "oa"

    def test_the_stored_result_stays_distinct_from_rejected(self):
        history = [{"roundId": "final", "result": "not_listed"}]
        assert resolve_overall_status(history, self.rounds) == "rejected"
        assert history[0]["result"] == "not_listed"
