# MLX OpenAI Server - MiniMax M2.1 REAP 50

OpenAI-compatible server for running MiniMax M2.1 REAP 50 (4-bit quantization) locally with MLX on Apple Silicon.

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

- **Model**: MiniMax M2.1 REAP 50 (4-bit quantization, ~61GB)
- **Max Tokens**: 120,000 tokens
- **Prompt Cache**: Size 1 (optimized for single user)
- **Port**: 8000
- **Base URL**: `http://localhost:8000/v1`
- **Model ID**: `local/MiniMax-M2.1-REAP-50-MLX-4bit`
- **Tool Calling**: Enabled (minimax_m2 parser)

## Script Management

There are two pairs of scripts for managing the server:

### 1. Start/Stop Server (start-server.sh / stop-server.sh)
Use these to control the running server process:

```bash
# Start server (foreground or via launchd)
./start-server.sh          # or: launchctl start com.local.mlx-native-server

# Stop server (kills process gracefully)
./stop-server.sh           # or: launchctl stop com.local.mlx-native-server
```

These scripts control the **running instance** of the server. If the service is installed, stopping will keep it stopped until you start it again.

### 2. Install/Uninstall Service (install-service.sh / uninstall-service.sh)
Use these to manage the **launchd service configuration**:

```bash
# Install service (enables auto-start on boot)
./install-service.sh

# Uninstall service (removes auto-start configuration)
./uninstall-service.sh
```

**Install** registers the service with macOS to auto-start on boot.  
**Uninstall** removes the service registration entirely.

### Service Behavior

When installed as a service:
- **Auto-starts** on system boot
- **Auto-restarts** if it crashes (but not on clean stop)
- Use `./stop-server.sh` to stop it (stays stopped until manually started)
- Use `./uninstall-service.sh` to remove auto-start behavior

### Manual Service Control

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
        "local/MiniMax-M2.1-REAP-50-MLX-4bit": {
          "name": "MiniMax M2.1 REAP 50 (4-bit)"
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
    "id": "local/MiniMax-M2.1-REAP-50-MLX-4bit",
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

Reduce max tokens in `start-server.sh`:
```bash
--max-tokens 65536  # or lower
```

The 4-bit model is already in use. If still experiencing issues, increase prompt-cache-size reduces memory usage (already set to 1).

## Model Details

### Active Model
- **Original**: MiniMax-M2.1-REAP-50
- **Quantization**: 4-bit
- **Size**: ~61GB
- **Max Context**: 196,608 tokens (model capability)
- **Current Setting**: 120,000 tokens (configurable in start-server.sh)
- **Location**: `local-models/MiniMax-M2.1-REAP-50-MLX-4bit/`

### Available Models
The `local-models/` directory may also contain:
- `MiniMax-M2.1-REAP-50-MLX-6bit` (~88GB) - Higher quality, slower
- Other converted models

To switch models, edit `start-server.sh` and change the `--model` path.

## Dependencies

- Python 3.12+
- mlx-lm 0.30.1+ (from git, installed in editable mode with custom patches)
  - Installed from: `mlx-lm-repo/`
  - Custom patches: `--prompt-cache-size` argument
- Apple Silicon Mac (M1/M2/M3 with 64GB+ unified memory recommended)

## Files

### Server Management
- `start-server.sh` - Start the server in foreground
- `stop-server.sh` - Stop the server gracefully
- `install-service.sh` - Install as macOS launchd service (auto-configures paths)
- `uninstall-service.sh` - Uninstall the service
- `com.local.mlx-native-server.plist.template` - Service configuration template

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
