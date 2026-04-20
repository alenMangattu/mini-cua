#!/usr/bin/env python3
from __future__ import annotations

import base64
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_ROOT / "src"))

from server.configs.huggingface import get_prompt_coordinates, parse


def main() -> None:
    input_path = REPO_ROOT / "screenshot.png"
    output_path = REPO_ROOT / "parsed.png"

    if not input_path.exists():
        raise FileNotFoundError(f"Missing input image: {input_path}")

    result = parse(input_path)
    annotated_image = result["image"]
    coord_ui = get_prompt_coordinates(input_path, parsed=result)

    if not isinstance(annotated_image, str):
        raise ValueError("Expected OmniParser to return a base64 string in result['image'].")

    if "," in annotated_image and annotated_image.startswith("data:"):
        _, encoded = annotated_image.split(",", 1)
    else:
        encoded = annotated_image

    output_path.write_bytes(base64.b64decode(encoded))
    print(f"Saved parsed image to {output_path}")
    print("coord_ui:")
    print(coord_ui)
    print(len(coord_ui))


if __name__ == "__main__":
    main()
