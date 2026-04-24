"""Shared helpers for conversation workflows."""

import base64
import json
import tempfile
import uuid
from datetime import datetime, timezone
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader

from server.configs.config import USE_OMNIPARSER
from server.configs.huggingface import get_prompt_coordinates, parse
from server.conversation import store
from server.database import get_image
from server.llm_client import chat, get_config

_MAX_LOOP_STEPS = 3


@dataclass
class RunTurnResult:
    """Outcome of a single LLM turn (persisted on *doc* before return)."""

    steps: list[str]
    llm_type: str | None = None
    assistant_message: str | None = None


_PROMPT_ENV = Environment(
    loader=FileSystemLoader(Path(__file__).with_name("prompts")),
    autoescape=False,
)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def new_doc(first_prompt: str) -> dict:
    now = now_iso()
    return {
        "id": str(uuid.uuid4()),
        "created_at": now,
        "updated_at": now,
        "messages": [],
        "last_prompt": first_prompt,
        "status": "active",
        "step_count": 0,
    }


def resolve_messages_for_llm(messages: list[dict]) -> list[dict]:
    """Replace every image_ref content part with the real image_url."""
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
            else:
                new_parts.append(part)
        resolved.append({**msg, "content": new_parts})
    return resolved


def render_system_prompt(coord_ui: str = "") -> str:
    """Render *main.j2* for a ``role: system`` message (no user text embedded)."""
    template = _PROMPT_ENV.get_template("main.j2")
    return template.render(
        USE_OMNIPARSER=bool(USE_OMNIPARSER and coord_ui),
        coord_ui=coord_ui,
    )


def _decode_data_uri(data_uri: str) -> bytes:
    _, _, encoded = data_uri.partition(",")
    if not encoded:
        raise ValueError("Invalid image data URI.")
    return base64.b64decode(encoded)


def _normalize_omniparser_image(image_value: str | None) -> str | None:
    if not image_value:
        return None
    if image_value.startswith("data:"):
        return image_value
    return f"data:image/png;base64,{image_value}"



def _first_turn_omnivision(image_data_uri: str) -> tuple[str, str | None]:
    """Return ``(coord_ui, omniparser_image_data_uri)`` for OmniParser, if enabled."""
    coord_ui = ""
    omniparser_image: str | None = None
    if not USE_OMNIPARSER:
        return coord_ui, omniparser_image
    try:
        image_bytes = _decode_data_uri(image_data_uri)
        parsed = parse(image_bytes)
        coord_ui = get_prompt_coordinates(image_bytes, parsed=parsed)
        omniparser_image = _normalize_omniparser_image(parsed.get("image"))
    except Exception as exc:
        print(f"[OmniParser error]: {exc}", flush=True)
    return coord_ui, omniparser_image


def _vision_user_message_parts(
    prompt: str,
    image_id: str,
    omniparser_image: str | None,
) -> list[dict]:
    parts: list[dict] = [
        {"type": "text", "text": prompt},
        {"type": "image_ref", "image_id": image_id},
    ]
    if omniparser_image:
        parts.append({"type": "image_url", "image_url": {"url": omniparser_image}})
    return parts


def _jsonable(value: Any) -> Any:
    if hasattr(value, "model_dump"):
        return value.model_dump()
    if hasattr(value, "dict"):
        return value.dict()
    return value


def _response_content(response: Any) -> str:
    try:
        message = response.choices[0].message
        content = getattr(message, "content", None)
        if content is not None:
            return str(content)
    except (AttributeError, IndexError, KeyError, TypeError):
        pass

    if isinstance(response, dict):
        choices = response.get("choices") or []
        if choices:
            message = choices[0].get("message", {})
            content = message.get("content")
            if content is not None:
                return str(content)

    return str(response)


def _steps_from_content(content: str) -> list[str]:
    try:
        payload = json.loads(content)
    except json.JSONDecodeError:
        return [content]

    response = payload.get("response")
    if isinstance(response, str) and response:
        return [response]

    steps = payload.get("steps")
    if isinstance(steps, list):
        return [str(step) for step in steps]

    plan = payload.get("plan")
    if isinstance(plan, list):
        return [
            str(item.get("description", item)) if isinstance(item, dict) else str(item)
            for item in plan
        ]

    summary = payload.get("summary")
    if isinstance(summary, str) and summary:
        return [summary]

    return [content]


def _parse_llm_classification(content: str) -> tuple[str | None, str | None]:
    """Return (llm_type, assistant_message) from JSON classification, if present."""
    try:
        payload = json.loads(content)
    except json.JSONDecodeError:
        return None, None

    raw_type = payload.get("type")
    if not isinstance(raw_type, str):
        return None, None
    llm_type = raw_type.strip().upper()

    assistant_message: str | None = None
    if llm_type == "CONVERSATIONAL":
        response = payload.get("response")
        if isinstance(response, str) and response.strip():
            assistant_message = response.strip()

    return llm_type, assistant_message


def run_turn(doc: dict, prompt: str, image_id: str, image_data_uri: str) -> RunTurnResult:
    """Append the user turn, run the LLM, persist updated doc, return structured result."""
    messages: list[dict] = list(doc["messages"])
    is_first_turn = len(messages) == 0

    if is_first_turn:
        coord_ui, omniparser_image = _first_turn_omnivision(image_data_uri)
        system_text = render_system_prompt(coord_ui=coord_ui)
        user_parts = _vision_user_message_parts(prompt, image_id, omniparser_image)
        messages.append({"role": "system", "content": system_text})
        messages.append({"role": "user", "content": user_parts})
    else:
        # Same vision payload as turn 1 (HTTP already sent screenshot like OverlayStart).
        _, omniparser_image = _first_turn_omnivision(image_data_uri)
        follow_user_parts = _vision_user_message_parts(prompt, image_id, omniparser_image)
        messages.append({"role": "user", "content": follow_user_parts})

    llm_messages = resolve_messages_for_llm(messages)

    tmp_path = Path(tempfile.gettempdir()) / f"llm_messages_{doc['id']}.json"
    tmp_path.write_text(json.dumps(llm_messages, indent=2, default=str))
    print(f"[debug] llm_messages saved → {tmp_path}", flush=True)

    _, model = get_config()
    print(
        f"[LLM/request] conv={doc['id']} model={model!r} messages={len(llm_messages)}",
        flush=True,
    )

    response = chat(llm_messages)
    response_json = json.dumps(_jsonable(response), indent=2, default=str)
    print(f"[LLM/raw]\n{response_json}", flush=True)

    assistant_content = _response_content(response)
    print(f"[LLM/content]\n{assistant_content}", flush=True)

    llm_type, assistant_message = _parse_llm_classification(assistant_content)
    steps = _steps_from_content(assistant_content)
    messages.append({"role": "assistant", "content": assistant_content})

    doc["messages"] = messages
    doc["last_prompt"] = prompt
    doc["updated_at"] = now_iso()
    doc["step_count"] = int(doc.get("step_count", 0)) + len(steps)
    if llm_type:
        doc["last_llm_type"] = llm_type
    store.update(doc)

    return RunTurnResult(
        steps=steps,
        llm_type=llm_type,
        assistant_message=assistant_message,
    )
