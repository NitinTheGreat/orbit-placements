from __future__ import annotations

import json
import os
from typing import Literal

from pydantic import BaseModel, Field

EXTRACTION_MODEL = os.environ.get("ORBIT_EXTRACTION_MODEL", "gemini-3.7-flash")

SYSTEM_PROMPT = (
    "You read placement emails sent to students at VIT and turn them into "
    "structured records. Report only what the email states. When a field is "
    "not stated, leave it null rather than inferring it. The email may "
    "announce a new drive, announce a new round of an existing drive, or "
    "report the result of a round that already happened. "
    "For requirements, list only steps the email actually asks students to "
    "do. Use type 'neopat' only when the email explicitly mentions NeoPAT or "
    "NeoPAT registration; never infer NeoPAT from the fact that this is a "
    "placement drive. Use 'google_form' for a Google Form link, "
    "'company_site' for a registration page on the company's own site, and "
    "'other' for anything else."
)


class RoundInfo(BaseModel):
    name: str | None = Field(
        default=None,
        description="Name of the round this email is about, as written in the email.",
    )
    type: Literal["ppt", "oa", "interview", "other"] | None = None
    is_new_round: bool = Field(
        default=False,
        description="True when the email announces a round happening in future.",
    )
    result: Literal["invited", "cleared", "rejected", "pending"] | None = Field(
        default=None,
        description="Outcome this email conveys for the students it names.",
    )


class CompanyInfo(BaseModel):
    name: str | None = None
    category: str | None = Field(
        default=None, description="Such as Super Dream, Dream, or Core."
    )
    ctc: str | None = Field(default=None, description="Verbatim, such as '12 LPA'.")
    stipend: str | None = None
    eligible_branches: list[str] = Field(default_factory=list)
    eligibility_criteria: str | None = None
    registration_deadline: str | None = Field(
        default=None, description="ISO 8601 date or datetime if stated."
    )
    visit_date: str | None = Field(default=None, description="ISO 8601 date if stated.")


class RequirementInfo(BaseModel):
    type: Literal["neopat", "google_form", "company_site", "other"] = "other"
    label: str
    url: str | None = None
    required: bool = True


class ExtractionResult(BaseModel):
    is_placement_mail: bool = Field(
        description="False when the email is not about a placement drive at all."
    )
    company: CompanyInfo
    round: RoundInfo
    requirements: list[RequirementInfo] = Field(default_factory=list)


def build_prompt(sender: str, subject: str, body: str) -> str:
    return f"From: {sender}\nSubject: {subject}\n\n{body}"


class GeminiExtractor:
    def __init__(self, client=None, model: str = EXTRACTION_MODEL):
        self._client = client
        self._model = model

    def _ensure_client(self):
        if self._client is None:
            from google import genai

            self._client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))
        return self._client

    def __call__(self, sender: str, subject: str, body: str) -> dict:
        from google.genai import types

        client = self._ensure_client()
        response = client.models.generate_content(
            model=self._model,
            contents=build_prompt(sender, subject, body),
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                response_mime_type="application/json",
                response_schema=ExtractionResult,
                temperature=0,
                automatic_function_calling=types.AutomaticFunctionCallingConfig(
                    disable=True
                ),
            ),
        )

        parsed = response.parsed
        if isinstance(parsed, ExtractionResult):
            return parsed.model_dump()
        if isinstance(parsed, dict):
            return ExtractionResult.model_validate(parsed).model_dump()
        if response.text:
            return ExtractionResult.model_validate(
                json.loads(response.text)
            ).model_dump()
        raise ValueError("Gemini returned no parsable extraction result")
