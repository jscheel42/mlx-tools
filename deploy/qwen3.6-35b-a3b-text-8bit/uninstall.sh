#!/bin/bash
#
# Uninstall mlx-lm model launchd service
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found in $SCRIPT_DIR"
    exit 1
fi

CONFIG_NAME=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('name', 'unknown'))")
SERVICE_NAME="com.local.mlx-$CONFIG_NAME"
PLIST_PATH="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"

if [ ! -f "$PLIST_PATH" ]; then
    echo "Service is not installed"
    exit 0
fi

read -p "Stop and remove $SERVICE_NAME? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"
rm -f "$SCRIPT_DIR/start.sh"

echo "Service removed: $SERVICE_NAME"
