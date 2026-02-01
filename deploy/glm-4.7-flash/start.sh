#!/bin/bash
#
# Start script for GLM-4.7-Flash 8bit
# Generated from config.json
#

set -e

PYTHON_BIN="/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12"
export PYTHONPATH="/Users/jscheel/tools/mlx-tools/mlx-lm-repo:/Users/jscheel/tools/mlx-tools/.venv/lib/python3.12/site-packages:${PYTHONPATH:-}"

exec "/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12" -m mlx_lm server \
    --model "./local-models/Huihui-GLM-4.7-Flash-abliterated-8bit" \
    --model-id "mlx-local" \
    --host "0.0.0.0" \
    --wired-limit-mb 100000 \
    --port 8000 \
    --trust-remote-code \
    --temp 0.7 \
    --top-p 1.0 \
    --top-k 40 \
    --max-tokens 128000     --kv-bits 8     --kv-group-size 64     --quantized-kv-start 0
