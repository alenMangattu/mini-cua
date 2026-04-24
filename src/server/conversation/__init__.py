"""Conversation package exports (lazy to avoid import cycles with *_shared*)."""

from __future__ import annotations

__all__ = ["continue_run", "create_and_run"]


def __getattr__(name: str):
    if name == "create_and_run":
        from server.conversation.agent_start import create_and_run

        return create_and_run
    if name == "continue_run":
        from server.conversation.conversation import continue_run

        return continue_run
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
