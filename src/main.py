import os
import time

from litellm import completion
from dotenv import load_dotenv

def main() -> None:
    load_dotenv()

    api_key = os.getenv("OPENAI_API_KEY")
    model = os.getenv("LITELLM_MODEL", "gpt-4.1-nano")

    if not api_key:
        raise ValueError("Set OPENAI_API_KEY before running this script.")

    try:
        request_start = time.perf_counter()
        response = completion(
            model=model,
            messages=[{"role": "user", "content": "write me a 500 line diffusion transformer in pytorch"}],
            api_key=api_key,
            stream=True,
        )
    except Exception as error:
        print(f"LiteLLM request failed: {error}")
        print("Check OPENAI_API_KEY and LITELLM_MODEL.")
        return

    first_token = True
    for chunk in response:
        delta = chunk.choices[0].delta.content
        if delta:
            if first_token:
                ttfb = time.perf_counter() - request_start
                print(f"[TTFB: {ttfb:.3f}s] ", end="", flush=True)
                first_token = False
            print(delta, end="", flush=True)
    print()


if __name__ == "__main__":
    main()