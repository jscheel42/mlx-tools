#!/bin/bash
#
# Start mlx-lm native server with MiniMax M2.1 REAP 50 (4-bit quantization)
#
# This script starts the MLX native server with tool calling support
# using the recommended MiniMax parameters.
#
# Usage:
#   ./start-server.sh
#
# To run in background and redirect logs:
#   ./start-server.sh > logs/server.log 2>&1 &
#

set -e

TARGET_MODEL="./local-models/GLM-4.7-REAP-50-MLX-4bit"

# Change to script directory
cd "$(dirname "$0")"

echo "=================================================="
echo "  Starting MLX Native Server (mlx-lm)"
echo "=================================================="
echo ""
echo "Server: mlx-lm native (v0.30.1)"
echo "Port: 8000"
echo "Tool Calling: Enabled (built-in)"
echo ""
echo "MODEL: ${TARGET_MODEL}"
echo "Press Ctrl+C to stop the server"
echo "=================================================="
echo ""

# Start mlx-lm native server with MiniMax recommended parameters
# Use UV's Python and include venv site-packages in PYTHONPATH
PYTHON_BIN="/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12"
export PYTHONPATH="$PWD/mlx-lm-repo:$PWD/.venv/lib/python3.12/site-packages:${PYTHONPATH:-}"


exec "$PYTHON_BIN" -m mlx_lm server \
    --model $TARGET_MODEL \
    --model-id "mlx-local" \
    --host 0.0.0.0 \
    --port 8000 \
    --trust-remote-code \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 40 \
    --max-tokens 120000 \
    --prompt-cache-size 1
