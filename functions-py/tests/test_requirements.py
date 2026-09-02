from __future__ import annotations

from datetime import datetime, timedelta, timezone

from orbit.derived import (
    action_needed,
    application_complete,
    completed_required_count,
)
from orbit.store import build_requirements, merge_requirements

NOW = datetime(2026, 9, 2, 12, 0, tzinfo=timezone.utc)
FUTURE = NOW + timedelta(days=3)
PAST = NOW - timedelta(days=3)


def req(kind, label, required=True, url=None):
    return {"type": kind, "label": label, "required": required, "url": url}


def test_ids_are_stable_across_runs_and_include_the_type():
    first = build_requirements([req("google_form", "Fill the form")], NOW, "m1")
    second = build_requirements([req("google_form", "Fill the form")], NOW, "m2")
    assert first[0]["id"] == second[0]["id"] == "google-form-fill-the-form"


def test_same_label_under_two_types_gets_two_ids():
    built = build_requirements(
        [req("neopat", "Register"), req("company_site", "Register")], NOW, "m1"
    )
    assert {r["id"] for r in built} == {"neopat-register", "company-site-register"}


def test_build_records_provenance():
    built = build_requirements([req("neopat", "Register on NeoPAT")], NOW, "m7")
    assert built[0]["addedAt"] == NOW
    assert built[0]["sourceMessageId"] == "m7"


def test_merge_adds_new_items_without_dropping_old_ones():
    existing = build_requirements([req("google_form", "Fill the form")], NOW, "m1")
    incoming = build_requirements([req("neopat", "Register on NeoPAT")], NOW, "m2")

    merged, newly_required = merge_requirements(existing, incoming)

    assert [r["id"] for r in merged] == [
        "google-form-fill-the-form",
        "neopat-register-on-neopat",
    ]
    assert [r["id"] for r in newly_required] == ["neopat-register-on-neopat"]


def test_merge_never_removes_an_id_a_later_mail_omitted():
    existing = build_requirements(
        [req("google_form", "Fill the form"), req("neopat", "Register on NeoPAT")],
        NOW,
        "m1",
    )
    incoming = build_requirements([req("google_form", "Fill the form")], NOW, "m2")

    merged, _ = merge_requirements(existing, incoming)

    assert len(merged) == 2
    assert "neopat-register-on-neopat" in {r["id"] for r in merged}


def test_merge_updates_label_url_and_required_in_place():
    existing = build_requirements(
        [req("google_form", "Fill the form", required=False)], NOW, "m1"
    )
    incoming = build_requirements(
        [req("google_form", "Fill the form", required=True, url="https://x.test")],
        NOW,
        "m2",
    )

    merged, newly_required = merge_requirements(existing, incoming)

    assert len(merged) == 1
    assert merged[0]["url"] == "https://x.test"
    assert merged[0]["required"] is True
    assert [r["id"] for r in newly_required] == ["google-form-fill-the-form"]


def test_merge_keeps_the_original_addedAt():
    existing = build_requirements([req("google_form", "Fill the form")], NOW, "m1")
    later = NOW + timedelta(days=1)
    incoming = build_requirements([req("google_form", "Fill the form")], later, "m2")

    merged, _ = merge_requirements(existing, incoming)

    assert merged[0]["addedAt"] == NOW
    assert merged[0]["sourceMessageId"] == "m1"


def test_application_complete_ignores_optional_items():
    requirements = build_requirements(
        [req("google_form", "Fill the form"), req("other", "Attend PPT", required=False)],
        NOW,
        "m1",
    )
    assert application_complete(requirements, ["google-form-fill-the-form"]) is True


def test_no_required_items_counts_as_complete():
    requirements = build_requirements(
        [req("other", "Attend PPT", required=False)], NOW, "m1"
    )
    assert application_complete(requirements, []) is True
    assert application_complete([], []) is True


def test_completed_required_count_reports_progress():
    requirements = build_requirements(
        [req("google_form", "Fill the form"), req("neopat", "Register on NeoPAT")],
        NOW,
        "m1",
    )
    assert completed_required_count(requirements, []) == (0, 2)
    assert completed_required_count(
        requirements, ["google-form-fill-the-form"]
    ) == (1, 2)


def test_action_needed_for_an_open_incomplete_drive():
    assert (
        action_needed(
            opted_in=None,
            complete=False,
            status="registration_open",
            registration_deadline=FUTURE,
            now=NOW,
        )
        is True
    )


def test_action_not_needed_when_opted_out():
    assert (
        action_needed(
            opted_in=False,
            complete=False,
            status="registration_open",
            registration_deadline=FUTURE,
            now=NOW,
        )
        is False
    )


def test_action_not_needed_once_complete():
    assert (
        action_needed(
            opted_in=True,
            complete=True,
            status="in_progress",
            registration_deadline=FUTURE,
            now=NOW,
        )
        is False
    )


def test_action_not_needed_after_the_deadline_or_when_closed():
    assert (
        action_needed(
            opted_in=True,
            complete=False,
            status="registration_open",
            registration_deadline=PAST,
            now=NOW,
        )
        is False
    )
    assert (
        action_needed(
            opted_in=True,
            complete=False,
            status="closed",
            registration_deadline=FUTURE,
            now=NOW,
        )
        is False
    )
    assert (
        action_needed(
            opted_in=True,
            complete=False,
            status="results_declared",
            registration_deadline=FUTURE,
            now=NOW,
        )
        is False
    )


def test_a_required_item_added_after_completion_reopens_the_application():
    requirements = build_requirements([req("google_form", "Fill the form")], NOW, "m1")
    completed = ["google-form-fill-the-form"]
    assert application_complete(requirements, completed) is True

    later = build_requirements([req("neopat", "Register on NeoPAT")], NOW, "m2")
    merged, _ = merge_requirements(requirements, later)

    assert application_complete(merged, completed) is False
    assert (
        action_needed(
            opted_in=True,
            complete=application_complete(merged, completed),
            status="in_progress",
            registration_deadline=FUTURE,
            now=NOW,
        )
        is True
    )


def test_links_survive_html_stripping_so_the_model_can_see_them():
    from orbit.cleaning import clean_body

    html = (
        '<p>Register here: '
        '<a href="https://forms.gle/abc123">company registration form</a></p>'
        '<p>Also <a href="https://neopat.example/portal">NeoPAT</a></p>'
    )
    cleaned = clean_body(html)

    assert "https://forms.gle/abc123" in cleaned
    assert "company registration form" in cleaned
    assert "https://neopat.example/portal" in cleaned


def test_mailto_and_anchor_links_are_dropped_not_shown_as_urls():
    from orbit.cleaning import clean_body

    cleaned = clean_body('<a href="mailto:cdc@vit.ac.in">write to us</a>')

    assert "mailto:" not in cleaned
    assert "write to us" in cleaned


def test_mail_dates_become_real_datetimes_not_strings():
    from orbit.store import IST, parse_mail_datetime

    parsed = parse_mail_datetime("2026-09-02T16:00:00")
    assert isinstance(parsed, datetime)
    assert parsed.tzinfo is not None
    assert parsed == datetime(2026, 9, 2, 16, 0, tzinfo=IST)


def test_date_only_and_zulu_forms_are_accepted():
    from orbit.store import IST, parse_mail_datetime

    date_only = parse_mail_datetime("2026-09-02")
    assert date_only.astimezone(IST).hour == 0
    assert date_only.astimezone(IST).date() == datetime(2026, 9, 2).date()

    zulu = parse_mail_datetime("2026-09-02T10:30:00Z")
    assert zulu == datetime(2026, 9, 2, 10, 30, tzinfo=timezone.utc)


def test_unparsable_or_missing_dates_return_none():
    from orbit.store import parse_mail_datetime

    assert parse_mail_datetime(None) is None
    assert parse_mail_datetime("") is None
    assert parse_mail_datetime("sometime next week") is None


def test_epoch_millis_are_accepted():
    from orbit.store import parse_mail_datetime

    parsed = parse_mail_datetime(1788263265000)
    assert isinstance(parsed, datetime)
    assert parsed.year == 2026
