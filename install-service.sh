#!/bin/bash
#
# Install mlx-lm native server as a macOS launchd service
#
# This script installs the server to run automatically on system startup.
#
# Usage:
#   ./install-service.sh
#

set -e

# Change to script directory
cd "$(dirname "$0")"
INSTALL_DIR="$(pwd)"

echo "=================================================="
echo "  Installing MLX Native Server Service"
echo "=================================================="
echo ""
echo "Install directory: $INSTALL_DIR"
echo ""

# Create logs directory if it doesn't exist
if [ ! -d "logs" ]; then
    echo "Creating logs directory..."
    mkdir -p logs
fi

# Check if service is already installed
if [ -f ~/Library/LaunchAgents/com.local.mlx-native-server.plist ]; then
    echo "⚠️  Service is already installed"
    echo ""
    read -p "Do you want to reinstall? This will stop and reload the service. (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Unload existing service
    echo "Unloading existing service..."
    launchctl unload ~/Library/LaunchAgents/com.local.mlx-native-server.plist 2>/dev/null || true
fi

# Generate plist with current installation directory
echo "Generating service configuration..."
cat > ~/Library/LaunchAgents/com.local.mlx-native-server.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Service identifier -->
    <key>Label</key>
    <string>com.local.mlx-native-server</string>
    
    <!-- Program to run -->
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/start-server.sh</string>
    </array>
    
    <!-- Working directory -->
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    
    <!-- Run at load (start automatically) -->
    <key>RunAtLoad</key>
    <true/>
    
    <!-- Keep the service alive (restart if it crashes) -->
    <key>KeepAlive</key>
    <true/>
    
    <!-- Standard output log -->
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/logs/stdout.log</string>
    
    <!-- Standard error log -->
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/logs/stderr.log</string>
    
    <!-- Environment variables (if needed) -->
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    
    <!-- Throttle interval (seconds to wait before restart after crash) -->
    <key>ThrottleInterval</key>
    <integer>30</integer>
</dict>
</plist>
EOF

# Load the service
echo "Loading service..."
launchctl load ~/Library/LaunchAgents/com.local.mlx-native-server.plist

# Wait a moment for service to start
sleep 2

# Check if service is running
if launchctl list | grep -q com.local.mlx-native-server; then
    echo ""
    echo "=================================================="
    echo "  ✓ Service installed successfully!"
    echo "=================================================="
    echo ""
    echo "The MLX Native Server is now running and will"
    echo "start automatically on system boot."
    echo ""
    echo "Service details:"
    echo "  - Server: mlx-lm native (v0.30.1)"
    echo "  - Port: 8000"
    echo "  - Model: MiniMax M2.1 REAP 50 (4-bit)"
    echo "  - Tool Calling: Enabled (built-in)"
    echo ""
    echo "Inference Parameters (MiniMax recommended):"
    echo "  - temperature: 1.0"
    echo "  - top_p: 0.95"
    echo "  - top_k: 40"
    echo ""
    echo "Commands:"
    echo "  Start:   launchctl start com.local.mlx-native-server"
    echo "  Stop:    launchctl stop com.local.mlx-native-server"
    echo "  Status:  launchctl list | grep mlx-native-server"
    echo "  Logs:    tail -f logs/stdout.log"
    echo ""
    echo "To uninstall, run: ./uninstall-service.sh"
    echo "=================================================="
else
    echo ""
    echo "✗ Service installation may have failed"
    echo ""
    echo "Check logs for errors:"
    echo "  tail -50 logs/stderr.log"
    echo ""
    echo "Try running manually to debug:"
    echo "  ./start-server.sh"
    exit 1
fi
