"""CRUD operations for the conversations table.

Each conversation is a single row whose entire document lives in the `data`
column as a JSON blob.  This gives NoSQL-style flexibility while keeping the
SQLite schema stable.

Document shape (v1):
    {
        "id":          str,
        "created_at":  str,   # ISO-8601 UTC
        "updated_at":  str,   # ISO-8601 UTC
        "messages":    list[dict],
        "last_prompt": str,
        "status":      str,   # "active" | "done"
        "step_count":  int
    }
"""

import json
from typing import Any

from server.database import get_connection


def create(doc: dict[str, Any]) -> None:
    """Insert a new conversation row."""
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO conversations (id, created_at, updated_at, data) VALUES (?, ?, ?, ?)",
            (doc["id"], doc["created_at"], doc["updated_at"], json.dumps(doc)),
        )
        conn.commit()


def get(conversation_id: str) -> dict[str, Any] | None:
    """Return the conversation document or *None* if not found."""
    with get_connection() as conn:
        row = conn.execute(
            "SELECT data FROM conversations WHERE id = ?", (conversation_id,)
        ).fetchone()
    if row is None:
        return None
    return json.loads(row["data"])


def update(doc: dict[str, Any]) -> None:
    """Overwrite an existing conversation row with the updated document."""
    with get_connection() as conn:
        conn.execute(
            "UPDATE conversations SET updated_at = ?, data = ? WHERE id = ?",
            (doc["updated_at"], json.dumps(doc), doc["id"]),
        )
        conn.commit()
