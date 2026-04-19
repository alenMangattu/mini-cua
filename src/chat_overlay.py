"""One-shot launcher for the chat overlay.

Compiles a Swift binary that reuses the overlay components, then pipes a JSON
payload (title, status, messages) over stdin so Swift can render a chat-like
panel with a text input at the bottom.
"""

from __future__ import annotations

import json
from typing import Iterable

from overlay_launcher import COMPONENTS_DIR, build_binary, spawn


EXTRA_SOURCES = [
    COMPONENTS_DIR / "ChatMessageView.swift",
    COMPONENTS_DIR / "ChatOverlayView.swift",
    COMPONENTS_DIR / "ChatOverlayController.swift",
    COMPONENTS_DIR / "ChatOverlayApp.swift",
]


def open_chat_overlay(
    messages: Iterable[dict],
    title: str = "Chat",
    status: str = "Press Enter to send  ·  Esc to close",
    placeholder: str = "Type a message…",
) -> None:
    binary_path = build_binary("chat_overlay", EXTRA_SOURCES)

    payload = {
        "title": title,
        "status": status,
        "placeholder": placeholder,
        "messages": list(messages),
    }

    spawn(binary_path, stdin_payload=json.dumps(payload))


MOCK_MESSAGES = [
    {"role": "assistant", "text": "Hi! I'm a mock assistant. What can I help with today?"},
    {"role": "user", "text": "Can you show me how the chat overlay looks?"},
    {"role": "assistant", "text": "Sure — this panel floats above your desktop and you can type at the bottom."},
    {"role": "user", "text": "Nice. Does it support multi-line messages?"},
    {"role": "assistant", "text": "For this mockup, each bubble wraps to fit. Hitting Enter sends a message."},
    {"role": "user", "text": "Perfect, thanks!"},
]


if __name__ == "__main__":
    open_chat_overlay(MOCK_MESSAGES)
