from __future__ import annotations

import json
from pathlib import Path

import pytest

from orbit.branches import (
    COMPUTER_SCIENCE,
    POSTGRADUATE_LEVEL,
    UNDERGRADUATE,
    degree_level_for_code,
    levels_mentioned_in,
    ELECTRICAL,
    ELIGIBLE,
    INFORMATION_TECHNOLOGY,
    MECHANICAL,
    NOT_OPEN,
    POSTGRADUATE,
    UNKNOWN,
    branch_code_from_reg_no,
    branch_family_for_code,
    branch_family_for_reg_no,
    branch_relevance_for_reg_no,
    is_confident_mismatch,
)

CASES = json.loads(
    (Path(__file__).resolve().parents[2] / "test_fixtures" / "branch_cases.json")
    .read_text(encoding="utf-8")
)


@pytest.mark.parametrize("row", CASES["codes"], ids=lambda r: str(r["code"]))
def test_shared_table_codes(row):
    assert branch_family_for_code(row["code"]) == row["family"]


@pytest.mark.parametrize("row", CASES["regNos"], ids=lambda r: str(r["regNo"]))
def test_shared_table_reg_nos(row):
    assert branch_code_from_reg_no(row["regNo"]) == row["code"]
    assert branch_family_for_reg_no(row["regNo"]) == row["family"]


def _relevance_rows():
    rows = []
    for case in CASES["relevance"]:
        for reg_no, expected in case["expect"].items():
            rows.append(
                pytest.param(
                    case["eligibleBranches"],
                    reg_no,
                    expected,
                    id=f"{case['why']} :: {reg_no} :: {expected}",
                )
            )
    return rows


@pytest.mark.parametrize("branches,reg_no,expected", _relevance_rows())
def test_shared_table_relevance(branches, reg_no, expected):
    assert branch_relevance_for_reg_no(reg_no, branches) == expected


@pytest.mark.parametrize("row", CASES["levels"], ids=lambda r: str(r["code"]))
def test_shared_table_levels(row):
    assert degree_level_for_code(row["code"]) == row["level"]


class TestDegreeLevelDetection:
    def test_an_mtech_drive_reads_as_postgraduate_only(self):
        assert levels_mentioned_in("M.Tech CSE & IT related branches") == {
            POSTGRADUATE_LEVEL
        }
        assert levels_mentioned_in("M. Tech ( CSE / IT ) related branches only") == {
            POSTGRADUATE_LEVEL
        }

    def test_a_btech_drive_reads_as_undergraduate_only(self):
        assert levels_mentioned_in("B.Tech CSE/IT related branches") == {UNDERGRADUATE}
        assert levels_mentioned_in("B.E") == {UNDERGRADUATE}

    def test_a_drive_naming_both_reads_as_both(self):
        assert levels_mentioned_in("B.Tech/M.Tech CSE") == {
            UNDERGRADUATE,
            POSTGRADUATE_LEVEL,
        }

    def test_a_drive_naming_no_level_reads_as_nothing(self):
        assert levels_mentioned_in("Computer Science & Engineering") == set()
        assert levels_mentioned_in("CSE") == set()

    def test_a_level_mismatch_beats_a_branch_match(self):
        assert (
            branch_relevance_for_reg_no(
                "23BCT0098", ["M.Tech CSE & IT related branches"]
            )
            == NOT_OPEN
        )

    def test_the_live_mtech_drives_are_all_suppressed_for_a_btech_student(self):
        live = {
            "Voxela": ["M.Tech CSE & IT related branches"],
            "Face Prep": ["M. Tech ( CSE / IT ) related branches only"],
            "FlamAI": ["M.Tech( 2 yr & 5 Yr) CSE,IT,ECE,EEE related branches"],
            "Premas Life Science": ["M.Tech Biotechnology"],
        }
        for name, branches in live.items():
            assert (
                branch_relevance_for_reg_no("23BCT0098", branches) == NOT_OPEN
            ), name


class TestPrefixRules:
    def test_any_bc_code_is_cs(self):
        for code in ("BCA", "BCB", "BCT", "BCZ"):
            assert branch_family_for_code(code) == COMPUTER_SCIENCE

    def test_bit_is_it_and_not_swallowed(self):
        assert branch_family_for_code("BIT") == INFORMATION_TECHNOLOGY

    def test_any_be_code_is_electrical(self):
        for code in ("BEA", "BEC", "BEE", "BEZ"):
            assert branch_family_for_code(code) == ELECTRICAL

    def test_any_bm_code_is_mechanical(self):
        for code in ("BMA", "BME", "BMY"):
            assert branch_family_for_code(code) == MECHANICAL

    def test_anything_starting_with_m_is_postgraduate(self):
        for code in ("MCA", "MIC", "MTX", "MZZ"):
            assert branch_family_for_code(code) == POSTGRADUATE

    def test_everything_else_is_unknown(self):
        for code in ("BAI", "BBT", "BPS", "XYZ", "ABC"):
            assert branch_family_for_code(code) is None

    def test_case_and_padding_do_not_matter(self):
        assert branch_family_for_code("bct") == COMPUTER_SCIENCE
        assert branch_family_for_code("  bit  ") == INFORMATION_TECHNOLOGY


class TestConfidentMismatch:
    keyence = ["B.Tech Mech,EEE,ECE related branches"]

    def test_true_only_for_a_confident_mismatch(self):
        assert is_confident_mismatch("23BCT0098", self.keyence) is True

    def test_false_when_eligible(self):
        assert is_confident_mismatch("19BMY0042", self.keyence) is False

    def test_false_when_the_code_is_unknown(self):
        assert is_confident_mismatch("23BAI0210", self.keyence) is False

    def test_false_when_there_is_no_eligibility_text(self):
        assert is_confident_mismatch("23BCT0098", []) is False
        assert is_confident_mismatch("23BCT0098", None) is False

    def test_false_when_the_text_names_no_branch(self):
        assert is_confident_mismatch("23BCT0098", ["All B.Techs"]) is False

    def test_false_without_a_reg_no(self):
        assert is_confident_mismatch(None, self.keyence) is False
        assert is_confident_mismatch("", self.keyence) is False


def test_relevance_vocabulary_is_the_documented_three():
    assert {ELIGIBLE, NOT_OPEN, UNKNOWN} == {"eligible", "not_open", "unknown"}
