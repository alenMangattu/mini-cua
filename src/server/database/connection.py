"""SQLite connection helpers.

The database file is stored at `<repo_root>/database/conversations.db` so it
sits outside the source tree and is easy to inspect or back up.
"""

import sqlite3
from pathlib import Path


def db_path() -> Path:
    """Return the absolute path to the SQLite database file.

    Creates the `database/` directory next to the repository root if it does
    not already exist.
    """
    repo_root = Path(__file__).resolve().parent.parent.parent.parent
    db_dir = repo_root / "database"
    db_dir.mkdir(parents=True, exist_ok=True)
    return db_dir / "conversations.db"


def get_connection() -> sqlite3.Connection:
    """Open and return a SQLite connection with Row factory enabled."""
    conn = sqlite3.connect(str(db_path()))
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create all tables if they do not exist yet (idempotent)."""
    with get_connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS conversations (
                id         TEXT PRIMARY KEY,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                data       TEXT NOT NULL CHECK(json_valid(data))
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS images (
                id         TEXT PRIMARY KEY,
                created_at TEXT NOT NULL,
                data_uri   TEXT NOT NULL
            )
            """
        )
        conn.commit()
