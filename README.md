# MLX OpenAI Server - MiniMax M2.1 REAP 50

OpenAI-compatible server for running MiniMax M2.1 REAP 50 (6-bit quantization) locally with MLX on Apple Silicon.

## First Time Setup

If you don't have `mlx-lm-repo` set up yet:

```bash
# 1. Clone and patch mlx-lm repository
./setup-mlx-lm-repo.sh

# 2. Install in server environment
source .venv/bin/activate
cd mlx-lm-repo && uv pip install -e . && cd ..
```

See [MLX_LM_MANAGEMENT.md](MLX_LM_MANAGEMENT.md) for details on updating mlx-lm while preserving patches.

## Quick Start

### Manual Start (Foreground)

```bash
./start-server.sh
```

This runs the server in the foreground and displays logs in the terminal. Press `Ctrl+C` to stop.

### Manual Stop

```bash
./stop-server.sh
```

## Configuration

- **Model**: MiniMax M2.1 REAP 50 (6-bit quantization)
- **Context Length**: 131,072 tokens
- **Port**: 8000
- **Base URL**: `http://localhost:8000/v1`
- **Model ID**: `local/MiniMax-M2.1-REAP-50-MLX-6bit`
- **Tool Calling**: Enabled (minimax_m2 parser)

## macOS Service (launchd)

To run the server automatically on system startup:

### Install Service

```bash
./install-service.sh
```

This will:
- Create the logs directory if needed
- Copy the service configuration to ~/Library/LaunchAgents/
- Load and start the service
- Configure it to auto-start on boot

### Uninstall Service

```bash
./uninstall-service.sh
```

This will:
- Stop the running service
- Remove it from auto-start
- Clean up the service configuration

### Manage Service (Manual)

```bash
# Start service
launchctl start com.local.mlx-native-server

# Stop service
launchctl stop com.local.mlx-native-server

# Check service status
launchctl list | grep mlx-native-server
```

### View Logs

```bash
# Real-time logs
tail -f logs/stdout.log
tail -f logs/stderr.log

# Application logs
tail -f logs/app.log
```

## OpenCode Configuration

Add to `~/.config/opencode/opencode.json`:

```json
{
  "provider": {
    "mlx-minimax": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "MLX MiniMax M2.1 (local)",
      "options": {
        "baseURL": "http://localhost:8000/v1"
      },
      "models": {
        "local/MiniMax-M2.1-REAP-50-MLX-6bit": {
          "name": "MiniMax M2.1 REAP 50 (6-bit)"
        }
      }
    }
  }
}
```

## Testing

Test the server is working:

```bash
curl http://localhost:8000/v1/models
```

Expected response:
```json
{
  "object": "list",
  "data": [{
    "id": "local/MiniMax-M2.1-REAP-50-MLX-6bit",
    "object": "model",
    "created": 1234567890,
    "owned_by": "local"
  }]
}
```

## Performance

The model uses KV caching for efficient conversation handling:

- **First message**: ~5-6 tokens/sec (cold cache)
- **Follow-up messages**: ~40-55 tokens/sec (warm cache)
- **Cache speedup**: 6-10x faster for subsequent messages

Run the cache test:
```bash
python3 /tmp/test_cache_detailed.py
```

## Troubleshooting

### Service won't start

Check logs:
```bash
tail -100 logs/stderr.log
```

Verify the start script works manually:
```bash
./start-server.sh
```

### Port already in use

Stop any running instances:
```bash
./stop-server.sh
# or
lsof -ti:8000 | xargs kill -9
```

### Out of memory

Reduce context length in `start-server.sh`:
```bash
--context-length 65536  # or 32768
```

Or use the 4-bit quantized model instead.

## Model Details

- **Original**: MiniMax-M2.1-REAP-50
- **Quantization**: 6-bit
- **Size**: ~88GB
- **Max Context**: 196,608 tokens
- **Location**: `/Users/jscheel/tools/mlx-tools/local-models/MiniMax-M2.1-REAP-50-MLX-6bit`

## Dependencies

- Python 3.12+
- mlx-lm 0.30.2 (from git, installed in editable mode)
  - Installed from: `/Users/jscheel/tools/mlx-tools/mlx-lm-repo`
- Apple Silicon Mac

## Files

### Server Management
- `start-server.sh` - Start the server in foreground
- `stop-server.sh` - Stop the server gracefully
- `install-service.sh` - Install as macOS launchd service
- `uninstall-service.sh` - Uninstall the service
- `com.local.mlx-native-server.plist` - launchd service configuration

### Model Management
- `convert-model.sh` - Convert HuggingFace models to MLX format
- `setup-mlx-lm-repo.sh` - Clone and patch mlx-lm repository
- `local-models/` - Model directory (git ignored)
- `mlx-lm-repo/` - Modified mlx-lm repository (git ignored)

### Documentation
- `MLX_LM_MANAGEMENT.md` - Guide for managing mlx-lm updates with patches
- `MODEL_CONVERSION.md` - Model conversion documentation
- `CACHE_CONFIGURATION.md` - Prompt cache configuration details
- `SETUP_NOTES.md` - Initial setup notes
- `memory_analysis.md` - Memory usage analysis

### Other
- `logs/` - Log files directory
