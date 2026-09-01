from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud import firestore

from .store import BROADCASTS, COMPANIES, PROCESSED, STUDENT_STATUS, status_doc_id


class FirestoreStore:
    def __init__(self, client: firestore.Client):
        self._db = client

    def get_config(self) -> dict[str, Any]:
        snapshot = self._db.collection("config").document("ingestion").get()
        return snapshot.to_dict() or {} if snapshot.exists else {}

    def is_processed(self, message_id: str) -> bool:
        return self._db.collection(PROCESSED).document(message_id).get().exists

    def mark_processed(self, message_id: str, student_id: str, outcome: str) -> None:
        self._db.collection(PROCESSED).document(message_id).set(
            {
                "studentId": student_id,
                "outcome": outcome,
                "processedAt": datetime.now(timezone.utc),
            }
        )

    def get_broadcast_company(self, digest: str) -> str | None:
        snapshot = self._db.collection(BROADCASTS).document(digest).get()
        if not snapshot.exists:
            return None
        return (snapshot.to_dict() or {}).get("companyId")

    def put_broadcast_company(self, digest: str, company_id: str) -> None:
        self._db.collection(BROADCASTS).document(digest).set(
            {"companyId": company_id, "seenAt": datetime.now(timezone.utc)},
            merge=True,
        )

    def get_company(self, company_id: str | None) -> dict[str, Any] | None:
        if not company_id:
            return None
        snapshot = self._db.collection(COMPANIES).document(company_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    def find_company_by_name(self, name: str) -> str | None:
        query = (
            self._db.collection(COMPANIES)
            .where(filter=firestore.FieldFilter("name", "==", name))
            .limit(1)
        )
        for doc in query.stream():
            return doc.id
        return None

    def upsert_company(
        self, company_id: str | None, payload: dict[str, Any], now: datetime
    ) -> str:
        collection = self._db.collection(COMPANIES)
        if company_id:
            collection.document(company_id).set(payload, merge=True)
            return company_id
        payload = {**payload, "createdAt": now}
        _, doc = collection.add(payload)
        return doc.id

    def get_status(self, student_id: str, company_id: str) -> dict[str, Any] | None:
        doc_id = status_doc_id(student_id, company_id)
        snapshot = self._db.collection(STUDENT_STATUS).document(doc_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    def put_status(
        self, student_id: str, company_id: str, payload: dict[str, Any]
    ) -> None:
        doc_id = status_doc_id(student_id, company_id)
        self._db.collection(STUDENT_STATUS).document(doc_id).set(payload, merge=True)

    def get_student(self, student_id: str) -> dict[str, Any] | None:
        snapshot = self._db.collection("students").document(student_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    def set_gmail_history_id(self, student_id: str, history_id: str) -> None:
        self._db.collection("students").document(student_id).set(
            {"gmailSync": {"historyId": history_id}}, merge=True
        )

    def find_student_by_email(self, email: str) -> tuple[str, dict[str, Any]] | None:
        query = (
            self._db.collection("students")
            .where(filter=firestore.FieldFilter("vitEmail", "==", email))
            .limit(1)
        )
        for doc in query.stream():
            return doc.id, doc.to_dict() or {}
        return None
