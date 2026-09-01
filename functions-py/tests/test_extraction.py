from __future__ import annotations

import json

import pytest

from orbit.extraction import ExtractionResult, GeminiExtractor, build_prompt

SAMPLE = {
    "is_placement_mail": True,
    "company": {
        "name": "Rubrik",
        "category": "Super Dream",
        "ctc": "32 LPA",
        "stipend": None,
        "eligible_branches": ["CSE"],
        "eligibility_criteria": None,
        "registration_deadline": None,
        "visit_date": None,
    },
    "round": {
        "name": "Technical Round 1",
        "type": "interview",
        "is_new_round": True,
        "result": "invited",
    },
    "requirements": [],
}


class FakeResponse:
    def __init__(self, parsed=None, text=None):
        self.parsed = parsed
        self.text = text


class FakeModels:
    def __init__(self, response):
        self.response = response
        self.calls = []

    def generate_content(self, *, model, contents, config):
        self.calls.append({"model": model, "contents": contents, "config": config})
        return self.response


class FakeClient:
    def __init__(self, response):
        self.models = FakeModels(response)


def test_prompt_carries_sender_and_subject():
    prompt = build_prompt("placements@vit.ac.in", "Rubrik shortlist", "Body here")
    assert "placements@vit.ac.in" in prompt
    assert "Rubrik shortlist" in prompt
    assert prompt.endswith("Body here")


def test_parsed_pydantic_instance_is_returned_as_a_dict():
    client = FakeClient(FakeResponse(parsed=ExtractionResult.model_validate(SAMPLE)))
    extractor = GeminiExtractor(client=client)

    result = extractor("placements@vit.ac.in", "Rubrik shortlist", "body")

    assert result["company"]["name"] == "Rubrik"
    assert result["round"]["result"] == "invited"
    assert result["is_placement_mail"] is True


def test_request_asks_for_json_against_the_pydantic_schema():
    client = FakeClient(FakeResponse(parsed=ExtractionResult.model_validate(SAMPLE)))
    extractor = GeminiExtractor(client=client, model="gemini-3.7-flash")

    extractor("placements@vit.ac.in", "Rubrik shortlist", "body")

    call = client.models.calls[0]
    assert call["model"] == "gemini-3.7-flash"
    assert call["config"].response_mime_type == "application/json"
    assert call["config"].response_schema is ExtractionResult
    assert call["config"].temperature == 0


def test_dict_parsed_is_validated_against_the_schema():
    client = FakeClient(FakeResponse(parsed=SAMPLE))
    extractor = GeminiExtractor(client=client)

    result = extractor("s", "s", "b")

    assert result["company"]["ctc"] == "32 LPA"


def test_falls_back_to_raw_text_when_parsed_is_missing():
    client = FakeClient(FakeResponse(parsed=None, text=json.dumps(SAMPLE)))
    extractor = GeminiExtractor(client=client)

    result = extractor("s", "s", "b")

    assert result["round"]["name"] == "Technical Round 1"


def test_empty_response_raises_rather_than_returning_junk():
    client = FakeClient(FakeResponse(parsed=None, text=None))
    extractor = GeminiExtractor(client=client)

    with pytest.raises(ValueError):
        extractor("s", "s", "b")


def test_non_placement_mail_is_representable():
    payload = {
        **SAMPLE,
        "is_placement_mail": False,
        "round": {"name": None, "type": None, "is_new_round": False, "result": None},
    }
    client = FakeClient(FakeResponse(parsed=ExtractionResult.model_validate(payload)))
    extractor = GeminiExtractor(client=client)

    result = extractor("s", "s", "b")

    assert result["is_placement_mail"] is False
    assert result["round"]["name"] is None
