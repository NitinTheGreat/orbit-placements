from __future__ import annotations

import json
from pathlib import Path

import pytest

from orbit.branches import (
    COMPUTER_SCIENCE,
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
