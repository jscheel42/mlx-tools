#!/bin/bash
#
# Uninstall mlx-lm model launchd service
#
# Usage:
#   ./uninstall.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found in $SCRIPT_DIR"
    exit 1
fi

CONFIG_NAME=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('name', 'unknown'))")
CONFIG_DISPLAY_NAME=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('display_name', c.get('name', 'unknown')))")
CONFIG_PORT=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('port', 8000))")

SERVICE_NAME="com.local.mlx-$CONFIG_NAME"
PLIST_PATH="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"

echo "=================================================="
echo "  Uninstalling MLX Model: $CONFIG_DISPLAY_NAME"
echo "=================================================="
echo ""
echo "Service: $SERVICE_NAME"
echo "Port: $CONFIG_PORT"
echo ""

# Check if service is installed
if [ ! -f "$PLIST_PATH" ]; then
    echo "✓ Service is not installed (nothing to do)"
    exit 0
fi

# Confirm uninstall
read -p "This will stop the service and remove it from auto-start. Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

# Unload the service
echo "Stopping and unloading service..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Wait for service to stop
sleep 2

# Remove the plist
echo "Removing service configuration..."
rm "$PLIST_PATH"

# Remove generated start script
if [ -f "$SCRIPT_DIR/start.sh" ]; then
    rm "$SCRIPT_DIR/start.sh"
fi

# Verify it's stopped
if launchctl list | grep -q "$SERVICE_NAME"; then
    echo ""
    echo "⚠️  Service may still be running. Attempting force stop..."
    launchctl remove "$SERVICE_NAME" 2>/dev/null || true
    sleep 1
fi

# Final check
if launchctl list | grep -q "$SERVICE_NAME"; then
    echo ""
    echo "✗ Service may still be running"
    echo "  Try: launchctl remove $SERVICE_NAME"
    exit 1
else
    echo ""
    echo "=================================================="
    echo "  ✓ Service uninstalled successfully!"
    echo "=================================================="
    echo ""
    echo "The $CONFIG_DISPLAY_NAME service is no longer"
    echo "running and will not start automatically."
    echo ""
    echo "To reinstall, run:"
    echo "  ./install.sh"
    echo "=================================================="
fi
