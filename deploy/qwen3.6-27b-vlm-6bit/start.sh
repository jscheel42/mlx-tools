#!/bin/bash
set -e

PYTHON_BIN="/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12"
export PYTHONPATH="/Users/jscheel/tools/mlx-tools/mlx-lm-repo:/Users/jscheel/tools/mlx-tools/.venv/lib/python3.12/site-packages:${PYTHONPATH:-}"
export MLX_VLM_MODEL_ID="mlx-local-vlm"

exec "/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12" -m mlx_vlm.server     --model "mlx-local-vlm"     --host "0.0.0.0"     --port 8001     --trust-remote-code
