#!/bin/bash
#
# Install mlx-lm model as a macOS launchd service
#
# Usage:
#   ./install.sh [--start]
#
# Options:
#   --start    Start the service immediately after installation
#

set -e

# Get script directory and load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found in $SCRIPT_DIR"
    exit 1
fi

# Read config values using python for JSON parsing
CONFIG_NAME=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('name', 'unknown'))")
CONFIG_MODEL_PATH=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('model_path', ''))")
CONFIG_DISPLAY_NAME=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('display_name', c.get('name', 'unknown')))")

SERVER_CONFIG=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(json.dumps(c.get('server', {})))")
CONFIG_PORT=$(python3 -c "import json; c=json.loads(open('$CONFIG_FILE').read()); print(c.get('server', {}).get('port', 8000))")
CONFIG_MODEL_ID=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('server', {}).get('model_id', 'mlx-local'))")

TEMP=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('parameters', {}).get('temp', 0.6))")
TOP_P=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('parameters', {}).get('top_p', 0.95))")
TOP_K=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('parameters', {}).get('top_k', 20))")
MAX_TOKENS=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('parameters', {}).get('max_tokens', 100000))")

KV_BITS=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('kv_cache', {}).get('bits', 0))")
KV_GROUP_SIZE=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('kv_cache', {}).get('group_size', 64))")
KV_QUANTIZED_START=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('kv_cache', {}).get('quantized_start', 0))")

HOST=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('server', {}).get('host', '0.0.0.0'))")
TRUST_REMOTE_CODE=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print('true' if c.get('server', {}).get('trust_remote_code', True) else 'false')")
PROMPT_CACHE_SIZE=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('server', {}).get('prompt_cache_size', 1))")

SERVICE_NAME="com.local.mlx-$CONFIG_NAME"
PLIST_PATH="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"
START_SERVER="$SCRIPT_DIR/start.sh"
DEPLOY_DIR="$(pwd)"

PYTHON_BIN="/Users/jscheel/.local/share/uv/python/cpython-3.12-macos-aarch64-none/bin/python3.12"

echo "=================================================="
echo "  Installing MLX Model: $CONFIG_DISPLAY_NAME"
echo "=================================================="
echo ""
echo "Service Name: $SERVICE_NAME"
echo "Port: $CONFIG_PORT"
echo "Model: $CONFIG_MODEL_PATH"
echo ""

# Check if service is already installed
if [ -f "$PLIST_PATH" ]; then
    echo "⚠️  Service is already installed"
    echo ""
    read -p "Do you want to reinstall and reload the service. (y/n? This will stop) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi

    echo "Unloading existing service..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

# Create logs directory
if [ ! -d "$SCRIPT_DIR/logs" ]; then
    mkdir -p "$SCRIPT_DIR/logs"
fi

# Generate the start.sh script
cat > "$START_SERVER" << STARTSCRIPT
#!/bin/bash
#
# Start script for $CONFIG_DISPLAY_NAME
# Generated from config.json
#

set -e

PYTHON_BIN="$PYTHON_BIN"
export PYTHONPATH="$DEPLOY_DIR/mlx-lm-repo:$DEPLOY_DIR/.venv/lib/python3.12/site-packages:\${PYTHONPATH:-}"

exec "$PYTHON_BIN" -m mlx_lm server \\
    --model "$CONFIG_MODEL_PATH" \\
    --model-id "$CONFIG_MODEL_ID" \\
    --host "$HOST" \\
    --port $CONFIG_PORT \\
    $([ "$TRUST_REMOTE_CODE" = "true" ] && echo "--trust-remote-code") \\
    --temp $TEMP \\
    --top-p $TOP_P \\
    --top-k $TOP_K \\
    --max-tokens $MAX_TOKENS \\
    --prompt-cache-size $PROMPT_CACHE_SIZE \\
    --kv-bits $KV_BITS \\
    --kv-group-size $KV_GROUP_SIZE \\
    --quantized-kv-start $KV_QUANTIZED_START
STARTSCRIPT

chmod +x "$START_SERVER"

# Generate plist
cat > "$PLIST_PATH" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_NAME</string>

    <key>ProgramArguments</key>
    <array>
        <string>$START_SERVER</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$DEPLOY_DIR</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>Crashed</key>
        <true/>
    </dict>

    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/logs/stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/logs/stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>

    <key>ThrottleInterval</key>
    <integer>30</integer>
</dict>
</plist>
PLISTEOF

# Load the service
echo "Loading service..."
launchctl load "$PLIST_PATH"

# Start if requested
if [[ "$1" == "--start" ]]; then
    echo "Starting service..."
    launchctl start "$SERVICE_NAME"
    sleep 2
fi

# Check if service is running
if launchctl list | grep -q "$SERVICE_NAME"; then
    echo ""
    echo "=================================================="
    echo "  ✓ Service installed successfully!"
    echo "=================================================="
    echo ""
    echo "Service details:"
    echo "  - Name: $CONFIG_DISPLAY_NAME"
    echo "  - Service: $SERVICE_NAME"
    echo "  - Port: $CONFIG_PORT"
    echo "  - Model: $CONFIG_MODEL_PATH"
    echo ""
    echo "Inference Parameters:"
    echo "  - temperature: $TEMP"
    echo "  - top_p: $TOP_P"
    echo "  - top_k: $TOP_K"
    echo ""
    echo "KV Cache:"
    echo "  - bits: $KV_BITS"
    echo "  - group_size: $KV_GROUP_SIZE"
    echo ""
    echo "Commands:"
    echo "  Start:   launchctl start $SERVICE_NAME"
    echo "  Stop:    launchctl stop $SERVICE_NAME"
    echo "  Status:  launchctl list | grep $SERVICE_NAME"
    echo "  Logs:    tail -f $SCRIPT_DIR/logs/stdout.log"
    echo ""
    echo "To uninstall, run: ./uninstall.sh"
    echo "=================================================="
else
    echo ""
    echo "✗ Service installation may have failed"
    echo ""
    echo "Check logs for errors:"
    echo "  tail -50 $SCRIPT_DIR/logs/stderr.log"
    exit 1
fi
