import time

from server.llm_client import chat


def main() -> None:
    try:
        request_start = time.perf_counter()
        response = chat(
            messages=[{"role": "user", "content": "write me a 500 line diffusion transformer in pytorch"}],
            stream=True,
        )
    except ValueError as error:
        print(f"Configuration error: {error}")
        print("Check OPENAI_API_KEY and LITELLM_MODEL.")
        return
    except Exception as error:
        print(f"LiteLLM request failed: {error}")
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
