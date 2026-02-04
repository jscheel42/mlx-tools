#!/usr/bin/env python3
import argparse
import json
import sys
import time
import urllib.error
import urllib.request


DEFAULT_PROMPT = "Write a short paragraph about the history of the telescope."


def _request_json(url: str, payload: dict | None, timeout: int) -> dict:
    data = None
    headers = {"Content-Type": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def _resolve_model(base_url: str, timeout: int) -> str:
    models_url = f"{base_url.rstrip('/')}/models"
    data = _request_json(models_url, None, timeout)
    items = data.get("data", [])
    if items:
        model_id = items[0].get("id")
        if model_id:
            return model_id
    return "mlx-local"


def _run_benchmark(
    base_url: str,
    model: str,
    prompt: str,
    max_tokens: int,
    temperature: float,
    timeout: int,
) -> tuple[float, int | None, int | None, int | None]:
    url = f"{base_url.rstrip('/')}/chat/completions"
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": False,
    }
    start = time.perf_counter()
    response = _request_json(url, payload, timeout)
    elapsed = time.perf_counter() - start

    usage = response.get("usage", {})
    prompt_tokens = usage.get("prompt_tokens")
    completion_tokens = usage.get("completion_tokens")
    total_tokens = usage.get("total_tokens")
    return elapsed, prompt_tokens, completion_tokens, total_tokens


def _format_tokens(tokens: float | int | None) -> str:
    if tokens is None:
        return "n/a"
    return str(int(tokens))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Benchmark a local OpenAI-compatible server.",
    )
    parser.add_argument(
        "--base-url",
        default="http://localhost:8000/v1",
        help="Base URL for the OpenAI-compatible server.",
    )
    parser.add_argument(
        "--model",
        default=None,
        help="Model ID to benchmark (defaults to first /v1/models entry).",
    )
    parser.add_argument("--prompt", default=DEFAULT_PROMPT, help="Prompt text.")
    parser.add_argument("--max-tokens", type=int, default=256)
    parser.add_argument("--temperature", type=float, default=0.2)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()

    if args.runs < 1:
        print("--runs must be >= 1", file=sys.stderr)
        return 2

    try:
        model = args.model or _resolve_model(args.base_url, args.timeout)
    except urllib.error.URLError as exc:
        print(f"Failed to fetch models from {args.base_url}: {exc}", file=sys.stderr)
        return 1

    print("Local model benchmark")
    print(f"Base URL: {args.base_url}")
    print(f"Model:    {model}")
    print(f"Runs:     {args.runs}")
    print("")

    durations = []
    completion_tps = []
    prompt_tokens_values = []
    completion_tokens_values = []

    for run_index in range(1, args.runs + 1):
        try:
            elapsed, prompt_tokens, completion_tokens, total_tokens = _run_benchmark(
                args.base_url,
                model,
                args.prompt,
                args.max_tokens,
                args.temperature,
                args.timeout,
            )
        except urllib.error.URLError as exc:
            print(f"Run {run_index}: request failed: {exc}", file=sys.stderr)
            return 1

        durations.append(elapsed)
        if completion_tokens is not None and elapsed > 0:
            completion_tps.append(completion_tokens / elapsed)
        if prompt_tokens is not None:
            prompt_tokens_values.append(prompt_tokens)
        if completion_tokens is not None:
            completion_tokens_values.append(completion_tokens)

        tps = (
            f"{completion_tokens / elapsed:.2f} tok/s"
            if completion_tokens is not None and elapsed > 0
            else "n/a"
        )
        print(
            "Run {run}: {elapsed:.2f}s | prompt={prompt} | completion={completion} | total={total} | {tps}".format(
                run=run_index,
                elapsed=elapsed,
                prompt=_format_tokens(prompt_tokens),
                completion=_format_tokens(completion_tokens),
                total=_format_tokens(total_tokens),
                tps=tps,
            )
        )

    avg_latency = sum(durations) / len(durations)
    avg_prompt = (
        sum(prompt_tokens_values) / len(prompt_tokens_values)
        if prompt_tokens_values
        else None
    )
    avg_completion = (
        sum(completion_tokens_values) / len(completion_tokens_values)
        if completion_tokens_values
        else None
    )
    avg_tps = sum(completion_tps) / len(completion_tps) if completion_tps else None

    print("")
    print("Summary")
    print(f"Avg latency:   {avg_latency:.2f}s")
    print(f"Avg prompt:    {_format_tokens(avg_prompt)}")
    print(f"Avg completion:{_format_tokens(avg_completion)}")
    print(
        f"Avg tok/s:     {avg_tps:.2f}" if avg_tps is not None else "Avg tok/s:     n/a"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
