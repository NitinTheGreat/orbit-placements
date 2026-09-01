from __future__ import annotations

import base64
from typing import Any

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

TOKEN_URI = "https://oauth2.googleapis.com/token"
SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]

MAX_SCAN_MESSAGES = 25


def build_service(refresh_token: str, client_id: str, client_secret: str):
    credentials = Credentials(
        token=None,
        refresh_token=refresh_token,
        token_uri=TOKEN_URI,
        client_id=client_id,
        client_secret=client_secret,
        scopes=SCOPES,
    )
    return build("gmail", "v1", credentials=credentials, cache_discovery=False)


def _decode(data: str | None) -> bytes:
    if not data:
        return b""
    return base64.urlsafe_b64decode(data.encode("utf-8"))


def _walk_parts(part: dict[str, Any], body_parts: list[str], attachments: list[dict]):
    mime = part.get("mimeType", "")
    filename = part.get("filename") or ""
    body = part.get("body", {})

    if filename and body.get("attachmentId"):
        attachments.append(
            {"filename": filename, "attachmentId": body["attachmentId"]}
        )
    elif mime in ("text/plain", "text/html"):
        decoded = _decode(body.get("data"))
        if decoded:
            body_parts.append(decoded.decode("utf-8", errors="replace"))

    for child in part.get("parts", []) or []:
        _walk_parts(child, body_parts, attachments)


class GmailClient:
    def __init__(self, service):
        self._service = service

    def get_metadata(self, message_id: str) -> dict[str, Any]:
        message = (
            self._service.users()
            .messages()
            .get(
                userId="me",
                id=message_id,
                format="metadata",
                metadataHeaders=["From", "Subject"],
            )
            .execute()
        )
        headers = {
            h["name"].lower(): h["value"]
            for h in message.get("payload", {}).get("headers", [])
        }
        return {
            "sender": headers.get("from", ""),
            "subject": headers.get("subject", ""),
            "internal_date_ms": int(message.get("internalDate", 0)),
        }

    def get_full_message(self, message_id: str) -> dict[str, Any]:
        message = (
            self._service.users()
            .messages()
            .get(userId="me", id=message_id, format="full")
            .execute()
        )
        body_parts: list[str] = []
        attachments: list[dict] = []
        payload = message.get("payload", {})
        _walk_parts(payload, body_parts, attachments)
        return {"body": "\n".join(body_parts), "attachments": attachments}

    def get_attachment(self, message_id: str, attachment_id: str) -> bytes:
        if not attachment_id:
            return b""
        blob = (
            self._service.users()
            .messages()
            .attachments()
            .get(userId="me", messageId=message_id, id=attachment_id)
            .execute()
        )
        return _decode(blob.get("data"))

    def list_new_message_ids(self, start_history_id: str) -> tuple[list[str], str | None]:
        message_ids: list[str] = []
        page_token = None
        latest_history_id: str | None = None
        while True:
            response = (
                self._service.users()
                .history()
                .list(
                    userId="me",
                    startHistoryId=start_history_id,
                    historyTypes=["messageAdded"],
                    pageToken=page_token,
                )
                .execute()
            )
            latest_history_id = response.get("historyId", latest_history_id)
            for record in response.get("history", []):
                for added in record.get("messagesAdded", []):
                    message = added.get("message", {})
                    if message.get("id"):
                        message_ids.append(message["id"])
            page_token = response.get("nextPageToken")
            if not page_token:
                break
        return message_ids, latest_history_id

    def scan_recent_message_ids(
        self, after_epoch_seconds: int, senders: list[str] | None = None
    ) -> tuple[list[str], str | None]:
        query = f"after:{after_epoch_seconds}"
        if senders:
            joined = " OR ".join(f"from:{sender}" for sender in senders)
            query = f"{query} ({joined})"
        response = (
            self._service.users()
            .messages()
            .list(userId="me", q=query, maxResults=MAX_SCAN_MESSAGES)
            .execute()
        )
        ids = [m["id"] for m in response.get("messages", []) if m.get("id")]
        return ids, self.current_history_id()

    def current_history_id(self) -> str | None:
        profile = self._service.users().getProfile(userId="me").execute()
        return profile.get("historyId")

    def watch(self, topic_name: str) -> dict[str, Any]:
        return (
            self._service.users()
            .watch(
                userId="me",
                body={
                    "topicName": topic_name,
                    "labelIds": ["INBOX"],
                    "labelFilterBehavior": "INCLUDE",
                },
            )
            .execute()
        )
