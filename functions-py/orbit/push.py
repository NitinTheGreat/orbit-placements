from __future__ import annotations

import logging
from typing import Any, Iterable

from firebase_admin import messaging

from .notifications import CHANNEL_DEFAULT, CHANNEL_URGENT, Notification

logger = logging.getLogger("orbit.push")

MAX_LOGGED_KEYS = 200


def build_message(token: str, notification: Notification) -> messaging.Message:
    channel = CHANNEL_URGENT if notification.urgent else CHANNEL_DEFAULT
    return messaging.Message(
        token=token,
        notification=messaging.Notification(
            title=notification.title, body=notification.body
        ),
        data={
            "companyId": notification.company_id,
            "trigger": notification.trigger,
        },
        android=messaging.AndroidConfig(
            priority="high" if notification.urgent else "normal",
            notification=messaging.AndroidNotification(
                channel_id=channel,
                priority="max" if notification.urgent else "default",
            ),
        ),
        apns=messaging.APNSConfig(
            headers={
                "apns-priority": "10" if notification.urgent else "5",
                "apns-push-type": "alert",
            },
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(
                        title=notification.title, body=notification.body
                    ),
                    sound="default",
                    custom_data=(
                        {"interruption-level": "time-sensitive"}
                        if notification.urgent
                        else {}
                    ),
                )
            ),
        ),
    )


def build_widget_refresh(token: str) -> messaging.Message:
    return messaging.Message(
        token=token,
        data={"orbitAction": "refreshWidget"},
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(
            headers={"apns-priority": "5", "apns-push-type": "background"},
            payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True)),
        ),
    )


def send_widget_refresh(tokens: Iterable[str]) -> int:
    token_list = [t for t in tokens if t]
    if not token_list:
        return 0
    response = messaging.send_each(
        [build_widget_refresh(token) for token in token_list]
    )
    return response.success_count


def send(
    tokens: Iterable[str], notifications: Iterable[Notification]
) -> tuple[int, list[str]]:
    token_list = [t for t in tokens if t]
    planned = list(notifications)
    if not token_list or not planned:
        return 0, []

    messages = [
        build_message(token, notification)
        for notification in planned
        for token in token_list
    ]

    response = messaging.send_each(messages)
    stale: list[str] = []
    for index, result in enumerate(response.responses):
        if result.success:
            continue
        token = messages[index].token
        if isinstance(
            result.exception,
            (messaging.UnregisteredError, messaging.SenderIdMismatchError),
        ):
            stale.append(token)
        else:
            logger.warning("push_failed token=%s error=%s", token[:12], result.exception)

    return response.success_count, sorted(set(stale))


def trim_keys(keys: Iterable[str]) -> list[str]:
    unique = list(dict.fromkeys(keys))
    return unique[-MAX_LOGGED_KEYS:]


def student_tokens(student: dict[str, Any] | None) -> list[str]:
    return [str(t) for t in (student or {}).get("fcmTokens", []) if t]
