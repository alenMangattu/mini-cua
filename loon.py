from __future__ import annotations

import sys
from pathlib import Path


from server.configs.huggingface import format_prompt_coordinates


def render_coord_ui_loon(items: list[dict], width: int, height: int) -> str:
    return format_prompt_coordinates(items, width, height)
