from __future__ import annotations

import logging
from typing import Any

from langgraph.graph import END, START, StateGraph

from .attachments import extract_text, is_supported
from .cleaning import clean_body, content_hash
from .matching import find_identifier, sender_allowed
from .state import IngestionState, halt
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

        payload: dict[str, Any] = {
            "name": name,
            "category": company_info.get("category") or (existing or {}).get("category", ""),
            "ctc": company_info.get("ctc") or (existing or {}).get("ctc"),
            "stipend": company_info.get("stipend") or (existing or {}).get("stipend"),
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

        return {
            **halt(state, MATCH_STUDENT, "student_not_named"),
            "matched": False,
        }

    return match_student


def route_match(state: IngestionState) -> str:
    return CHECK_OPT_IN if state.get("matched") else END


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
        MATCH_STUDENT, route_match, {CHECK_OPT_IN: CHECK_OPT_IN, END: END}
    )
    builder.add_conditional_edges(
        CHECK_OPT_IN, route_opt_in, {UPDATE_STATUS: UPDATE_STATUS, END: END}
    )
    builder.add_edge(UPDATE_STATUS, END)

    return builder.compile()
