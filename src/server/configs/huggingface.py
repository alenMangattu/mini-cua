"""Hugging Face model integrations used by the server.

This module currently exposes OmniParser v2 through the official Hugging Face
repository handler code rather than re-implementing the model pipeline locally.
That keeps behavior aligned with the published model while still giving the app
one small `parse()` entry point.
"""

from __future__ import annotations

import base64
import importlib.util
import json
from io import BytesIO
from pathlib import Path
from threading import Lock
from typing import Any

from huggingface_hub import snapshot_download
from PIL import Image


OMNIPARSER_V2_REPO = "microsoft/OmniParser-v2.0"
DEFAULT_MODEL = OMNIPARSER_V2_REPO

_MODEL_ALIASES = {
    "omniparser-v2": OMNIPARSER_V2_REPO,
    "omniparser-v2.0": OMNIPARSER_V2_REPO,
    OMNIPARSER_V2_REPO: OMNIPARSER_V2_REPO,
}
_MODEL_HANDLERS: dict[str, Any] = {}
_MODEL_LOCK = Lock()


def _resolve_model_name(model_name: str | None) -> str:
    model_key = (model_name or DEFAULT_MODEL).strip()
    try:
        return _MODEL_ALIASES[model_key]
    except KeyError as exc:
        supported = ", ".join(sorted(_MODEL_ALIASES))
        raise ValueError(
            f"Unsupported model_name {model_key!r}. Supported values: {supported}."
        ) from exc


def _coerce_pil_image(image: Any) -> Image.Image:
    """Convert a supported image input into an RGB PIL image."""
    if isinstance(image, Image.Image):
        pil_image = image
    elif isinstance(image, (str, Path)):
        pil_image = Image.open(image).convert("RGB")
    elif isinstance(image, (bytes, bytearray)):
        pil_image = Image.open(BytesIO(image)).convert("RGB")
    else:
        try:
            import numpy as np
        except ImportError as exc:
            raise TypeError(
                "Unsupported image type. Expected PIL image, path, bytes, or numpy array."
            ) from exc

        if isinstance(image, np.ndarray):
            pil_image = Image.fromarray(image).convert("RGB")
        else:
            raise TypeError(
                "Unsupported image type. Expected PIL image, path, bytes, or numpy array."
            )

    return pil_image.convert("RGB")


def _image_to_data_uri(image: Image.Image) -> str:
    """Convert a PIL image into a PNG data URI."""
    pil_image = image.convert("RGB")

    buffer = BytesIO()
    pil_image.save(buffer, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("utf-8")


def _format_prompt_scalar(value: Any) -> str:
    if isinstance(value, str):
        compact_value = value.replace(" ", "").replace("\t", "")
        return json.dumps(compact_value, ensure_ascii=True)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    return str(value)


def format_prompt_coordinates(items: list[dict], width: int, height: int) -> str:
    lines = ["(CoordUI)"]

    for index, item in enumerate(items, start=1):
        bbox = item.get("bbox")
        if not isinstance(bbox, list) or len(bbox) != 4:
            continue

        x1, y1, x2, y2 = bbox
        lines.append(f"item_{index}")

        item_type = item.get("type")
        if item_type is not None:
            lines.append(f"type:{_format_prompt_scalar(item_type)}")

        lines.append("bbox_px")
        lines.append(f"x1:{round(x1 * width)}")
        lines.append(f"y1:{round(y1 * height)}")
        lines.append(f"x2:{round(x2 * width)}")
        lines.append(f"y2:{round(y2 * height)}")
        lines.append("end")

        content = item.get("content")
        if content:
            lines.append(f"content:{_format_prompt_scalar(content)}")

        lines.append("end")

    lines.append("end")
    return "".join(lines)


def _load_omniparser_v2_handler(repo_id: str) -> Any:
    with _MODEL_LOCK:
        cached = _MODEL_HANDLERS.get(repo_id)
        if cached is not None:
            return cached

        snapshot_dir = snapshot_download(
            repo_id=repo_id,
            allow_patterns=[
                "handler.py",
                "icon_detect/*",
                "icon_caption/*",
            ],
        )

        handler_path = Path(snapshot_dir) / "handler.py"
        spec = importlib.util.spec_from_file_location(
            f"hf_handler_{repo_id.replace('/', '_').replace('.', '_')}",
            handler_path,
        )
        if spec is None or spec.loader is None:
            raise RuntimeError(f"Unable to load handler.py from {repo_id}.")

        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        handler = module.EndpointHandler(model_dir=snapshot_dir)
        _MODEL_HANDLERS[repo_id] = handler
        return handler


def parse(image: Any, model_name: str | None = None) -> dict[str, Any]:
    """Parse an image with the selected Hugging Face model.

    Parameters
    ----------
    image:
        Required. Accepts a PIL image, image path, raw image bytes, or a numpy
        array.
    model_name:
        Optional model selector. Currently supports OmniParser v2 via
        `"microsoft/OmniParser-v2.0"` and its short aliases.

    Returns
    -------
    dict[str, Any]
        The selected model's parsed output. For OmniParser v2 this includes an
        annotated base64 PNG under `image` and structured element metadata under
        `bboxes`.
    """

    repo_id = _resolve_model_name(model_name)
    if repo_id == OMNIPARSER_V2_REPO:
        pil_image = _coerce_pil_image(image)
        handler = _load_omniparser_v2_handler(repo_id)
        width, height = pil_image.size
        return handler(
            {
                "inputs": {
                    "image": _image_to_data_uri(pil_image),
                    "image_size": {"w": width, "h": height},
                }
            }
        )

    raise ValueError(f"No parser implementation is registered for {repo_id!r}.")


def get_prompt_coordinates(
    image: Any,
    parsed: dict[str, Any] | None = None,
    model_name: str | None = None,
) -> str:
    pil_image = _coerce_pil_image(image)
    result = parsed if parsed is not None else parse(pil_image, model_name=model_name)
    width, height = pil_image.size
    return format_prompt_coordinates(result.get("bboxes", []), width, height)
