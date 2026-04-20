"""Conversation creation flow for the agent start endpoint."""

from server.conversation import store
from server.conversation._shared import new_doc, run_turn


def create_and_run(prompt: str, image_id: str, image_data_uri: str) -> tuple[dict, list[str]]:
    """Create a brand-new conversation and execute its first turn."""
    doc = new_doc(prompt)
    store.create(doc)
    steps = run_turn(doc, prompt, image_id, image_data_uri)
    return doc, steps
