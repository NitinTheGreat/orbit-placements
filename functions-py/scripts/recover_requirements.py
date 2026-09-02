from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import firebase_admin
from firebase_admin import credentials, firestore

from orbit.extraction import GeminiExtractor
from orbit.gmail_client import GmailClient, build_service
from orbit.requirements import build_requirements, requirement_type
from orbit.cleaning import clean_body
from orbit.stipend import infer_stipend_period


def source_message_id(requirements: list[dict]) -> str | None:
    for item in requirements:
        if item.get("sourceMessageId"):
            return item["sourceMessageId"]
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Re-extract requirements for companies from their original mail."
    )
    parser.add_argument("--project", default="orbit-507316")
    parser.add_argument("--only", action="append", default=None)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    firebase_admin.initialize_app(options={"projectId": args.project})
    db = firestore.client()

    token_doc = next(db.collection("gmailTokens").limit(1).stream(), None)
    if token_doc is None:
        print("  no stored Gmail token; cannot re-fetch mail")
        return 1
    refresh_token = (token_doc.to_dict() or {})["refreshToken"]

    gmail = GmailClient(
        build_service(
            refresh_token,
            os.environ["GMAIL_OAUTH_CLIENT_ID"],
            os.environ["GMAIL_OAUTH_CLIENT_SECRET"],
        )
    )
    extractor = GeminiExtractor()

    changed = 0
    for doc in db.collection("companies").stream():
        data = doc.to_dict() or {}
        name = data.get("name", doc.id)
        if args.only and name not in args.only:
            continue

        stored = data.get("requirements") or []
        message_id = source_message_id(stored)
        if not message_id:
            print(f"  {name}: no sourceMessageId, skipped")
            continue

        try:
            metadata = gmail.get_metadata(message_id)
            body = clean_body(gmail.get_full_message(message_id)["body"])
        except Exception as error:
            print(f"  {name}: could not fetch {message_id}: {str(error)[:90]}")
            continue

        extraction = extractor(metadata["sender"], metadata["subject"], body)
        fresh = build_requirements(
            extraction.get("requirements") or [],
            data.get("createdAt"),
            message_id,
        )

        before = [r.get("label") for r in stored]
        after = [r.get("label") for r in fresh]
        neopat_before = sum(1 for r in stored if requirement_type(r) == "neopat")
        neopat_after = sum(1 for r in fresh if requirement_type(r) == "neopat")

        if before == after:
            continue

        changed += 1
        print(f"\n  {name}  ({len(stored)} -> {len(fresh)}, neopat {neopat_before} -> {neopat_after})")
        for label in before:
            print(f"    before: {label}")
        for label in after:
            print(f"    after : {label}")

        if args.apply:
            update = {"requirements": fresh}
            period = extraction.get("company", {}).get("stipend_period")
            if not period or period == "unspecified":
                period = infer_stipend_period(data.get("stipend"))
            update["stipendPeriod"] = period
            signal = extraction.get("drive_status_signal")
            if signal in ("results_declared", "closed"):
                update["status"] = signal
            doc.reference.update(update)

    mode = "applied" if args.apply else "dry run, nothing written"
    print(f"\n  companies whose requirements changed: {changed}   ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
