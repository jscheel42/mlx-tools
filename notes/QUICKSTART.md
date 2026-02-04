# MLX Tools - Quick Start Guide

## What is This?

Tools for running the MiniMax M2.1 REAP 50 language model locally on Apple Silicon using MLX, with an OpenAI-compatible API server.

## Prerequisites

- Apple Silicon Mac (M1/M2/M3/M4)
- 64GB+ unified memory (128GB recommended for 6-bit models)
- macOS 12.0+
- Python 3.12+
- `uv` package manager

## First Time Setup

### 1. Clone and Patch MLX-LM

```bash
./setup-mlx-lm-repo.sh
```

This will:
- Clone mlx-lm from GitHub
- Apply custom `--prompt-cache-size` patch
- Set up for future updates

### 2. Install MLX-LM in Server Environment

```bash
source .venv/bin/activate
cd mlx-lm-repo
uv pip install -e .
cd ..
```

### 3. Convert a Model (if needed)

If you don't have a model in `local-models/` yet:

```bash
./convert-model.sh 0xSero/MiniMax-M2.1-REAP-50 MiniMax-M2.1-REAP-50-MLX-4bit 4
```

This downloads from HuggingFace and converts to MLX format (~30-60 min first time).

### 4. Start the Server

```bash
./start-server.sh
```

The server will start on http://localhost:8000

## Daily Usage

### Start Server (Foreground)

```bash
./start-server.sh
```

Press Ctrl+C to stop.

### Install as Background Service

```bash
./install-service.sh
```

The server will now:
- Start automatically on boot
- Restart if it crashes
- Run in the background

### Manage Service

```bash
# Check status
launchctl list | grep mlx-native-server

# Stop service
launchctl stop com.local.mlx-native-server

# Start service
launchctl start com.local.mlx-native-server

# Uninstall service
./uninstall-service.sh
```

### View Logs

```bash
# Real-time logs
tail -f logs/stdout.log
tail -f logs/stderr.log

# Check recent errors
tail -100 logs/stderr.log
```

## Testing the Server

```bash
# Check server is running
curl http://localhost:8000/v1/models

# Test completion
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local/MiniMax-M2.1-REAP-50-MLX-4bit",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Benchmarking

```bash
python3 bench-local.py --runs 3
```

Override base URL or model ID if needed:

```bash
python3 bench-local.py --base-url http://localhost:8000/v1 --model mlx-local
```

## Configure OpenCode

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

## Common Tasks

### Convert Another Model

```bash
./convert-model.sh <hf-model-name> <output-name> <bits>

# Examples:
./convert-model.sh meta-llama/Llama-3.1-70B-Instruct Llama-3.1-70B-MLX-4bit 4
./convert-model.sh mistralai/Mistral-7B-Instruct-v0.2 Mistral-7B-MLX-4bit 4
```

### Switch Models

1. Edit `start-server.sh`
2. Change the `--model` path to your desired model
3. Restart the server

### Update MLX-LM

```bash
cd mlx-lm-repo
git fetch upstream
git rebase upstream/main
# Resolve conflicts if any
cd ..

# Reinstall
source .venv/bin/activate
cd mlx-lm-repo && uv pip install -e . && cd ..

# Restart server
./stop-server.sh
./start-server.sh
```

## Performance

- **First message**: ~5-6 tokens/sec (cold cache)
- **Follow-up messages**: ~40-55 tokens/sec (warm cache)
- **Speedup**: 6-10x for subsequent messages in same conversation

## Memory Usage

- **4-bit model**: ~65-75GB (model + single conversation cache)
- **6-bit model**: ~90-100GB (model + single conversation cache)

The `--prompt-cache-size 1` setting limits memory by caching only the most recent conversation.

## Troubleshooting

### Server Won't Start

```bash
# Check logs
tail -100 logs/stderr.log

# Verify virtual environment
source .venv/bin/activate
python -c "import mlx_lm; print(mlx_lm.__file__)"
```

### Port Already in Use

```bash
# Stop any existing server
./stop-server.sh

# Or manually kill process on port 8000
lsof -ti:8000 | xargs kill -9
```

### Out of Memory

1. Use 4-bit model instead of 6-bit
2. Reduce `--max-tokens` in `start-server.sh`
3. Close other memory-intensive applications

## File Structure

```
mlx-tools/
├── mlx-lm-repo/               # Patched mlx-lm (git ignored)
├── local-models/              # Converted models (git ignored)
├── .venv/                     # Server virtual environment
├── logs/                      # Server logs
├── start-server.sh            # Start server
├── stop-server.sh             # Stop server
├── convert-model.sh           # Convert HF models to MLX
├── setup-mlx-lm-repo.sh       # Setup mlx-lm with patches
└── install-service.sh         # Install as macOS service
```

## More Information

- **README.md** - Complete server documentation
- **MLX_LM_MANAGEMENT.md** - How to update mlx-lm with patches
- **MODEL_CONVERSION.md** - Detailed conversion guide
- **CACHE_CONFIGURATION.md** - Prompt cache details
- **SETUP_NOTES.md** - Historical setup notes

## Getting Help

1. Check logs: `tail -f logs/stderr.log`
2. Review documentation in this directory
3. Check mlx-lm repo: https://github.com/ml-explore/mlx-lm

## Quick Commands Reference

| Task | Command |
|------|---------|
| Start server (foreground) | `./start-server.sh` |
| Stop server | `./stop-server.sh` |
| Install service | `./install-service.sh` |
| Uninstall service | `./uninstall-service.sh` |
| View logs | `tail -f logs/stdout.log` |
| Convert model | `./convert-model.sh <hf-path> <name> <bits>` |
| Setup mlx-lm | `./setup-mlx-lm-repo.sh` |
| Test server | `curl http://localhost:8000/v1/models` |
