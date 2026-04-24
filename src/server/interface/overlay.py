"""Python helpers for launching and managing native Swift overlay windows."""

from __future__ import annotations

import json
import subprocess
from contextlib import contextmanager
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

OverlayKind = Literal["hello", "chat", "loading", "glass"]

_REPO_ROOT = Path(__file__).resolve().parents[3]
_COMPONENTS_DIR = _REPO_ROOT / "src" / "components"
_BUILD_DIR = _REPO_ROOT / ".cache" / "interface-overlays"

_TARGET_SOURCES: dict[OverlayKind, list[str]] = {
    "hello": [
        "OverlaySupport.swift",
        "OverlayAppSupport.swift",
        "OverlayPanel.swift",
        "OverlayContentView.swift",
        "OverlayWindowController.swift",
        "HelloOverlayApp.swift",
    ],
    "chat": [
        "OverlaySupport.swift",
        "OverlayAppSupport.swift",
        "OverlayPanel.swift",
        "ChatMessageView.swift",
        "ChatOverlayView.swift",
        "ChatOverlayController.swift",
        "ChatOverlayApp.swift",
    ],
    "loading": [
        "OverlaySupport.swift",
        "OverlayPanel.swift",
        "LoadingOverlay.swift",
    ],
    "glass": ["GlassOverlay.swift"],
}


@dataclass(frozen=True)
class ChatMessage:
    role: str
    text: str

    def to_payload(self) -> dict[str, str]:
        return {"role": self.role, "text": self.text}


@dataclass
class OverlayHandle:
    """Handle returned for a running overlay process."""

    id: str
    kind: OverlayKind
    process: subprocess.Popen
    started_at: float

    @property
    def pid(self) -> int:
        return self.process.pid

    def is_running(self) -> bool:
        return self.process.poll() is None

    def wait(self, timeout: float | None = None) -> int | None:
        """Block until the overlay exits. Returns exit code, or *None* on timeout."""
        try:
            return self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            return None

    def terminate(self, timeout: float = 2.0) -> None:
        if not self.is_running():
            return
        self.process.terminate()
        try:
            self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            self.kill()

    def kill(self) -> None:
        if self.is_running():
            self.process.kill()
            self.process.wait()


class OverlayManager:
    """Compile, spawn, and stop Swift overlay windows."""

    def __init__(
        self,
        *,
        components_dir: Path = _COMPONENTS_DIR,
        build_dir: Path = _BUILD_DIR,
    ) -> None:
        self.components_dir = components_dir
        self.build_dir = build_dir
        self._handles: dict[str, OverlayHandle] = {}

    def spawn_hello(
        self,
        *,
        title: str = "Hello",
        status: str = "Opened from Python",
        message: str = "Hello world from Python.",
        detach: bool = True,
    ) -> OverlayHandle:
        binary = self._ensure_binary("hello")
        return self._spawn("hello", [str(binary), title, status, message], detach=detach)

    def spawn_chat(
        self,
        *,
        title: str = "Chat",
        status: str = "Press Enter to send  ·  Esc to close",
        placeholder: str = "Type a message…",
        messages: list[ChatMessage | dict[str, str]] | None = None,
        conversation_id: str | None = None,
        agent_base_url: str | None = None,
        detach: bool = True,
    ) -> OverlayHandle:
        payload = {
            "title": title,
            "status": status,
            "placeholder": placeholder,
            "messages": [
                message.to_payload() if isinstance(message, ChatMessage) else message
                for message in (messages or [])
            ],
        }
        if conversation_id:
            payload["conversation_id"] = conversation_id
        if agent_base_url:
            payload["agent_base_url"] = agent_base_url
        binary = self._ensure_binary("chat")
        return self._spawn("chat", [str(binary)], stdin_payload=payload, detach=detach)

    def spawn_loading(self, *, detach: bool = True) -> OverlayHandle:
        binary = self._ensure_binary("loading")
        return self._spawn("loading", [str(binary)], detach=detach)

    def spawn_glass(self, *, detach: bool = True) -> OverlayHandle:
        binary = self._ensure_binary("glass")
        return self._spawn("glass", [str(binary)], detach=detach)

    def get(self, overlay_id: str) -> OverlayHandle | None:
        handle = self._handles.get(overlay_id)
        if handle and not handle.is_running():
            self._handles.pop(overlay_id, None)
            return None
        return handle

    def running(self) -> list[OverlayHandle]:
        active = []
        for overlay_id, handle in list(self._handles.items()):
            if handle.is_running():
                active.append(handle)
            else:
                self._handles.pop(overlay_id, None)
        return active

    def terminate(self, overlay_id: str, timeout: float = 2.0) -> bool:
        handle = self._handles.pop(overlay_id, None)
        if handle is None:
            return False
        handle.terminate(timeout=timeout)
        return True

    def kill(self, overlay_id: str) -> bool:
        handle = self._handles.pop(overlay_id, None)
        if handle is None:
            return False
        handle.kill()
        return True

    def terminate_all(self, timeout: float = 2.0) -> None:
        for overlay_id in list(self._handles):
            self.terminate(overlay_id, timeout=timeout)

    def _spawn(
        self,
        kind: OverlayKind,
        args: list[str],
        *,
        stdin_payload: dict | None = None,
        detach: bool = True,
    ) -> OverlayHandle:
        process = subprocess.Popen(
            args,
            stdin=subprocess.PIPE if stdin_payload is not None else subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=detach,
        )

        if stdin_payload is not None and process.stdin is not None:
            process.stdin.write(json.dumps(stdin_payload).encode("utf-8"))
            process.stdin.close()

        handle = OverlayHandle(
            id=str(uuid.uuid4()),
            kind=kind,
            process=process,
            started_at=time.time(),
        )
        self._handles[handle.id] = handle
        return handle

    def _ensure_binary(self, kind: OverlayKind) -> Path:
        sources = [self.components_dir / name for name in _TARGET_SOURCES[kind]]
        binary = self.build_dir / f"{kind}-overlay"

        if self._is_current(binary, sources):
            return binary

        self.build_dir.mkdir(parents=True, exist_ok=True)
        command = ["swiftc"]
        if len(sources) > 1:
            command.append("-parse-as-library")
        command.extend(str(source) for source in sources)
        command.extend(["-o", str(binary)])
        subprocess.run(command, check=True)
        return binary

    @staticmethod
    def _is_current(binary: Path, sources: list[Path]) -> bool:
        if not binary.exists():
            return False
        binary_mtime = binary.stat().st_mtime
        return all(source.exists() and source.stat().st_mtime <= binary_mtime for source in sources)


overlay_manager = OverlayManager()


@contextmanager
def loading_overlay_session():
    """Show the native loading dots overlay for the duration of the block, then tear it down.

    Used between “request received” and “next UI” (e.g. conversational chat) so the user
    sees progress while the LLM runs. If the Swift binary cannot be spawned, continues
    without UI and logs once.
    """
    handle: OverlayHandle | None = None
    try:
        try:
            handle = overlay_manager.spawn_loading()
        except Exception as exc:
            print(f"[interface] loading overlay unavailable: {exc}", flush=True)
        yield
    finally:
        if handle is not None:
            overlay_manager.terminate(handle.id, timeout=2.0)


def spawn_hello(**kwargs) -> OverlayHandle:
    return overlay_manager.spawn_hello(**kwargs)


def spawn_chat(**kwargs) -> OverlayHandle:
    return overlay_manager.spawn_chat(**kwargs)


def spawn_loading(**kwargs) -> OverlayHandle:
    return overlay_manager.spawn_loading(**kwargs)


def spawn_glass(**kwargs) -> OverlayHandle:
    return overlay_manager.spawn_glass(**kwargs)


def terminate_overlay(overlay_id: str, timeout: float = 2.0) -> bool:
    return overlay_manager.terminate(overlay_id, timeout=timeout)


def kill_overlay(overlay_id: str) -> bool:
    return overlay_manager.kill(overlay_id)


def terminate_all_overlays(timeout: float = 2.0) -> None:
    overlay_manager.terminate_all(timeout=timeout)
