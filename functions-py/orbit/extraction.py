from __future__ import annotations

import os
from typing import Literal

from pydantic import BaseModel, Field

EXTRACTION_MODEL = os.environ.get("ORBIT_EXTRACTION_MODEL", "claude-opus-5")

SYSTEM_PROMPT = (
    "You read placement emails sent to students at VIT and turn them into "
    "structured records. Report only what the email states. When a field is "
    "not stated, leave it null rather than inferring it. The email may "
    "announce a new drive, announce a new round of an existing drive, or "
    "report the result of a round that already happened."
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
    type: str = "other"
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
    return (
        f"From: {sender}\n"
        f"Subject: {subject}\n\n"
        f"{body}"
    )


class AnthropicExtractor:
    def __init__(self, client=None, model: str = EXTRACTION_MODEL):
        self._client = client
        self._model = model

    def _ensure_client(self):
        if self._client is None:
            import anthropic

            self._client = anthropic.Anthropic()
        return self._client

    def __call__(self, sender: str, subject: str, body: str) -> dict:
        client = self._ensure_client()
        response = client.messages.parse(
            model=self._model,
            max_tokens=4000,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": build_prompt(sender, subject, body)}],
            output_format=ExtractionResult,
        )
        return response.parsed_output.model_dump()
