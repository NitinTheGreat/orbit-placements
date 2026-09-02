from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import firebase_admin
from firebase_admin import firestore

from orbit.stipend import infer_stipend_period


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Re-infer stipendPeriod from each company's stored stipend string."
    )
    parser.add_argument("--project", default="orbit-507316")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    firebase_admin.initialize_app(options={"projectId": args.project})
    db = firestore.client()

    changed = 0
    for doc in db.collection("companies").stream():
        data = doc.to_dict() or {}
        stipend = data.get("stipend")
        current = data.get("stipendPeriod")
        inferred = infer_stipend_period(stipend)

        if current == inferred:
            continue

        changed += 1
        print(f"  {data.get('name', doc.id)[:34]:34s} {str(stipend)[:34]:34s} {current} -> {inferred}")
        if args.apply:
            doc.reference.update({"stipendPeriod": inferred})

    mode = "applied" if args.apply else "dry run, nothing written"
    print(f"\n  companies updated: {changed}   ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
