"""Conversation creation flow for the agent start endpoint."""

from server.conversation import store
from server.conversation._shared import RunTurnResult, new_doc, run_turn
from server.conversation.conversation import after_first_turn_maybe_open_chat
from server.interface.overlay import loading_overlay_session


def create_and_run(prompt: str, image_id: str, image_data_uri: str) -> tuple[dict, RunTurnResult]:
    """Create a brand-new conversation and execute its first turn."""
    with loading_overlay_session():
        doc = new_doc(prompt)
        store.create(doc)
        turn = run_turn(doc, prompt, image_id, image_data_uri)

    after_first_turn_maybe_open_chat(doc, user_prompt=prompt, turn=turn)
    return doc, turn
