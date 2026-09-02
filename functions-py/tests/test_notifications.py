from __future__ import annotations

from datetime import datetime, timedelta, timezone

from orbit.notifications import (
    TRIGGER_ACTION_NEEDED,
    TRIGGER_DEADLINE_HOUR,
    TRIGGER_NEW_ROUND,
    TRIGGER_ROUND_RESULT,
    Notification,
    outstanding_required_ids,
    plan_notifications,
    undelivered,
)

NOW = datetime(2026, 9, 2, 12, 0, tzinfo=timezone.utc)
SOON = NOW + timedelta(days=3)


def company(**overrides):
    base = {
        "id": "company-1",
        "name": "Rubrik",
        "status": "registration_open",
        "registrationDeadline": SOON,
        "requirements": [
            {"id": "neopat", "required": True},
            {"id": "form", "required": True},
            {"id": "optional-note", "required": False},
        ],
        "rounds": [
            {"id": "oa", "name": "Online assessment", "order": 1},
            {"id": "final", "name": "Final interview", "order": 2},
        ],
    }
    base.update(overrides)
    return base


def status(**overrides):
    base = {
        "studentId": "student-1",
        "companyId": "company-1",
        "completedRequirementIds": [],
        "roundHistory": [],
    }
    base.update(overrides)
    return base


UNSET = object()


def plan(before_status, after_status, before_company=UNSET, after_company=UNSET):
    return plan_notifications(
        before_status=before_status,
        after_status=after_status,
        before_company=company() if before_company is UNSET else before_company,
        after_company=company() if after_company is UNSET else after_company,
        now=NOW,
    )


def triggers(planned):
    return [n.trigger for n in planned]


class TestActionNeededFlip:
    def test_a_brand_new_drive_fires(self):
        planned = plan(None, None, before_company=None)
        assert triggers(planned) == [TRIGGER_ACTION_NEEDED]
        assert planned[0].body == "2 steps left before the deadline."

    def test_finishing_the_checklist_does_not_fire(self):
        planned = plan(
            status(),
            status(completedRequirementIds=["neopat", "form"]),
        )
        assert triggers(planned) == []

    def test_a_new_required_item_reopens_and_fires(self):
        done = company(
            requirements=[{"id": "neopat", "required": True}],
        )
        reopened = company(
            requirements=[
                {"id": "neopat", "required": True},
                {"id": "form", "required": True},
            ],
        )
        planned = plan(
            status(completedRequirementIds=["neopat"]),
            status(completedRequirementIds=["neopat"]),
            before_company=done,
            after_company=reopened,
        )
        assert triggers(planned) == [TRIGGER_ACTION_NEEDED]
        assert planned[0].body == "One step left before the deadline."

    def test_no_repeat_while_the_state_holds(self):
        planned = plan(status(), status())
        assert triggers(planned) == []

    def test_a_closed_drive_never_fires(self):
        planned = plan(
            None,
            None,
            before_company=None,
            after_company=company(status="closed"),
        )
        assert triggers(planned) == []

    def test_a_passed_deadline_never_fires(self):
        planned = plan(
            None,
            None,
            before_company=None,
            after_company=company(
                registrationDeadline=NOW - timedelta(days=1),
            ),
        )
        assert triggers(planned) == []

    def test_opting_out_silences_everything(self):
        planned = plan(None, status(optedIn=False), before_company=None)
        assert triggers(planned) == []

    def test_the_key_changes_when_the_outstanding_set_changes(self):
        first = plan(None, None, before_company=None)[0]
        narrower = plan(
            None,
            status(completedRequirementIds=["neopat"]),
            before_company=None,
        )[0]
        assert first.key != narrower.key


class TestUnderTheHourTier:
    def test_fires_urgent_inside_the_window(self):
        closing = company(registrationDeadline=NOW + timedelta(minutes=40))
        planned = plan(None, None, before_company=None, after_company=closing)
        assert TRIGGER_DEADLINE_HOUR in triggers(planned)
        urgent = [n for n in planned if n.trigger == TRIGGER_DEADLINE_HOUR][0]
        assert urgent.urgent is True

    def test_does_not_fire_outside_the_window(self):
        planned = plan(None, None, before_company=None)
        assert TRIGGER_DEADLINE_HOUR not in triggers(planned)

    def test_does_not_fire_once_the_deadline_has_passed(self):
        passed = company(registrationDeadline=NOW - timedelta(minutes=1))
        planned = plan(None, None, before_company=None, after_company=passed)
        assert TRIGGER_DEADLINE_HOUR not in triggers(planned)

    def test_does_not_fire_for_a_finished_checklist(self):
        closing = company(registrationDeadline=NOW + timedelta(minutes=40))
        planned = plan(
            status(),
            status(completedRequirementIds=["neopat", "form"]),
            before_company=closing,
            after_company=closing,
        )
        assert TRIGGER_DEADLINE_HOUR not in triggers(planned)

    def test_one_crossing_yields_one_key(self):
        closing = company(registrationDeadline=NOW + timedelta(minutes=40))
        first = plan(None, None, before_company=None, after_company=closing)
        second = plan(status(), status(), before_company=closing, after_company=closing)
        keys = {n.key for n in first if n.trigger == TRIGGER_DEADLINE_HOUR}
        repeat = {n.key for n in second if n.trigger == TRIGGER_DEADLINE_HOUR}
        assert repeat <= keys

    def test_an_extended_deadline_is_a_new_crossing(self):
        first = company(registrationDeadline=NOW + timedelta(minutes=40))
        extended = company(registrationDeadline=NOW + timedelta(minutes=50))
        a = [n for n in plan(None, None, None, first) if n.urgent][0]
        b = [n for n in plan(None, None, None, extended) if n.urgent][0]
        assert a.key != b.key


class TestRoundResults:
    def each_result(self, result):
        return plan(
            status(roundHistory=[{"roundId": "oa", "result": "invited"}]),
            status(roundHistory=[{"roundId": "oa", "result": result}]),
        )

    def test_cleared_fires(self):
        planned = self.each_result("cleared")
        assert triggers(planned) == [TRIGGER_ROUND_RESULT]
        assert planned[0].title == "Rubrik: you are through"
        assert planned[0].body == "You cleared Online assessment."

    def test_rejected_fires(self):
        planned = self.each_result("rejected")
        assert planned[0].title == "Rubrik: not selected"

    def test_not_listed_fires_with_its_own_wording(self):
        planned = self.each_result("not_listed")
        assert planned[0].title == "Rubrik: not shortlisted"
        assert planned[0].body == "You are not on the Online assessment list."

    def test_invited_and_pending_do_not_fire(self):
        assert triggers(self.each_result("pending")) == []
        planned = plan(
            status(),
            status(roundHistory=[{"roundId": "oa", "result": "invited"}]),
        )
        assert TRIGGER_ROUND_RESULT not in triggers(planned)

    def test_an_unchanged_result_does_not_refire(self):
        settled = status(roundHistory=[{"roundId": "oa", "result": "cleared"}])
        assert triggers(plan(settled, settled)) == []

    def test_a_correction_to_a_different_result_fires_again(self):
        planned = plan(
            status(roundHistory=[{"roundId": "oa", "result": "cleared"}]),
            status(roundHistory=[{"roundId": "oa", "result": "rejected"}]),
        )
        assert triggers(planned) == [TRIGGER_ROUND_RESULT]

    def test_each_round_carries_its_own_key(self):
        planned = plan(
            status(roundHistory=[{"roundId": "oa", "result": "cleared"}]),
            status(
                roundHistory=[
                    {"roundId": "oa", "result": "cleared"},
                    {"roundId": "final", "result": "cleared"},
                ]
            ),
        )
        assert len(planned) == 1
        assert planned[0].key == f"{TRIGGER_ROUND_RESULT}:final:cleared"


class TestNewRound:
    def test_a_first_round_fires(self):
        planned = plan(status(), status(currentRoundId="oa"))
        assert TRIGGER_NEW_ROUND in triggers(planned)
        assert [n for n in planned if n.trigger == TRIGGER_NEW_ROUND][
            0
        ].title == "Rubrik: Online assessment"

    def test_moving_forward_fires_again(self):
        planned = plan(
            status(
                currentRoundId="oa",
                roundHistory=[{"roundId": "oa", "result": "cleared"}],
            ),
            status(
                currentRoundId="final",
                roundHistory=[
                    {"roundId": "oa", "result": "cleared"},
                    {"roundId": "final", "result": "invited"},
                ],
            ),
        )
        assert TRIGGER_NEW_ROUND in triggers(planned)

    def test_an_unchanged_round_does_not_fire(self):
        settled = status(currentRoundId="oa")
        assert TRIGGER_NEW_ROUND not in triggers(plan(settled, settled))

    def test_falling_back_to_an_earlier_round_does_not_fire(self):
        planned = plan(
            status(
                currentRoundId="final",
                roundHistory=[{"roundId": "oa", "result": "cleared"}],
            ),
            status(
                currentRoundId="oa",
                roundHistory=[{"roundId": "oa", "result": "cleared"}],
            ),
        )
        assert TRIGGER_NEW_ROUND not in triggers(planned)


class TestDedup:
    def test_an_already_sent_key_is_dropped(self):
        planned = [
            Notification(
                trigger=TRIGGER_ACTION_NEEDED,
                key="action_needed:neopat",
                title="t",
                body="b",
                company_id="company-1",
            )
        ]
        assert undelivered(planned, ["action_needed:neopat"]) == []
        assert undelivered(planned, []) == planned

    def test_duplicates_inside_one_batch_collapse(self):
        one = Notification(
            trigger=TRIGGER_NEW_ROUND,
            key="new_round:oa",
            title="t",
            body="b",
            company_id="company-1",
        )
        assert undelivered([one, one], []) == [one]

    def test_an_unrelated_key_is_kept(self):
        planned = [
            Notification(
                trigger=TRIGGER_NEW_ROUND,
                key="new_round:final",
                title="t",
                body="b",
                company_id="company-1",
            )
        ]
        assert undelivered(planned, ["new_round:oa"]) == planned


def test_outstanding_ids_ignore_optional_items():
    assert outstanding_required_ids(company(), status()) == ["form", "neopat"]
    assert outstanding_required_ids(
        company(), status(completedRequirementIds=["form", "neopat"])
    ) == []
