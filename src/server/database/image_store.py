"""CRUD for the images table.

Each uploaded screenshot is stored once, keyed by UUID.
Conversation messages reference the image by id instead of embedding the raw
base64 string, keeping the conversations JSON compact and readable.
"""

import uuid
from datetime import datetime, timezone

from server.database.connection import get_connection


def save(data_uri: str) -> str:
    """Store a base64 data-URI and return the new image id."""
    image_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO images (id, created_at, data_uri) VALUES (?, ?, ?)",
            (image_id, created_at, data_uri),
        )
        conn.commit()
    return image_id


def get(image_id: str) -> str | None:
    """Return the data-URI for *image_id*, or *None* if not found."""
    with get_connection() as conn:
        row = conn.execute(
            "SELECT data_uri FROM images WHERE id = ?", (image_id,)
        ).fetchone()
    return row["data_uri"] if row else None
