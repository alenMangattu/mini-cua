"""Local agent service.

Start with:
    uvicorn server.app:app --app-dir src --host 127.0.0.1 --port 8000

Endpoints
---------
POST /agent/run
    Start a brand-new conversation.
    Form fields:
        prompt      (str)  - The task or question.
        screenshot  (file) - Current page screenshot (PNG / JPEG).
    Response:
        { "status": "ok", "conversation_id": "<uuid>", "steps": [...] }

POST /conversation/{id}
    Continue an existing conversation.
    Returns HTTP 404 if the id is not found.
    Form fields:
        prompt      (str)  - The next instruction.
        screenshot  (file) - Current page screenshot (PNG / JPEG).
    Response:
        { "status": "ok", "conversation_id": "<uuid>", "steps": [...] }
"""

import base64
import mimetypes
import uuid
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from server.conversation.agent_start import create_and_run
from server.conversation.conversation import continue_run
from server.database import init_db, save_image
from server.llm_client import get_config

app = FastAPI(title="CUA Agent Service", version="0.1.0")

DEBUG_SAVE_SCREENSHOTS = True
DEBUG_SCREENSHOT_DIR = Path(__file__).resolve().parent.parent.parent / "debug_screenshots"


@app.on_event("startup")
def _startup() -> None:
    init_db()


def _validate_and_read_image(screenshot: UploadFile) -> tuple[bytes, str]:
    """Validate content-type and return (raw_bytes, content_type).

    Raises HTTP 400 on invalid input.
    """
    content_type = screenshot.content_type or ""
    if not content_type.startswith("image/"):
        guessed, _ = mimetypes.guess_type(screenshot.filename or "")
        if guessed and guessed.startswith("image/"):
            content_type = guessed
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Uploaded file does not appear to be an image (content-type: {content_type}).",
            )
    return content_type


def _encode_image(data: bytes, content_type: str) -> str:
    b64 = base64.b64encode(data).decode("utf-8")
    return f"data:{content_type};base64,{b64}"


async def _prepare_image(screenshot: UploadFile) -> tuple[bytes, str, str]:
    """Read, optionally save, and encode the uploaded screenshot.

    Returns (raw_bytes, content_type, image_data_uri).
    """
    content_type = _validate_and_read_image(screenshot)
    raw = await screenshot.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Screenshot upload was empty.")

    if DEBUG_SAVE_SCREENSHOTS:
        DEBUG_SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
        ext = ".png" if "png" in content_type else ".jpg" if "jpeg" in content_type or "jpg" in content_type else ".bin"
        out_path = DEBUG_SCREENSHOT_DIR / f"{uuid.uuid4().hex}{ext}"
        out_path.write_bytes(raw)
        print(f"[debug] saved screenshot → {out_path}", flush=True)

    return raw, content_type, _encode_image(raw, content_type)


@app.post("/agent/run")
async def agent_run(
    prompt: str = Form(..., description="Task or question for the agent"),
    screenshot: UploadFile = File(..., description="Screenshot of the current page"),
) -> JSONResponse:
    """Create a new conversation and run its first turn."""
    try:
        get_config()
    except ValueError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    _, _, image_data_uri = await _prepare_image(screenshot)

    image_id = save_image(image_data_uri)
    print(f"\n[Agent/new] prompt={prompt!r}  image_id={image_id}", flush=True)
    doc, steps = create_and_run(prompt, image_id, image_data_uri)

    return JSONResponse({"status": "ok", "conversation_id": doc["id"], "steps": steps})


@app.post("/conversation/{conversation_id}")
async def conversation_turn(
    conversation_id: str,
    prompt: str = Form(..., description="Next instruction for the agent"),
    screenshot: UploadFile = File(..., description="Screenshot of the current page"),
) -> JSONResponse:
    """Continue an existing conversation. Returns 404 for unknown ids."""
    try:
        get_config()
    except ValueError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    _, _, image_data_uri = await _prepare_image(screenshot)

    image_id = save_image(image_data_uri)
    print(f"\n[Agent/continue] conv={conversation_id!r}  prompt={prompt!r}  image_id={image_id}", flush=True)
    doc, steps = continue_run(conversation_id, prompt, image_id, image_data_uri)

    return JSONResponse({"status": "ok", "conversation_id": doc["id"], "steps": steps})


if __name__ == "__main__":
    uvicorn.run("server.app:app", host="127.0.0.1", port=8000, reload=True)
