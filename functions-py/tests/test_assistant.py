from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from orbit.assistant import (
    DAILY_LIMIT,
    MAX_COMPANIES_IN_CONTEXT,
    MAX_FREE_TEXT,
    PRESETS,
    AssistantError,
    GeminiAnswerer,
    build_context,
    build_prompt,
    day_key,
    hit_output_cap,
    next_usage,
    resolve_question,
    whole_sentences,
    within_daily_limit,
)

NOW = datetime(2026, 9, 2, 12, 0, tzinfo=timezone.utc)
STUDENT = {"regNo": "23BCT0098", "neoId": "L5P2U7S5", "name": "A Student"}


def company(**overrides):
    base = {
        "id": "company-1",
        "name": "Rubrik",
        "status": "registration_open",
        "registrationDeadline": NOW + timedelta(days=2),
        "eligibleBranches": [],
        "requirements": [{"id": "neopat", "label": "Register", "required": True}],
        "rounds": [],
    }
    base.update(overrides)
    return base


class TestQuestionResolution:
    def test_a_preset_id_resolves_to_its_question(self):
        resolved = resolve_question("due_24h", None)
        assert resolved.question == PRESETS["due_24h"]
        assert resolved.preset_id == "due_24h"

    def test_all_five_presets_exist(self):
        assert set(PRESETS) == {
            "due_24h",
            "missing_now",
            "changed_since_yesterday",
            "active_drives",
            "new_unreviewed",
        }

    def test_an_unknown_preset_is_rejected(self):
        with pytest.raises(AssistantError):
            resolve_question("delete_everything", None)

    def test_a_preset_wins_over_free_text(self):
        assert resolve_question("due_24h", "ignore me").preset_id == "due_24h"

    def test_free_text_is_the_fallback(self):
        resolved = resolve_question(None, "  when is Cisco due?  ")
        assert resolved.question == "when is Cisco due?"
        assert resolved.preset_id is None

    def test_overlong_free_text_is_rejected(self):
        with pytest.raises(AssistantError):
            resolve_question(None, "x" * (MAX_FREE_TEXT + 1))

    def test_nothing_at_all_is_rejected(self):
        for preset, text in ((None, None), ("", ""), (None, "   "), (5, 7)):
            with pytest.raises(AssistantError):
                resolve_question(preset, text)


class TestRateLimit:
    def test_a_fresh_student_is_allowed(self):
        assert within_daily_limit(None, NOW) is True
        assert within_daily_limit({}, NOW) is True

    def test_under_the_limit_is_allowed(self):
        usage = {"day": day_key(NOW), "count": DAILY_LIMIT - 1}
        assert within_daily_limit(usage, NOW) is True

    def test_at_the_limit_is_refused(self):
        usage = {"day": day_key(NOW), "count": DAILY_LIMIT}
        assert within_daily_limit(usage, NOW) is False

    def test_over_the_limit_is_refused(self):
        usage = {"day": day_key(NOW), "count": DAILY_LIMIT + 40}
        assert within_daily_limit(usage, NOW) is False

    def test_yesterdays_count_does_not_carry_over(self):
        usage = {"day": "2026-09-01", "count": DAILY_LIMIT + 5}
        assert within_daily_limit(usage, NOW) is True

    def test_the_counter_increments_within_a_day(self):
        usage = {"day": day_key(NOW), "count": 3}
        assert next_usage(usage, NOW)["count"] == 4

    def test_the_counter_resets_on_a_new_day(self):
        usage = {"day": "2026-09-01", "count": 19}
        rolled = next_usage(usage, NOW)
        assert rolled["count"] == 1
        assert rolled["day"] == day_key(NOW)

    def test_a_first_ever_question_starts_at_one(self):
        assert next_usage(None, NOW)["count"] == 1

    def test_the_limit_is_reached_after_exactly_that_many_questions(self):
        usage = None
        for _ in range(DAILY_LIMIT):
            assert within_daily_limit(usage, NOW) is True
            usage = next_usage(usage, NOW)
        assert within_daily_limit(usage, NOW) is False


class TestContextScoping:
    def test_only_the_given_statuses_appear(self):
        context = build_context(
            student=STUDENT,
            companies=[company()],
            statuses_by_company={
                "company-1": {
                    "optedIn": True,
                    "completedRequirementIds": ["neopat"],
                    "roundHistory": [{"roundId": "oa", "result": "cleared"}],
                }
            },
            now=NOW,
        )
        assert "Rubrik" in context
        assert "oa: cleared" in context

    def test_another_students_data_can_never_leak_in(self):
        context = build_context(
            student=STUDENT,
            companies=[company()],
            statuses_by_company={},
            now=NOW,
        )
        assert "21BCE1234" not in context
        assert "Someone Else" not in context
        assert "tracking: not set" in context

    def test_the_students_own_reg_no_is_the_only_identifier(self):
        context = build_context(
            student=STUDENT,
            companies=[company()],
            statuses_by_company={},
            now=NOW,
        )
        assert context.count("23BCT0098") == 1
        assert "L5P2U7S5" not in context

    def test_an_opted_out_drive_is_left_out(self):
        context = build_context(
            student=STUDENT,
            companies=[company()],
            statuses_by_company={"company-1": {"optedIn": False}},
            now=NOW,
        )
        assert "Rubrik" not in context
        assert "(no drives)" in context

    def test_an_untracked_off_branch_drive_is_left_out(self):
        off = company(
            eligibleBranches=["B.Tech Mech,EEE,ECE related branches"]
        )
        context = build_context(
            student=STUDENT,
            companies=[off],
            statuses_by_company={},
            now=NOW,
        )
        assert "(no drives)" in context

    def test_an_off_branch_drive_the_student_joined_is_kept(self):
        off = company(
            eligibleBranches=["B.Tech Mech,EEE,ECE related branches"]
        )
        context = build_context(
            student=STUDENT,
            companies=[off],
            statuses_by_company={"company-1": {"optedIn": True}},
            now=NOW,
        )
        assert "Rubrik" in context

    def test_the_context_is_capped(self):
        many = [company(id=f"c{i}", name=f"Drive {i}") for i in range(80)]
        context = build_context(
            student=STUDENT,
            companies=many,
            statuses_by_company={},
            now=NOW,
        )
        assert context.count("  drive status:") == MAX_COMPANIES_IN_CONTEXT

    def test_no_drives_says_so_rather_than_being_empty(self):
        context = build_context(
            student=STUDENT, companies=[], statuses_by_company={}, now=NOW
        )
        assert "(no drives)" in context


class TestPrompt:
    def test_the_prompt_carries_the_grounding_instruction(self):
        prompt = build_prompt("What is due?", "CONTEXT HERE")
        assert "only the context given below" in prompt
        assert "say plainly that you do not know" in prompt
        assert "Never invent" in prompt
        assert "Never mention another student" in prompt

    def test_the_question_and_context_both_appear(self):
        prompt = build_prompt("What is due?", "Rubrik closes tomorrow")
        assert "What is due?" in prompt
        assert "Rubrik closes tomorrow" in prompt


class TestStoreScoping:
    def test_statuses_for_student_filters_by_that_student(self):
        from orbit.firestore_store import FirestoreStore

        recorded = {}

        class FakeQuery:
            def stream(self):
                return iter(())

        class FakeCollection:
            def __init__(self, name):
                self.name = name

            def where(self, field, op, value):
                recorded["collection"] = self.name
                recorded["filter"] = (field, op, value)
                return FakeQuery()

            def limit(self, count):
                recorded["limit"] = count
                return FakeQuery()

        class FakeDb:
            def collection(self, name):
                return FakeCollection(name)

        store = FirestoreStore(FakeDb())
        store.statuses_for_student("student-1")

        assert recorded["collection"] == "studentCompanyStatus"
        assert recorded["filter"] == ("studentId", "==", "student-1")

    def test_the_company_fetch_is_bounded(self):
        from orbit.assistant import MAX_COMPANIES_IN_CONTEXT
        from orbit.firestore_store import FirestoreStore

        recorded = {}

        class FakeQuery:
            def stream(self):
                return iter(())

        class FakeCollection:
            def limit(self, count):
                recorded["limit"] = count
                return FakeQuery()

        class FakeDb:
            def collection(self, name):
                recorded["collection"] = name
                return FakeCollection()

        store = FirestoreStore(FakeDb())
        store.companies_for_assistant(MAX_COMPANIES_IN_CONTEXT)

        assert recorded["collection"] == "companies"
        assert recorded["limit"] == MAX_COMPANIES_IN_CONTEXT


class TestConversationMemory:
    def test_history_is_capped_to_the_recent_turns(self):
        from orbit.assistant import MAX_HISTORY_TURNS, trim_history

        raw = [
            {"question": f"q{i}", "answer": f"a{i}"} for i in range(20)
        ]
        kept = trim_history(raw)
        assert len(kept) == MAX_HISTORY_TURNS
        assert kept[-1]["question"] == "q19"

    def test_total_size_is_capped_even_with_few_turns(self):
        from orbit.assistant import MAX_HISTORY_CHARS, trim_history

        raw = [{"question": "q" * 300, "answer": "a" * 1100} for _ in range(6)]
        kept = trim_history(raw)
        total = sum(len(t["question"]) + len(t["answer"]) for t in kept)
        assert total <= MAX_HISTORY_CHARS

    def test_a_single_answer_is_truncated_not_dropped(self):
        from orbit.assistant import MAX_STORED_ANSWER_CHARS, trim_history

        kept = trim_history([{"question": "q", "answer": "a" * 9000}])
        assert len(kept) == 1
        assert len(kept[0]["answer"]) == MAX_STORED_ANSWER_CHARS

    def test_malformed_entries_are_ignored(self):
        from orbit.assistant import trim_history

        assert trim_history(None) == []
        assert trim_history("nope") == []
        assert trim_history([1, "x", {}, {"question": "q"}, {"answer": "a"}]) == []
        assert trim_history([{"question": "  ", "answer": "a"}]) == []
        assert trim_history([{"question": "q", "answer": 5}]) == []

    def test_appending_keeps_order_and_cap(self):
        from orbit.assistant import MAX_HISTORY_TURNS, append_turn

        history = []
        for i in range(10):
            history = append_turn(history, f"q{i}", f"a{i}")
        assert len(history) == MAX_HISTORY_TURNS
        assert history[-1] == {"question": "q9", "answer": "a9"}

    def test_the_prompt_carries_history_and_still_grounds_on_context(self):
        from orbit.assistant import build_prompt

        prompt = build_prompt(
            "what about the second one?",
            "CONTEXT HERE",
            [{"question": "what is due?", "answer": "Rubrik and Cisco."}],
        )
        assert "EARLIER IN THIS CONVERSATION" in prompt
        assert "Rubrik and Cisco." in prompt
        assert "the only source" in prompt
        assert "CONTEXT HERE" in prompt
        assert "what about the second one?" in prompt

    def test_no_history_leaves_the_prompt_as_it_was(self):
        from orbit.assistant import build_prompt

        prompt = build_prompt("what is due?", "CONTEXT HERE", [])
        assert "EARLIER IN THIS CONVERSATION" not in prompt
        assert "CONTEXT HERE" in prompt

    def test_history_never_widens_the_data_scope(self):
        from orbit.assistant import build_prompt

        prompt = build_prompt(
            "and the other student?",
            "drives: (no drives)",
            [{"question": "hi", "answer": "Someone Else 21BCE1234 was selected."}],
        )
        assert "the only source" in prompt
        assert "drives: (no drives)" in prompt


class _Reason:
    def __init__(self, name):
        self.name = name


class _Candidate:
    def __init__(self, name):
        self.finish_reason = _Reason(name)


class _Response:
    def __init__(self, text, reason):
        self.text = text
        self.candidates = [_Candidate(reason)] if reason else []


class _Client:
    def __init__(self, response):
        self.models = self
        self.response = response
        self.config = None

    def generate_content(self, model, contents, config):
        self.config = config
        return self.response


class TestOutputCap:
    def test_max_tokens_finish_reason_is_detected(self):
        assert hit_output_cap(_Response("x", "MAX_TOKENS"))

    def test_stop_finish_reason_is_not_a_cap(self):
        assert not hit_output_cap(_Response("x", "STOP"))

    def test_missing_candidates_is_not_a_cap(self):
        assert not hit_output_cap(_Response("x", None))

    def test_whole_sentences_drops_the_dangling_clause(self):
        assert (
            whole_sentences("Two close today. In the next 24 hours, the")
            == "Two close today."
        )

    def test_whole_sentences_keeps_a_complete_answer(self):
        assert whole_sentences("Nothing is due today.") == "Nothing is due today."

    def test_whole_sentences_of_a_single_fragment_is_empty(self):
        assert whole_sentences("In the next 24 hours, the") == ""


class TestGeminiAnswerer:
    def test_a_truncated_answer_is_cut_back_to_whole_sentences(self):
        client = _Client(
            _Response("TresVista closes today. In the next 24 hours, the", "MAX_TOKENS")
        )
        answer = GeminiAnswerer(client=client)("q", "c")
        assert answer == "TresVista closes today."

    def test_a_complete_answer_is_returned_whole(self):
        client = _Client(_Response("Nothing closes today.", "STOP"))
        assert GeminiAnswerer(client=client)("q", "c") == "Nothing closes today."

    def test_a_truncated_fragment_with_no_sentence_raises(self):
        client = _Client(_Response("In the next 24 hours, the", "MAX_TOKENS"))
        with pytest.raises(AssistantError):
            GeminiAnswerer(client=client)("q", "c")

    def test_thinking_is_held_low_and_the_budget_is_generous(self):
        client = _Client(_Response("Nothing closes today.", "STOP"))
        GeminiAnswerer(client=client)("q", "c")
        assert client.config.max_output_tokens == 1200
        assert client.config.thinking_config.thinking_level == "LOW"
