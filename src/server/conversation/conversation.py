"""Conversation continuation flow for the conversation endpoint."""

from fastapi import HTTPException

from server.conversation import store
from server.conversation._shared import run_turn


def continue_run(
    conversation_id: str,
    prompt: str,
    image_id: str,
    image_data_uri: str,
) -> tuple[dict, list[str]]:
    """Load an existing conversation and append a new turn."""
    doc = store.get(conversation_id)
    if doc is None:
        raise HTTPException(
            status_code=404,
            detail=f"Conversation '{conversation_id}' not found.",
        )

    steps = run_turn(doc, prompt, image_id, image_data_uri)
    return doc, steps
