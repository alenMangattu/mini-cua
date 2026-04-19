"""Shared helpers for compiling and launching the Swift overlay apps.

Both hello_overlay.py and chat_overlay.py build tiny one-shot Swift binaries
from the reusable sources in src/components.  The compiled binaries are
cached in .build/ and rebuilt only when a source file changes.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPONENTS_DIR = ROOT / "src/components"
BUILD_DIR = ROOT / ".build"

SHARED_SOURCES = [
    COMPONENTS_DIR / "OverlaySupport.swift",
    COMPONENTS_DIR / "OverlayAppSupport.swift",
    COMPONENTS_DIR / "OverlayPanel.swift",
]


def _needs_rebuild(binary: Path, sources: list[Path]) -> bool:
    if not binary.exists():
        return True
    binary_mtime = binary.stat().st_mtime
    return any(src.stat().st_mtime > binary_mtime for src in sources)


def build_binary(name: str, extra_sources: list[Path]) -> Path:
    """Compile a Swift binary from the shared overlay sources plus *extra_sources*.

    Returns the path to the compiled executable.
    """
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    binary_path = BUILD_DIR / name
    sources = SHARED_SOURCES + extra_sources

    if _needs_rebuild(binary_path, sources):
        command = ["swiftc", "-o", str(binary_path), *map(str, sources)]
        subprocess.run(command, check=True)

    return binary_path


def spawn(binary_path: Path, args: list[str] | None = None, stdin_payload: str | None = None) -> subprocess.Popen:
    """Launch *binary_path* in the background, optionally piping stdin_payload."""
    command = [str(binary_path), *(args or [])]
    stdin = subprocess.PIPE if stdin_payload is not None else None
    process = subprocess.Popen(command, stdin=stdin, text=True)

    if stdin_payload is not None and process.stdin is not None:
        process.stdin.write(stdin_payload)
        process.stdin.close()

    return process
