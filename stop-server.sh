#!/bin/bash
#
# Stop mlx-lm native server
#
# This script gracefully stops the mlx-lm server.
# If running as a launchd service, it will stop the service.
# Otherwise, it will kill the process directly.
#
# Usage:
#   ./stop-server.sh
#

set -e

echo "Stopping MLX Native Server..."

SERVICE_NAME="com.local.mlx-native-server"

# Check if service is managed by launchd
if launchctl list | grep -q "$SERVICE_NAME" 2>/dev/null; then
    echo "Stopping launchd service..."
    launchctl stop "$SERVICE_NAME"
    echo "✓ Service stopped successfully"
    exit 0
fi

# Fallback: Find and kill mlx-lm server processes directly
if pgrep -f "mlx_lm server" > /dev/null; then
    pkill -TERM -f "mlx_lm server"
    echo "Sent termination signal to mlx-lm server"
    
    # Wait up to 10 seconds for graceful shutdown
    for i in {1..10}; do
        if ! pgrep -f "mlx_lm server" > /dev/null; then
            echo "✓ Server stopped successfully"
            exit 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    if pgrep -f "mlx_lm server" > /dev/null; then
        echo "Server didn't stop gracefully, forcing shutdown..."
        pkill -KILL -f "mlx_lm server"
        sleep 1
        if ! pgrep -f "mlx_lm server" > /dev/null; then
            echo "✓ Server force-stopped"
        else
            echo "✗ Failed to stop server"
            exit 1
        fi
    fi
else
    echo "✓ No mlx-lm server process found (already stopped)"
fi
