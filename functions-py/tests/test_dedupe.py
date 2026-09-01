from __future__ import annotations

from datetime import datetime, timedelta, timezone

from orbit.requirements import (
    NEOPAT_ID,
    build_requirements,
    dedupe_requirements,
    labels_match,
    merge_requirements,
    normalise_url,
)

NOW = datetime(2026, 9, 2, 12, 0, tzinfo=timezone.utc)
LATER = NOW + timedelta(days=1)


def req(kind, label, required=True, url=None):
    return {"type": kind, "label": label, "required": required, "url": url}


def test_neopat_id_is_a_constant_regardless_of_wording():
    a = build_requirements([req("neopat", "Register on NeoPAT")], NOW, "m1")
    b = build_requirements([req("neopat", "NEO PAT registration")], NOW, "m2")
    assert a[0]["id"] == b[0]["id"] == NEOPAT_ID


def test_reworded_neopat_merges_into_the_existing_one():
    existing = build_requirements([req("neopat", "Register on NeoPAT")], NOW, "m1")
    incoming = build_requirements(
        [req("neopat", "Register on NEO PAT platform")], LATER, "m2"
    )

    merged, _ = merge_requirements(existing, incoming)

    assert len(merged) == 1
    assert merged[0]["id"] == NEOPAT_ID
    assert merged[0]["addedAt"] == NOW


def test_several_neopat_mentions_in_one_mail_collapse_to_one():
    built = build_requirements(
        [
            req("neopat", "Register on NeoPAT"),
            req("neopat", "Update resume in NeoPAT portal"),
            req("neopat", "NEO PAT registration"),
        ],
        NOW,
        "m1",
    )
    assert len(built) == 1
    assert built[0]["id"] == NEOPAT_ID


def test_reworded_non_neopat_step_merges_on_label_overlap():
    existing = build_requirements(
        [req("company_site", "Company registration form")], NOW, "m1"
    )
    incoming = build_requirements(
        [req("company_site", "Company registration link")], LATER, "m2"
    )

    merged, _ = merge_requirements(existing, incoming)

    assert len(merged) == 1


def test_genuinely_different_steps_of_the_same_type_stay_separate():
    existing = build_requirements(
        [req("google_form", "Fill the academic gap declaration")], NOW, "m1"
    )
    incoming = build_requirements(
        [req("google_form", "Upload your passport photograph")], LATER, "m2"
    )

    merged, _ = merge_requirements(existing, incoming)

    assert len(merged) == 2


def test_identical_wording_in_two_companies_stays_separate():
    company_a = build_requirements([req("neopat", "Register on NeoPAT")], NOW, "m1")
    company_b = build_requirements([req("neopat", "Register on NeoPAT")], NOW, "m2")

    assert company_a is not company_b
    assert len(company_a) == 1 and len(company_b) == 1
    assert company_a[0]["sourceMessageId"] == "m1"
    assert company_b[0]["sourceMessageId"] == "m2"


def test_url_bearing_item_merges_with_a_later_url_less_mention():
    existing = build_requirements(
        [req("google_form", "Registration form", url="https://forms.gle/abc")],
        NOW,
        "m1",
    )
    incoming = build_requirements(
        [req("google_form", "Registration form")], LATER, "m2"
    )

    merged, _ = merge_requirements(existing, incoming)

    assert len(merged) == 1
    assert merged[0]["url"] == "https://forms.gle/abc"


def test_same_url_with_different_query_or_slash_is_one_item():
    existing = build_requirements(
        [req("google_form", "Form A", url="https://forms.gle/abc/")], NOW, "m1"
    )
    incoming = build_requirements(
        [req("google_form", "A completely different wording",
             url="https://forms.gle/abc?usp=sharing")],
        LATER,
        "m2",
    )

    merged, _ = merge_requirements(existing, incoming)

    assert len(merged) == 1


def test_url_normalisation_rules():
    assert normalise_url("https://Forms.GLE/abc/") == "https://forms.gle/abc"
    assert normalise_url("https://x.test/a?b=1#frag") == "https://x.test/a"
    assert normalise_url(None) == ""


def test_label_overlap_threshold():
    assert labels_match("Company registration form", "Company registration link")
    assert not labels_match("Upload resume", "Attend the pre placement talk")


def test_a_url_less_item_does_not_swallow_a_different_url_bearing_one():
    existing = build_requirements([req("company_site", "Apply on portal")], NOW, "m1")
    incoming = build_requirements(
        [req("company_site", "Submit the coding challenge",
             url="https://hackerrank.test/x")],
        LATER,
        "m2",
    )

    merged, _ = merge_requirements(existing, incoming)

    assert len(merged) == 2


def test_backfill_collapses_existing_duplicate_neopat_entries():
    stored = [
        {"id": "neopat-register-on-neopat", "type": "neopat",
         "label": "Register on NeoPAT", "url": None, "required": True,
         "addedAt": NOW, "sourceMessageId": "m1"},
        {"id": "company-site-company-registration-form", "type": "company_site",
         "label": "Company registration form", "url": None, "required": True,
         "addedAt": NOW, "sourceMessageId": "m1"},
        {"id": "neopat-neo-pat-registration", "type": "neopat",
         "label": "NEO PAT registration", "url": None, "required": True,
         "addedAt": LATER, "sourceMessageId": "m2"},
        {"id": "company-site-company-registration-link", "type": "company_site",
         "label": "Company registration link", "url": None, "required": True,
         "addedAt": LATER, "sourceMessageId": "m2"},
    ]

    merged, removed = dedupe_requirements(stored)

    ids = [r["id"] for r in merged]
    assert ids == [NEOPAT_ID, "company-site-company-registration-form"]
    assert set(removed) == {
        "neopat-neo-pat-registration",
        "company-site-company-registration-link",
    }
    assert merged[0]["addedAt"] == NOW


def test_backfill_is_idempotent():
    stored = build_requirements(
        [req("neopat", "Register on NeoPAT"), req("google_form", "Fill the form")],
        NOW,
        "m1",
    )
    once, removed_first = dedupe_requirements(stored)
    twice, removed_second = dedupe_requirements(once)

    assert removed_first == [] and removed_second == []
    assert [r["id"] for r in once] == [r["id"] for r in twice]


def test_a_lone_neopat_entry_is_renormalised_to_the_constant_id():
    stored = [
        {"id": "neopat-neo-pat-registration", "type": "neopat",
         "label": "NEO PAT registration", "url": None, "required": True,
         "addedAt": NOW, "sourceMessageId": "m1"},
    ]

    merged, removed = dedupe_requirements(stored)

    assert removed == []
    assert merged[0]["id"] == NEOPAT_ID
    assert merged[0]["label"] == "NEO PAT registration"
