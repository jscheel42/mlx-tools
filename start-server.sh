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

# Change to script directory
cd "$(dirname "$0")"

echo "=================================================="
echo "  Starting MLX Native Server (mlx-lm)"
echo "=================================================="
echo ""
echo "Model: MiniMax M2.1 REAP 50 (4-bit)"
echo "Server: mlx-lm native (v0.30.1)"
echo "Port: 8000"
echo "Tool Calling: Enabled (built-in)"
echo ""
echo "Inference Parameters (MiniMax recommended):"
echo "  - temperature: 1.0"
echo "  - top_p: 0.95"
echo "  - top_k: 40"
echo ""
echo "Press Ctrl+C to stop the server"
echo "=================================================="
echo ""

# Activate virtual environment
source .venv/bin/activate

# Start mlx-lm native server with MiniMax recommended parameters
exec python -m mlx_lm server \
    --model ./local-models/MiniMax-M2.1-REAP-50-MLX-4bit \
    --host 0.0.0.0 \
    --port 8000 \
    --trust-remote-code \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 40 \
    --max-tokens 120000 \
    --prompt-cache-size 1
