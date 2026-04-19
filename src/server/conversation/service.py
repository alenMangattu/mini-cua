"""High-level conversation operations.

Responsibilities:
    store           — raw SQLite CRUD  (conversation/store.py)
    service         — business logic: build docs, run LLM loop, persist
    app             — HTTP layer only; calls this module

Public API:
    create_and_run(prompt, image_data_uri)          -> (doc, steps)
    continue_run(conversation_id, prompt, image_data_uri) -> (doc, steps)
"""

import uuid
from datetime import datetime, timezone

from fastapi import HTTPException

from server.conversation import store
from server.database import get_image
from server.llm_client import chat

_MAX_LOOP_STEPS = 3


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _new_doc(first_prompt: str) -> dict:
    now = _now_iso()
    return {
        "id": str(uuid.uuid4()),
        "created_at": now,
        "updated_at": now,
        "messages": [],
        "last_prompt": first_prompt,
        "status": "active",
        "step_count": 0,
    }


def create_and_run(prompt: str, image_id: str, image_data_uri: str) -> tuple[dict, list[str]]:
    """Create a brand-new conversation and execute its first turn."""
    doc = _new_doc(prompt)
    store.create(doc)
    steps = _run_turn(doc, prompt, image_id, image_data_uri)
    return doc, steps


def continue_run(
    conversation_id: str,
    prompt: str,
    image_id: str,
    image_data_uri: str,
) -> tuple[dict, list[str]]:
    """Load an existing conversation and append a new turn.

    Raises HTTP 404 if *conversation_id* is not found.
    """
    doc = store.get(conversation_id)
    if doc is None:
        raise HTTPException(
            status_code=404,
            detail=f"Conversation '{conversation_id}' not found.",
        )
    steps = _run_turn(doc, prompt, image_id, image_data_uri)
    return doc, steps


def _resolve_messages_for_llm(messages: list[dict]) -> list[dict]:
    """Replace every image_ref content part with the real image_url.

    Messages stored in the DB use {"type": "image_ref", "image_id": "..."}
    to avoid embedding large base64 blobs in the JSON.  This function swaps
    them back to the format the LLM API expects before the request is sent.
    """
    resolved = []
    for msg in messages:
        content = msg.get("content")
        if not isinstance(content, list):
            resolved.append(msg)
            continue

        new_parts = []
        for part in content:
            if part.get("type") == "image_ref":
                data_uri = get_image(part["image_id"])
                if data_uri:
                    new_parts.append({"type": "image_url", "image_url": {"url": data_uri}})
                # silently drop if image is missing (shouldn't happen)
            else:
                new_parts.append(part)
        resolved.append({**msg, "content": new_parts})
    return resolved


def _run_turn(doc: dict, prompt: str, image_id: str, image_data_uri: str) -> list[str]:
    """Append the user turn, run the LLM loop, persist updated doc, return steps.

    The first turn stores an image_ref in the saved message (clean JSON) and
    passes the resolved data-URI to the LLM.  Subsequent turns are text-only.
    """
    messages: list[dict] = list(doc["messages"])
    is_first_turn = len(messages) == 0

    if is_first_turn:
        # Stored message: compact image_ref, not the raw base64 blob.
        stored_content: list[dict] | str = [
            {
                "type": "text",
                "text": (
                    "You are an AI agent helping a user complete a task.\n"
                    f"Task: {prompt}\n\n"
                    "Analyse the screenshot, then describe:\n"
                    "1. What you observe on screen.\n"
                    "2. What action you would take next.\n"
                    "3. What the expected outcome is."
                ),
            },
            {"type": "image_ref", "image_id": image_id},
        ]
    else:
        stored_content = (
            f"New instruction: {prompt}\n\n"
            "Continue from the previous context. Describe your next action and expected outcome."
        )

    messages.append({"role": "user", "content": stored_content})
    llm_messages = _resolve_messages_for_llm(messages)

    steps: list[str] = []
    for step_idx in range(1, _MAX_LOOP_STEPS + 1):
        print(f"\n--- Step {step_idx} (conv {doc['id']}) ---", flush=True)

        try:
            response = chat(messages=llm_messages)
        except Exception as exc:
            error_msg = f"[LLM error on step {step_idx}]: {exc}"
            print(error_msg, flush=True)
            steps.append(error_msg)
            break

        reply = response.choices[0].message.content or ""
        print(f"[Observation / Action]\n{reply}", flush=True)
        steps.append(reply)

        # Append assistant reply to both lists so they stay in sync.
        assistant_msg = {"role": "assistant", "content": reply}
        messages.append(assistant_msg)
        llm_messages.append(assistant_msg)

        if step_idx < _MAX_LOOP_STEPS:
            continuation = {
                "role": "user",
                "content": (
                    "Continue. If the task is complete say 'DONE'. "
                    "Otherwise describe your next action and expected outcome."
                ),
            }
            messages.append(continuation)
            llm_messages.append(continuation)

            if "DONE" in reply.upper():
                print("[Agent signalled DONE — stopping loop early]", flush=True)
                break

    print("\n--- Loop finished ---\n", flush=True)

    doc["messages"] = messages
    doc["last_prompt"] = prompt
    doc["step_count"] = doc.get("step_count", 0) + len(steps)
    doc["updated_at"] = _now_iso()
    if any("DONE" in s.upper() for s in steps):
        doc["status"] = "done"
    store.update(doc)

    return steps
