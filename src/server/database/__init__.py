"""Database package.

Exposes the SQLite connection helper, table initialisation, and the image
store.  The physical database file lives at the repo-root `database/`
directory so it is easy to inspect and back up independently of the source
tree.
"""

from server.database.connection import db_path, get_connection, init_db
from server.database.image_store import get as get_image
from server.database.image_store import save as save_image

__all__ = ["db_path", "get_connection", "init_db", "save_image", "get_image"]
