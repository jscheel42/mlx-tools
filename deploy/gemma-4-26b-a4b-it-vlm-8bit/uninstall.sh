#!/bin/bash
#
# Uninstall mlx-vlm model launchd service
#

set -e

AUTO_CONFIRM=false
if [ "${1:-}" = "--yes" ] || [ "${MLX_AUTO_CONFIRM:-}" = "1" ]; then
    AUTO_CONFIRM=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found in $SCRIPT_DIR"
    exit 1
fi

CONFIG_NAME=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('name', 'unknown'))")
CONFIG_DISPLAY_NAME=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('display_name', c.get('name', 'unknown')))")
CONFIG_MODEL_ID=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('server', {}).get('model_id', 'mlx-local-vlm'))")

SERVICE_NAME="com.local.mlx-$CONFIG_NAME"
PLIST_PATH="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODEL_ALIAS_PATH="$DEPLOY_DIR/$CONFIG_MODEL_ID"

echo "=================================================="
echo "  Uninstalling MLX Model: $CONFIG_DISPLAY_NAME"
echo "=================================================="

if [ ! -f "$PLIST_PATH" ]; then
    echo "Service not installed"
    exit 0
fi

if [ "$AUTO_CONFIRM" != "true" ]; then
    read -p "This will stop the service and remove it. Continue? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled"
        exit 0
    fi
fi

echo "Stopping and unloading service..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
sleep 2

echo "Removing service files..."
rm -f "$PLIST_PATH"
rm -f "$SCRIPT_DIR/start.sh"
if [ -L "$MODEL_ALIAS_PATH" ]; then
    rm -f "$MODEL_ALIAS_PATH"
fi

if launchctl list | grep -q "$SERVICE_NAME"; then
    launchctl remove "$SERVICE_NAME" 2>/dev/null || true
fi

echo "Uninstalled $CONFIG_DISPLAY_NAME"
