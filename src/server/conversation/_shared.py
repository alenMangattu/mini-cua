"""Shared helpers for conversation workflows."""

import base64
import uuid
from datetime import datetime, timezone
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from server.configs.config import USE_OMNIPARSER
from server.configs.huggingface import get_prompt_coordinates, parse
from server.conversation import store
from server.database import get_image
from server.llm_client import chat

_MAX_LOOP_STEPS = 3
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


def render_main_prompt(user_prompt: str, coord_ui: str = "") -> str:
    template = _PROMPT_ENV.get_template("main.j2")
    return template.render(
        user_prompt=user_prompt,
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


def build_initial_content(prompt: str, image_id: str, image_data_uri: str) -> list[dict]:
    coord_ui = ""
    omniparser_image = None

    if USE_OMNIPARSER:
        try:
            image_bytes = _decode_data_uri(image_data_uri)
            parsed = parse(image_bytes)
            coord_ui = get_prompt_coordinates(image_bytes, parsed=parsed)
            omniparser_image = _normalize_omniparser_image(parsed.get("image"))
        except Exception as exc:
            print(f"[OmniParser error]: {exc}", flush=True)

    content = [
        {
            "type": "text",
            "text": render_main_prompt(prompt, coord_ui=coord_ui),
        },
        {"type": "image_ref", "image_id": image_id},
    ]

    if omniparser_image:
        content.append({"type": "image_url", "image_url": {"url": omniparser_image}})

    return content


def build_followup_content(prompt: str) -> str:
    return (
        f"New instruction: {prompt}\n\n"
        "Continue from the previous context. Describe your next action and expected outcome."
    )


def build_turn_content(
    *,
    is_first_turn: bool,
    prompt: str,
    image_id: str,
    image_data_uri: str,
) -> list[dict] | str:
    if is_first_turn:
        return build_initial_content(prompt, image_id, image_data_uri)
    return build_followup_content(prompt)


def run_turn(doc: dict, prompt: str, image_id: str, image_data_uri: str) -> list[str]:
    """Append the user turn, run the LLM loop, persist updated doc, return steps."""
    messages: list[dict] = list(doc["messages"])
    is_first_turn = len(messages) == 0
    stored_content = build_turn_content(
        is_first_turn=is_first_turn,
        prompt=prompt,
        image_id=image_id,
        image_data_uri=image_data_uri,
    )

    messages.append({"role": "user", "content": stored_content})
    llm_messages = resolve_messages_for_llm(messages)

    import json, tempfile, os
    _tmp = os.path.join(tempfile.gettempdir(), f"llm_messages_{doc['id']}.json")
    with open(_tmp, "w") as _f:
        json.dump(llm_messages, _f, indent=2, default=str)
    print(f"[debug] llm_messages saved → {_tmp}", flush=True)
    exit(0)
