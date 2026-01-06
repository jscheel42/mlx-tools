#!/bin/bash
#
# Stop mlx-lm native server
#
# This script gracefully stops any running mlx-lm server processes.
#
# Usage:
#   ./stop-server.sh
#

set -e

echo "Stopping MLX Native Server..."

# Find and kill mlx-lm server processes
if pgrep -f "mlx_lm.server" > /dev/null; then
    pkill -TERM -f "mlx_lm.server"
    echo "Sent termination signal to mlx-lm server"
    
    # Wait up to 10 seconds for graceful shutdown
    for i in {1..10}; do
        if ! pgrep -f "mlx_lm.server" > /dev/null; then
            echo "✓ Server stopped successfully"
            exit 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    if pgrep -f "mlx_lm.server" > /dev/null; then
        echo "Server didn't stop gracefully, forcing shutdown..."
        pkill -KILL -f "mlx_lm.server"
        sleep 1
        if ! pgrep -f "mlx_lm.server" > /dev/null; then
            echo "✓ Server force-stopped"
        else
            echo "✗ Failed to stop server"
            exit 1
        fi
    fi
else
    echo "✓ No mlx-lm server process found (already stopped)"
fi
