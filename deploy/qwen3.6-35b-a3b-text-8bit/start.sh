#!/bin/bash
set -e

PYTHON_BIN="/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12"
export PYTHONPATH="/Users/jscheel/tools/mlx-tools/mlx-lm-repo:/Users/jscheel/tools/mlx-tools/.venv/lib/python3.12/site-packages:${PYTHONPATH:-}"

exec "/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12" -m mlx_lm server     --model "./local-models/Qwen/Qwen3.6-35B-A3B-TEXT-8bit"     --model-id "mlx-local"     --host "0.0.0.0"     --port 8000     --log-level "INFO"     --prompt-cache-size 8     --prompt-cache-ttl-seconds 600     --prompt-cache-pin-largest-session     --prompt-cache-pinned-max-bytes 33554432000          --trust-remote-code     --temp 0.6     --top-p 0.95     --top-k 20     --min-p 0.0     --chat-template-args '{}'     --max-tokens 100000
