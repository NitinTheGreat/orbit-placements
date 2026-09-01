from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import firebase_admin
from firebase_admin import credentials, firestore

from orbit.requirements import dedupe_requirements, requirement_type


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Collapse duplicate requirements on existing company docs."
    )
    parser.add_argument("--project", default="orbit-507316")
    parser.add_argument("--credentials", default=None)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    if args.credentials:
        firebase_admin.initialize_app(
            credentials.Certificate(args.credentials), {"projectId": args.project}
        )
    else:
        firebase_admin.initialize_app(options={"projectId": args.project})

    db = firestore.client()
    touched = 0
    removed_total = 0

    for doc in db.collection("companies").stream():
        data = doc.to_dict() or {}
        requirements = data.get("requirements") or []
        if not requirements:
            continue

        merged, removed = dedupe_requirements(requirements)
        renamed = [
            (before.get("id"), after.get("id"))
            for before, after in zip(requirements, merged)
            if before.get("id") != after.get("id")
        ]
        if not removed and not renamed:
            continue

        neopat_before = sum(
            1 for r in requirements if requirement_type(r) == "neopat"
        )
        neopat_after = sum(1 for r in merged if requirement_type(r) == "neopat")

        touched += 1
        removed_total += len(removed)
        print(f"  {data.get('name', doc.id)}")
        print(f"    requirements {len(requirements)} -> {len(merged)}")
        if neopat_before != neopat_after:
            print(f"    neopat {neopat_before} -> {neopat_after}")
        for rid in removed:
            print(f"    merged away: {rid}")
        for before, after in renamed:
            print(f"    id {before} -> {after}")

        if args.apply:
            doc.reference.update({"requirements": merged})

    mode = "applied" if args.apply else "dry run, nothing written"
    print(f"\n  companies touched: {touched}   requirements merged away: {removed_total}   ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
