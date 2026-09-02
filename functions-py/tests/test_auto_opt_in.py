from __future__ import annotations

import copy

from orbit.graph import build_graph

from .test_graph import (
    FakeGmail,
    FakeStore,
    RecordingExtractor,
    base_state,
    make_deps,
)

MECH_ONLY = ["B.Tech Mech,EEE,ECE related branches"]
CSE_ONLY = ["B.Tech CSE/IT related branches"]
NO_BRANCHES: list[str] = []


def extractor_with(eligible_branches):
    extractor = RecordingExtractor()
    extractor.result = copy.deepcopy(extractor.result)
    extractor.result["company"]["eligible_branches"] = eligible_branches
    return extractor


def body_naming(identifiers):
    rows = "".join(f"<p>{value} A Student</p>" for value in identifiers)
    return (
        "<p>Dear Students,</p><p>The following students are shortlisted for "
        "the Technical Round 1 of the Rubrik drive.</p>" + rows
    )


def run(eligible_branches, identifiers, existing_status=None):
    statuses = {}
    if existing_status is not None:
        statuses["student-1_company-1"] = existing_status
    store = FakeStore(
        companies={
            "company-1": {
                "name": "Rubrik",
                "rounds": [],
                "eligibleBranches": eligible_branches,
            }
        },
        statuses=statuses,
    )
    graph = build_graph(
        make_deps(
            store=store,
            gmail=FakeGmail(body=body_naming(identifiers)),
            extractor=extractor_with(eligible_branches),
        )
    )
    graph.invoke(base_state(student_identifiers=identifiers))
    return store


def written_opt_in(store):
    assert store.put_status_calls, "expected a status write"
    return store.put_status_calls[-1]["optedIn"]


CSE_STUDENT = ["L5P2U7S5", "23BCT0098"]
MECH_STUDENT = ["L5P2U7S5", "19BMY0042"]
UNKNOWN_STUDENT = ["L5P2U7S5", "23BAI0210"]


class TestSuppression:
    def test_a_confident_mismatch_is_not_auto_tracked(self):
        store = run(MECH_ONLY, CSE_STUDENT)
        assert written_opt_in(store) is None

    def test_an_eligible_student_is_auto_tracked(self):
        store = run(MECH_ONLY, MECH_STUDENT)
        assert written_opt_in(store) is True

    def test_an_unknown_branch_code_still_auto_tracks(self):
        store = run(MECH_ONLY, UNKNOWN_STUDENT)
        assert written_opt_in(store) is True

    def test_no_eligibility_text_still_auto_tracks(self):
        store = run(NO_BRANCHES, CSE_STUDENT)
        assert written_opt_in(store) is True

    def test_text_naming_no_branch_still_auto_tracks(self):
        store = run(["All B.Techs"], CSE_STUDENT)
        assert written_opt_in(store) is True

    def test_a_matching_drive_auto_tracks(self):
        store = run(CSE_ONLY, CSE_STUDENT)
        assert written_opt_in(store) is True

    def test_a_student_with_no_reg_no_still_auto_tracks(self):
        store = run(MECH_ONLY, ["L5P2U7S5"])
        assert written_opt_in(store) is True


class TestExistingChoiceWins:
    def test_an_explicit_opt_in_survives_a_mismatch(self):
        store = run(
            MECH_ONLY,
            CSE_STUDENT,
            existing_status={
                "studentId": "student-1",
                "companyId": "company-1",
                "optedIn": True,
                "roundHistory": [],
            },
        )
        assert written_opt_in(store) is True

    def test_an_explicit_opt_out_is_never_overwritten(self):
        store = run(
            CSE_ONLY,
            CSE_STUDENT,
            existing_status={
                "studentId": "student-1",
                "companyId": "company-1",
                "optedIn": False,
                "roundHistory": [],
            },
        )
        assert store.put_status_calls == []
