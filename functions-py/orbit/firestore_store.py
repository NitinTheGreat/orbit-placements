from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.cloud import firestore

from .store import (
    BROADCASTS,
    COMPANIES,
    ASSISTANT_USAGE,
    NOTIFICATION_LOG,
    PROCESSED,
    STUDENT_STATUS,
    status_doc_id,
)


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

    def get_notified_keys(self, student_id: str, company_id: str) -> list[str]:
        doc_id = status_doc_id(student_id, company_id)
        snapshot = self._db.collection(NOTIFICATION_LOG).document(doc_id).get()
        if not snapshot.exists:
            return []
        return list((snapshot.to_dict() or {}).get("keys", []))

    def put_notified_keys(
        self, student_id: str, company_id: str, keys: list[str], now: Any
    ) -> None:
        doc_id = status_doc_id(student_id, company_id)
        self._db.collection(NOTIFICATION_LOG).document(doc_id).set(
            {
                "studentId": student_id,
                "companyId": company_id,
                "keys": keys,
                "updatedAt": now,
            },
            merge=True,
        )

    def drop_fcm_tokens(self, student_id: str, tokens: list[str]) -> None:
        if not tokens:
            return
        self._db.collection("students").document(student_id).update(
            {"fcmTokens": firestore.ArrayRemove(tokens)}
        )

    def tracked_student_ids(self) -> list[str]:
        return [doc.id for doc in self._db.collection("students").stream()]

    def get_assistant_usage(self, student_id: str) -> dict[str, Any] | None:
        snapshot = (
            self._db.collection(ASSISTANT_USAGE).document(student_id).get()
        )
        return snapshot.to_dict() if snapshot.exists else None

    def put_assistant_usage(self, student_id: str, usage: dict[str, Any]) -> None:
        self._db.collection(ASSISTANT_USAGE).document(student_id).set(
            usage, merge=True
        )

    def get_assistant_history(self, student_id: str) -> list[dict[str, Any]]:
        snapshot = (
            self._db.collection(ASSISTANT_USAGE).document(student_id).get()
        )
        if not snapshot.exists:
            return []
        return list((snapshot.to_dict() or {}).get("history", []))

    def put_assistant_history(
        self, student_id: str, history: list[dict[str, str]]
    ) -> None:
        self._db.collection(ASSISTANT_USAGE).document(student_id).set(
            {"history": history}, merge=True
        )

    def companies_for_assistant(self, limit: int) -> list[dict[str, Any]]:
        rows = []
        for doc in self._db.collection(COMPANIES).limit(limit).stream():
            data = doc.to_dict() or {}
            data["id"] = doc.id
            rows.append(data)
        return rows

    def statuses_for_student(self, student_id: str) -> dict[str, dict[str, Any]]:
        rows: dict[str, dict[str, Any]] = {}
        query = self._db.collection(STUDENT_STATUS).where(
            "studentId", "==", student_id
        )
        for doc in query.stream():
            data = doc.to_dict() or {}
            company_id = data.get("companyId")
            if company_id:
                rows[company_id] = data
        return rows

    def get_student(self, student_id: str) -> dict[str, Any] | None:
        snapshot = self._db.collection("students").document(student_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    def set_gmail_history_id(self, student_id: str, history_id: str) -> None:
        self._db.collection("students").document(student_id).set(
            {"gmailSync": {"historyId": history_id}}, merge=True
        )

    def mark_synced(self, student_id: str, history_id: str | None = None) -> None:
        payload: dict[str, Any] = {
            "lastSyncedAt": datetime.now(timezone.utc),
            "status": "connected",
            "lastError": None,
        }
        if history_id:
            payload["historyId"] = str(history_id)
        self._db.collection("students").document(student_id).set(
            {"gmailSync": payload}, merge=True
        )

    def mark_needs_reconnect(self, student_id: str, reason: str) -> None:
        self._db.collection("students").document(student_id).set(
            {
                "gmailSync": {
                    "status": "needs_reconnect",
                    "lastError": reason[:400],
                    "lastSyncedAt": datetime.now(timezone.utc),
                }
            },
            merge=True,
        )

    def set_watch_expiration(self, student_id: str, expiration_ms: int) -> None:
        self._db.collection("students").document(student_id).set(
            {
                "gmailSync": {
                    "watchExpiration": datetime.fromtimestamp(
                        expiration_ms / 1000, tz=timezone.utc
                    )
                }
            },
            merge=True,
        )

    def connected_students(self) -> list[tuple[str, dict[str, Any]]]:
        query = self._db.collection("students").where(
            filter=firestore.FieldFilter("gmailSync.status", "==", "connected")
        )
        return [(doc.id, doc.to_dict() or {}) for doc in query.stream()]

    def find_student_by_email(self, email: str) -> tuple[str, dict[str, Any]] | None:
        query = (
            self._db.collection("students")
            .where(filter=firestore.FieldFilter("vitEmail", "==", email))
            .limit(1)
        )
        for doc in query.stream():
            return doc.id, doc.to_dict() or {}
        return None
