"""One-shot launcher for the hello overlay.

Compiles a tiny Swift binary that reuses the overlay components and displays
a static message, then opens it.
"""

from __future__ import annotations

from overlay_launcher import COMPONENTS_DIR, build_binary, spawn


EXTRA_SOURCES = [
    COMPONENTS_DIR / "OverlayContentView.swift",
    COMPONENTS_DIR / "OverlayWindowController.swift",
    COMPONENTS_DIR / "HelloOverlayApp.swift",
]


def open_hello_overlay(
    title: str = "Hello",
    status: str = "Opened from Python",
    message: str = "Hello world from Python.",
) -> None:
    binary_path = build_binary("hello_overlay", EXTRA_SOURCES)
    spawn(binary_path, args=[title, status, message])


if __name__ == "__main__":
    open_hello_overlay()
