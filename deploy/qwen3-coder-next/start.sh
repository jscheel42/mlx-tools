#!/bin/bash
#
# Start script for Qwen3-Coder-Next-6b
# Generated from config.json
#

set -e

PYTHON_BIN="/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12"
export PYTHONPATH="/Users/jscheel/tools/mlx-tools/mlx-lm-repo:/Users/jscheel/tools/mlx-tools/.venv/lib/python3.12/site-packages:${PYTHONPATH:-}"

exec "/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12" -m mlx_lm server \
    --model "./local-models/Qwen3-Coder-Next-6b" \
    --model-id "mlx-local" \
    --host "0.0.0.0" \
    --wired-limit-mb 100000 \
    --port 8000 \
    --trust-remote-code \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 40 \
    --max-tokens 200000     --kv-bits 8     --kv-group-size 64     --quantized-kv-start 0
