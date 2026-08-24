import json
import sys
import time
import requests

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

URL = "http://100.112.201.46:1234/v1/chat/completions"

payload = {
    "model": "qwen3.8-27b@q2_k_xl",
    "messages": [
        {
            "role": "user",
            "content": "Explique le fonctionnement de Modbus TCP en cinq points."
        }
    ],
    "temperature": 0.2,
    "max_tokens": 300,
    "stream": True,
    "stream_options": {
        "include_usage": True
    }
}

start = time.perf_counter()
first_token = None
last_usage = None
text = ""

try:
    with requests.post(
        URL,
        json=payload,
        stream=True,
        timeout=(10, 600),
        headers={
            "Accept": "text/event-stream",
            "Accept-Charset": "utf-8",
        },
    ) as response:

        response.raise_for_status()

        for raw_line in response.iter_lines(
            chunk_size=1,
            decode_unicode=False
        ):
            if not raw_line:
                continue

            line = raw_line.decode("utf-8", errors="replace").strip()

            if not line.startswith("data:"):
                continue

            data = line[5:].strip()

            if data == "[DONE]":
                break

            try:
                chunk = json.loads(data)
            except json.JSONDecodeError:
                continue

            if chunk.get("usage") is not None:
                last_usage = chunk["usage"]

            choices = chunk.get("choices") or []
            if not choices:
                continue

            delta = choices[0].get("delta") or {}

            # On ignore volontairement reasoning_content/reasoning
            piece = delta.get("content")

            if piece:
                if first_token is None:
                    first_token = time.perf_counter()

                print(piece, end="", flush=True)
                text += piece

except requests.exceptions.RequestException as error:
    print(f"\nErreur HTTP : {error}", file=sys.stderr)
    raise SystemExit(1)

end = time.perf_counter()

print("\n")

if first_token is None:
    first_token = start

generation_time = max(end - first_token, 0.001)
ttft = first_token - start

if last_usage:
    prompt_tokens = last_usage.get("prompt_tokens", "?")
    completion_tokens = last_usage.get("completion_tokens", "?")
    total_tokens = last_usage.get("total_tokens", "?")
else:
    prompt_tokens = "non fourni"
    completion_tokens = max(1, len(text.split()))
    total_tokens = "estimé"

tokens_per_second = completion_tokens / generation_time

print("---------- Statistiques ----------")
print(f"Prompt tokens       : {prompt_tokens}")
print(f"Completion tokens   : {completion_tokens}")
print(f"Total tokens        : {total_tokens}")
print(f"Temps avant réponse : {ttft:.2f} s")
print(f"Temps génération    : {generation_time:.2f} s")
print(f"Vitesse             : {tokens_per_second:.2f} tokens/s")