"""Shared LiteLLM client configuration loaded from environment variables."""

import os

from dotenv import load_dotenv
from litellm import completion

load_dotenv()

_DEFAULT_MODEL = "gpt-4.1-nano"


def get_config() -> tuple[str, str]:
    """Return (api_key, model).  Raises ValueError if OPENAI_API_KEY is missing."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY is not set.")
    model = os.getenv("LITELLM_MODEL", _DEFAULT_MODEL)
    return api_key, model


def chat(messages: list[dict], stream: bool = False):
    """Call LiteLLM with the resolved credentials and model."""
    api_key, model = get_config()
    return completion(model=model, messages=messages, api_key=api_key, stream=stream)
