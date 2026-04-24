"""Conversation continuation flow, UI hooks, and first-turn chat spawn."""

from __future__ import annotations

import json
import os
from typing import Any

from fastapi import HTTPException

from server.conversation import store
from server.conversation._shared import RunTurnResult, run_turn
from server.interface.overlay import loading_overlay_session, overlay_manager

_DEFAULT_AGENT_PUBLIC_URL = os.environ.get("CUA_AGENT_PUBLIC_URL", "http://127.0.0.1:8000")


def _display_text_for_stored_message(msg: dict) -> str:
    """Turn one persisted message into plain text for the Swift chat bubbles."""
    role = str(msg.get("role") or "user")
    content: Any = msg.get("content")

    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                t = block.get("text")
                if isinstance(t, str) and t.strip():
                    parts.append(t.strip())
        return "\n".join(parts)

    if isinstance(content, str):
        if role == "assistant":
            try:
                payload = json.loads(content)
                if isinstance(payload, dict):
                    if payload.get("type") == "CONVERSATIONAL" and isinstance(
                        payload.get("response"), str
                    ):
                        return str(payload["response"]).strip()
                    summary = payload.get("summary")
                    if isinstance(summary, str) and summary.strip():
                        return summary.strip()
            except json.JSONDecodeError:
                pass
        return content

    return ""


def _chat_overlay_transcript(
    doc: dict,
    *,
    last_user: str,
    last_assistant: str,
) -> list[dict[str, str]]:
    """Rebuild full bubble list: history (excluding latest pair) + this turn's user/assistant text."""
    raw = list(doc.get("messages") or [])
    rows: list[dict[str, str]] = []
    if len(raw) >= 2:
        for msg in raw[:-2]:
            role = str(msg.get("role") or "user")
            if role == "system":
                continue
            text = _display_text_for_stored_message(msg).strip()
            if text:
                rows.append({"role": role, "text": text})

    u = last_user.strip()
    a = last_assistant.strip()
    if u:
        rows.append({"role": "user", "text": u})
    if a:
        rows.append({"role": "assistant", "text": a})
    return rows


def _spawn_conversational_overlay(doc: dict, messages: list[dict[str, str]]) -> None:
    if not messages:
        return
    base = _DEFAULT_AGENT_PUBLIC_URL.rstrip("/")
    print(
        f"[interface] conversational overlay conv={doc['id']} base={base!r} messages={len(messages)}",
        flush=True,
    )
    overlay_manager.spawn_chat(
        title="CUA",
        status="Conversation  ·  Enter to send  ·  Esc to close",
        placeholder="Message…",
        messages=messages,
        conversation_id=doc["id"],
        agent_base_url=base,
        detach=True,
    )


def _conversational_reply_text(turn: RunTurnResult) -> str:
    reply = (turn.assistant_message or "").strip()
    if not reply and turn.steps:
        reply = str(turn.steps[0]).strip()
    return reply


def after_first_turn_maybe_open_chat(
    doc: dict,
    *,
    user_prompt: str,
    turn: RunTurnResult,
) -> None:
    """After POST /agent/run, open the chat overlay when the model chose CONVERSATIONAL."""
    if turn.llm_type != "CONVERSATIONAL":
        return

    reply = _conversational_reply_text(turn)
    if not reply:
        return

    _spawn_conversational_overlay(
        doc,
        [
            {"role": "user", "text": user_prompt},
            {"role": "assistant", "text": reply},
        ],
    )


def after_continue_turn_maybe_open_chat(
    doc: dict,
    *,
    user_prompt: str,
    turn: RunTurnResult,
) -> None:
    """After POST /conversation/{id}, respawn chat when the model stays CONVERSATIONAL.

    Swift send-and-forget closes the overlay; the server opens a new one with the same
    ``conversation_id`` / ``agent_base_url`` so Enter keeps using the correct thread.
    """
    if turn.llm_type != "CONVERSATIONAL":
        return

    reply = _conversational_reply_text(turn)
    if not reply:
        return

    messages = _chat_overlay_transcript(doc, last_user=user_prompt, last_assistant=reply)
    _spawn_conversational_overlay(doc, messages)


def continue_run(
    conversation_id: str,
    prompt: str,
    image_id: str,
    image_data_uri: str,
) -> tuple[dict, RunTurnResult]:
    """Load an existing conversation and append a new turn."""
    doc = store.get(conversation_id)
    if doc is None:
        raise HTTPException(
            status_code=404,
            detail=f"Conversation '{conversation_id}' not found.",
        )

    with loading_overlay_session():
        turn = run_turn(doc, prompt, image_id, image_data_uri)

    after_continue_turn_maybe_open_chat(doc, user_prompt=prompt, turn=turn)
    return doc, turn
