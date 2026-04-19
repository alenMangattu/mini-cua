"""Local agent service.

Start with:
    uvicorn server.app:app --app-dir src --host 127.0.0.1 --port 8000

POST /agent/run
  Form fields:
    prompt      (str)   - The task or question from the caller.
    screenshot  (file)  - Current page screenshot (PNG / JPEG).

Response JSON:
    { "status": "ok", "steps": [...] }
"""

import base64
import mimetypes
import uuid
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from server.llm_client import chat, get_config

app = FastAPI(title="CUA Agent Service", version="0.1.0")

_MAX_LOOP_STEPS = 3

# Toggle saving each uploaded screenshot to disk for debugging (not read from env).
DEBUG_SAVE_SCREENSHOTS = True
# Repo root / debug_screenshots — edit path if you want a different folder.
DEBUG_SCREENSHOT_DIR = Path(__file__).resolve().parent.parent.parent / "debug_screenshots"


def _encode_image(data: bytes, content_type: str) -> str:
    """Return a base64 data-URI for the given image bytes."""
    b64 = base64.b64encode(data).decode("utf-8")
    return f"data:{content_type};base64,{b64}"


def _run_agent_loop(prompt: str, image_data_uri: str) -> list[str]:
    """
    Very basic fixed-iteration agent loop.

    Each step:
      1. Sends the current messages (including the screenshot on step 1) to the LLM.
      2. Prints the response to the console.
      3. Appends the assistant reply to the conversation so the next step has context.

    Returns the list of assistant replies (one per step).
    """
    steps: list[str] = []

    # Step 1 message includes the screenshot so the model can 'see' the page.
    messages: list[dict] = [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": (
                        f"You are an AI agent helping a user complete a task.\n"
                        f"Task: {prompt}\n\n"
                        "Analyse the screenshot, then describe:\n"
                        "1. What you observe on screen.\n"
                        "2. What action you would take next.\n"
                        "3. What the expected outcome is."
                    ),
                },
                {"type": "image_url", "image_url": {"url": image_data_uri}},
            ],
        }
    ]

    for step_idx in range(1, _MAX_LOOP_STEPS + 1):
        print(f"\n--- Step {step_idx} ---", flush=True)

        try:
            response = chat(messages=messages)
        except Exception as exc:
            error_msg = f"[LLM error on step {step_idx}]: {exc}"
            print(error_msg, flush=True)
            steps.append(error_msg)
            break

        reply = response.choices[0].message.content or ""
        print(f"[Observation / Action]\n{reply}", flush=True)
        steps.append(reply)

        # Feed the reply back as context for the next iteration.
        messages.append({"role": "assistant", "content": reply})

        # On subsequent steps ask the model to refine or continue.
        if step_idx < _MAX_LOOP_STEPS:
            messages.append(
                {
                    "role": "user",
                    "content": (
                        "Continue. If the task is complete say 'DONE'. "
                        "Otherwise describe your next action and expected outcome."
                    ),
                }
            )

            # Stop early if the model signals completion.
            if "DONE" in reply.upper():
                print("[Agent signalled DONE — stopping loop early]", flush=True)
                break

    print("\n--- Loop finished ---\n", flush=True)
    return steps


@app.post("/agent/run")
async def agent_run(
    prompt: str = Form(..., description="Task or question for the agent"),
    screenshot: UploadFile = File(..., description="Screenshot of the current page"),
) -> JSONResponse:
    # Validate that the upload looks like an image.
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

    try:
        get_config()
    except ValueError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    raw = await screenshot.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Screenshot upload was empty.")

    if DEBUG_SAVE_SCREENSHOTS:
        DEBUG_SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
        if "png" in content_type:
            ext = ".png"
        elif "jpeg" in content_type or "jpg" in content_type:
            ext = ".jpg"
        else:
            ext = ".bin"
        out_path = DEBUG_SCREENSHOT_DIR / f"{uuid.uuid4().hex}{ext}"
        out_path.write_bytes(raw)
        print(f"[debug] saved screenshot to {out_path}", flush=True)
    else:
        pass

    image_data_uri = _encode_image(raw, content_type)

    print(f"\n[Agent] Received request — prompt: {prompt!r}", flush=True)

    steps = _run_agent_loop(prompt, image_data_uri)

    return JSONResponse({"status": "ok", "steps": steps})


if __name__ == "__main__":
    uvicorn.run("server.app:app", host="127.0.0.1", port=8000, reload=True)
