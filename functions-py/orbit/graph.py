from __future__ import annotations

import logging
from typing import Any

from langgraph.graph import END, START, StateGraph

from .attachments import extract_text, is_supported
from .cleaning import clean_body, content_hash
from .matching import find_identifier, sender_allowed
from .state import IngestionState, halt
from .stipend import UNSPECIFIED, infer_stipend_period
from .store import (
    Deps,
    build_requirements,
    merge_requirements,
    merge_round_history,
    merge_rounds,
    parse_mail_datetime,
    resolve_current_round_id,
    resolve_overall_status,
)

CHEAP_FILTER = "cheap_filter"
DEDUP_CHECK = "dedup_check"
LLM_EXTRACT = "llm_extract"
COMPANY_WRITE = "company_write"
MATCH_STUDENT = "match_student"
CHECK_OPT_IN = "check_opt_in"
UPDATE_STATUS = "update_student_status"
NOT_LISTED_CHECK = "not_listed_check"

logger = logging.getLogger("orbit.graph")


def make_cheap_filter(deps: Deps):
    def cheap_filter(state: IngestionState) -> IngestionState:
        internal_date = state.get("internal_date_ms", 0)
        cutoff = state.get("cutoff_ms", 0)
        if internal_date < cutoff:
            return halt(state, CHEAP_FILTER, "before_cutoff")
        if not sender_allowed(
            state.get("sender", ""), state.get("allowed_sender_patterns", [])
        ):
            return halt(state, CHEAP_FILTER, "sender_not_allowed")
        return state

    return cheap_filter


def route_cheap_filter(state: IngestionState) -> str:
    return END if state.get("halt_reason") else DEDUP_CHECK


def make_dedup_check(deps: Deps):
    def dedup_check(state: IngestionState) -> IngestionState:
        message = deps.gmail.get_full_message(state["message_id"])
        cleaned = clean_body(message.get("body", ""))
        digest = content_hash(cleaned)
        known = deps.store.get_broadcast_company(digest)
        return {
            **state,
            "body_text": cleaned,
            "body_hash": digest,
            "attachments": message.get("attachments", []),
            "known_company_id": known,
        }

    return dedup_check


def route_dedup(state: IngestionState) -> str:
    return COMPANY_WRITE if state.get("known_company_id") else LLM_EXTRACT


def make_llm_extract(deps: Deps):
    def llm_extract(state: IngestionState) -> IngestionState:
        extraction = deps.extractor(
            state.get("sender", ""),
            state.get("subject", ""),
            state.get("body_text", ""),
        )
        return {**state, "extraction": extraction}

    return llm_extract


def _stipend_period(company_info: dict[str, Any], existing: dict[str, Any] | None):
    declared = company_info.get("stipend_period")
    if declared and declared != UNSPECIFIED:
        return declared
    stipend = company_info.get("stipend") or (existing or {}).get("stipend")
    inferred = infer_stipend_period(stipend)
    if inferred != UNSPECIFIED:
        return inferred
    return (existing or {}).get("stipendPeriod", UNSPECIFIED)


def make_company_write(deps: Deps):
    def company_write(state: IngestionState) -> IngestionState:
        now = deps.now()
        known_id = state.get("known_company_id")
        extraction = state.get("extraction")

        if known_id and not extraction:
            company = deps.store.get_company(known_id) or {}
            rounds = company.get("rounds", [])
            round_id = rounds[-1]["id"] if rounds else None
            return {**state, "company_id": known_id, "round_id": round_id}

        if not extraction or not extraction.get("is_placement_mail"):
            return halt(state, COMPANY_WRITE, "not_placement_mail")

        company_info = extraction.get("company") or {}
        name = (company_info.get("name") or "").strip()
        if not name:
            return halt(state, COMPANY_WRITE, "no_company_name")

        company_id = known_id or deps.store.find_company_by_name(name)
        existing = deps.store.get_company(company_id) if company_id else None
        rounds = list((existing or {}).get("rounds", []))

        round_info = extraction.get("round") or {}
        round_name = (round_info.get("name") or "").strip()
        round_id = None
        created_round = False
        if round_name:
            rounds, round_id, created_round = merge_rounds(
                rounds, round_name, round_info.get("type") or "other", now
            )

        status = (existing or {}).get("status", "registration_open")
        if created_round and status == "registration_open":
            status = "in_progress"
        signal = extraction.get("drive_status_signal")
        if signal in ("results_declared", "closed"):
            status = signal

        payload: dict[str, Any] = {
            "name": name,
            "category": company_info.get("category") or (existing or {}).get("category", ""),
            "ctc": company_info.get("ctc") or (existing or {}).get("ctc"),
            "stipend": company_info.get("stipend") or (existing or {}).get("stipend"),
            "stipendPeriod": _stipend_period(company_info, existing),
            "eligibleBranches": company_info.get("eligible_branches")
            or (existing or {}).get("eligibleBranches", []),
            "eligibilityCriteria": company_info.get("eligibility_criteria")
            or (existing or {}).get("eligibilityCriteria"),
            "registrationDeadline": parse_mail_datetime(
                company_info.get("registration_deadline")
            )
            or parse_mail_datetime((existing or {}).get("registrationDeadline")),
            "visitDate": parse_mail_datetime(company_info.get("visit_date"))
            or parse_mail_datetime((existing or {}).get("visitDate")),
            "status": status,
            "rounds": rounds,
        }

        incoming = build_requirements(
            extraction.get("requirements") or [], now, state.get("message_id")
        )
        merged, newly_required = merge_requirements(
            list((existing or {}).get("requirements", [])), incoming
        )
        payload["requirements"] = merged
        if existing and newly_required:
            logger.info(
                "new_required_requirement company=%s ids=%s message=%s",
                company_id,
                [r["id"] for r in newly_required],
                state.get("message_id"),
            )

        source = {
            "subject": state.get("subject", ""),
            "date": state.get("internal_date_ms", 0),
        }
        payload["lastUpdatedFrom"] = source
        if not existing:
            payload["sourceSubject"] = source["subject"]
            payload["sourceDate"] = source["date"]

        company_id = deps.store.upsert_company(company_id, payload, now)
        deps.store.put_broadcast_company(state["body_hash"], company_id)
        return {**state, "company_id": company_id, "round_id": round_id}

    return company_write


def make_match_student(deps: Deps):
    def match_student(state: IngestionState) -> IngestionState:
        if state.get("halt_reason"):
            return state
        identifiers = state.get("student_identifiers", [])
        body_match = find_identifier(state.get("body_text", ""), identifiers)
        if body_match:
            return {**state, "matched": True, "match_source": "body"}

        for attachment in state.get("attachments", []):
            filename = attachment.get("filename", "")
            if not is_supported(filename):
                continue
            data = deps.gmail.get_attachment(
                state["message_id"], attachment.get("attachmentId", "")
            )
            if not data:
                continue
            text = extract_text(filename, data)
            if find_identifier(text, identifiers):
                return {**state, "matched": True, "match_source": "attachment"}

        return {**state, "matched": False}

    return match_student


def route_match(state: IngestionState) -> str:
    return CHECK_OPT_IN if state.get("matched") else NOT_LISTED_CHECK


def make_not_listed_check(deps: Deps):
    def not_listed_check(state: IngestionState) -> IngestionState:
        extraction = state.get("extraction") or {}
        round_info = extraction.get("round") or {}
        roster_type = round_info.get("roster_type")
        if roster_type is None:
            return halt(state, NOT_LISTED_CHECK, "student_not_named")
        if roster_type != "complete_final":
            return halt(state, NOT_LISTED_CHECK, "roster_not_final")

        round_id = state.get("round_id")
        company_id = state.get("company_id")
        if not round_id or not company_id:
            return halt(state, NOT_LISTED_CHECK, "no_round_for_roster")

        student_id = state["student_id"]
        existing = deps.store.get_status(student_id, company_id)
        if not existing:
            return halt(state, NOT_LISTED_CHECK, "no_prior_engagement")

        history = list(existing.get("roundHistory") or [])
        if not history:
            return halt(state, NOT_LISTED_CHECK, "no_prior_engagement")

        if existing.get("optedIn") is False:
            return halt(state, NOT_LISTED_CHECK, "opted_out")

        for entry in history:
            if entry.get("roundId") == round_id and entry.get("result") == "cleared":
                return halt(state, NOT_LISTED_CHECK, "already_cleared")

        now = deps.now()
        company = deps.store.get_company(company_id) or {}
        rounds = company.get("rounds", [])
        history = merge_round_history(
            history, round_id, "not_listed", state["message_id"], now
        )

        deps.store.put_status(
            student_id,
            company_id,
            {
                "studentId": student_id,
                "companyId": company_id,
                "roundHistory": history,
                "currentRoundId": resolve_current_round_id(history, rounds),
                "overallStatus": resolve_overall_status(history, rounds),
                "optedIn": True if existing.get("optedIn") is None else existing["optedIn"],
                "updatedAt": now,
                "source": "gmail_ingestion",
            },
        )
        logger.info(
            "not_listed company=%s round=%s message=%s",
            company_id,
            round_id,
            state.get("message_id"),
        )
        return {**state, "not_listed": True}

    return not_listed_check


def make_check_opt_in(deps: Deps):
    def check_opt_in(state: IngestionState) -> IngestionState:
        existing = deps.store.get_status(state["student_id"], state["company_id"])
        opted_in = (existing or {}).get("optedIn")
        if opted_in is False:
            return {
                **halt(state, CHECK_OPT_IN, "opted_out"),
                "opted_in": False,
            }
        return {**state, "opted_in": opted_in}

    return check_opt_in


def route_opt_in(state: IngestionState) -> str:
    return END if state.get("opted_in") is False else UPDATE_STATUS


def make_update_status(deps: Deps):
    def update_student_status(state: IngestionState) -> IngestionState:
        now = deps.now()
        student_id = state["student_id"]
        company_id = state["company_id"]
        existing = deps.store.get_status(student_id, company_id) or {}
        company = deps.store.get_company(company_id) or {}
        rounds = company.get("rounds", [])

        history = list(existing.get("roundHistory", []))
        round_id = state.get("round_id")
        if round_id:
            extraction = state.get("extraction") or {}
            result = (extraction.get("round") or {}).get("result") or "invited"
            history = merge_round_history(
                history, round_id, result, state["message_id"], now
            )

        payload = {
            "studentId": student_id,
            "companyId": company_id,
            "roundHistory": history,
            "currentRoundId": resolve_current_round_id(history, rounds),
            "overallStatus": resolve_overall_status(history, rounds),
            "optedIn": True if existing.get("optedIn") is None else existing["optedIn"],
            "updatedAt": now,
            "source": "gmail_ingestion",
        }
        deps.store.put_status(student_id, company_id, payload)
        return {**state, "opted_in": payload["optedIn"]}

    return update_student_status


def build_graph(deps: Deps):
    builder = StateGraph(IngestionState)

    builder.add_node(CHEAP_FILTER, make_cheap_filter(deps))
    builder.add_node(DEDUP_CHECK, make_dedup_check(deps))
    builder.add_node(LLM_EXTRACT, make_llm_extract(deps))
    builder.add_node(COMPANY_WRITE, make_company_write(deps))
    builder.add_node(MATCH_STUDENT, make_match_student(deps))
    builder.add_node(CHECK_OPT_IN, make_check_opt_in(deps))
    builder.add_node(UPDATE_STATUS, make_update_status(deps))
    builder.add_node(NOT_LISTED_CHECK, make_not_listed_check(deps))

    builder.add_edge(START, CHEAP_FILTER)
    builder.add_conditional_edges(
        CHEAP_FILTER, route_cheap_filter, {DEDUP_CHECK: DEDUP_CHECK, END: END}
    )
    builder.add_conditional_edges(
        DEDUP_CHECK, route_dedup, {COMPANY_WRITE: COMPANY_WRITE, LLM_EXTRACT: LLM_EXTRACT}
    )
    builder.add_edge(LLM_EXTRACT, COMPANY_WRITE)
    builder.add_edge(COMPANY_WRITE, MATCH_STUDENT)
    builder.add_conditional_edges(
        MATCH_STUDENT,
        route_match,
        {CHECK_OPT_IN: CHECK_OPT_IN, NOT_LISTED_CHECK: NOT_LISTED_CHECK},
    )
    builder.add_edge(NOT_LISTED_CHECK, END)
    builder.add_conditional_edges(
        CHECK_OPT_IN, route_opt_in, {UPDATE_STATUS: UPDATE_STATUS, END: END}
    )
    builder.add_edge(UPDATE_STATUS, END)

    return builder.compile()
