<div align="center">

# CUA Playground

**A compact local workspace for streaming LLM experiments, UI prototyping, and screenshot understanding.**

[![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![Jupyter](https://img.shields.io/badge/Jupyter-Notebook-F37626?style=flat-square&logo=jupyter&logoColor=white)](https://jupyter.org/)
[![AppKit](https://img.shields.io/badge/UI-AppKit-4B8BBE?style=flat-square)](#components)
[![Models](https://img.shields.io/badge/Models-YOLO%20%2B%20Florence--2-6f42c1?style=flat-square)](#components)

</div>

This repository combines three focused components in one workspace: a streaming client built with LiteLLM, a native macOS glass overlay built with AppKit, and a notebook pipeline for UI element detection and captioning using YOLO and Florence-2. It is intended for fast local iteration on interaction patterns, latency measurement, and image-based interface analysis.

> [!NOTE]
> The notebook uses local model weights from `weights/` and is currently detection-and-caption only.

## Quick Navigation

- [Components](#components)
- [Repository Structure](#repository-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Environment Configuration](#environment-configuration)

## Components

| Component | Purpose | Entry Point |
| --- | --- | --- |
| Streaming client | Streams chat completions and reports time to first token | `main.py` |
| Swift glass overlay | Runs a native macOS floating blur overlay | `src/overlay/GlassOverlay.swift` |
| OmniParser notebook | Detects and captions UI regions in screenshots | `src/omniparser.ipynb` |

## Repository Structure

```text
.
├── main.py
├── requirements.txt
├── src/
│   ├── omniparser.ipynb
│   ├── overlay/
│   │   └── GlassOverlay.swift
└── weights/
    ├── icon_detect/
    └── icon_caption_florence/
```

## Requirements

- Python `3.11` or `3.12` recommended
- local model weights under `weights/`
- an OpenAI-compatible API key for `main.py`

Some ML dependencies may be unreliable on Python `3.14`, so an earlier runtime is recommended for consistent setup.

## Installation

Create a virtual environment and install dependencies:

```bash
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

To use the notebook in Jupyter:

```bash
python -m ipykernel install --user --name cua --display-name "Python (cua)"
```

## Environment Configuration

Create a `.env` file in the project root:

```env
OPENAI_API_KEY=your_key_here
LITELLM_MODEL=gpt-4.1-nano
```

## Components

### Streaming Client

`main.py` sends a prompt through LiteLLM, streams tokens as they arrive, and reports time to first token.

Run:

```bash
python main.py
```

### Native macOS Glass Overlay

`src/overlay/GlassOverlay.swift` is a standalone AppKit overlay that behaves like a native floating glass panel. It uses a borderless `NSPanel`, `NSVisualEffectView`, and adaptive screen-aware placement.

Run:

```bash
swift src/overlay/GlassOverlay.swift
```

Notes:

- drag anywhere in the panel to move it
- press `Esc` to close it
- tweak size, text, and placement directly in `src/overlay/GlassOverlay.swift`

### OmniParser Notebook

`src/omniparser.ipynb` performs detection and captioning over a screenshot or other UI image.

The notebook expects local model assets at:

- `weights/icon_detect/model.pt`
- `weights/icon_caption_florence/model.safetensors`

Pipeline:

1. YOLO detects candidate UI regions.
2. Each crop is resized and passed to Florence-2 for captioning.
3. The notebook renders labeled boxes, prints detections, and writes `annotated.png`.

The final notebook cell exposes the main runtime controls:

- `IMAGE_PATH`
- `BBOX_THRESHOLD`
- `IOU_THRESHOLD`
- `IMGSZ`

This notebook is currently detection-and-caption only; OCR is not part of the pipeline.

## Notes

- `weights/`, `venv/`, `.env`, and generated `.png` files are excluded from version control.
- `annotated.png` is produced by the notebook in the project root.