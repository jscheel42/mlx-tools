#!/bin/bash
#
# Uninstall mlx-openai-server launchd service
#
# This script removes the service and stops it from running automatically.
#
# Usage:
#   ./uninstall-service.sh
#

set -e

echo "=================================================="
echo "  Uninstalling MLX Native Server Service"
echo "=================================================="
echo ""

# Check if service is installed
if [ ! -f ~/Library/LaunchAgents/com.local.mlx-native-server.plist ]; then
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
launchctl unload ~/Library/LaunchAgents/com.local.mlx-native-server.plist 2>/dev/null || true

# Wait for service to stop
sleep 2

# Remove the plist
echo "Removing service configuration..."
rm ~/Library/LaunchAgents/com.local.mlx-native-server.plist

# Verify it's stopped
if launchctl list | grep -q com.local.mlx-native-server; then
    echo ""
    echo "⚠️  Service may still be running. Attempting force stop..."
    launchctl remove com.local.mlx-native-server 2>/dev/null || true
    sleep 1
fi

# Final check
if launchctl list | grep -q com.local.mlx-native-server; then
    echo ""
    echo "✗ Service may still be running"
    echo "  Try: launchctl remove com.local.mlx-native-server"
    exit 1
else
    echo ""
    echo "=================================================="
    echo "  ✓ Service uninstalled successfully!"
    echo "=================================================="
    echo ""
    echo "The MLX Native Server is no longer running and"
    echo "will not start automatically on system boot."
    echo ""
    echo "You can still run it manually with:"
    echo "  ./start-server.sh"
    echo ""
    echo "To reinstall as a service, run:"
    echo "  ./install-service.sh"
    echo "=================================================="
fi
