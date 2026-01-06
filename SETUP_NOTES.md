# Setup Notes - MLX OpenAI Server with MiniMax M2.1

## Summary

Successfully configured MiniMax M2.1 REAP 50 (4-bit quantization, with 6-bit available) with mlx-lm server for OpenCode integration, with full tool calling support and custom prompt cache sizing.

## Key Findings

### mlx-lm PyPI Packaging Issue

**Problem:** Both PyPI versions 0.30.0 and 0.30.1 are **missing the `tool_parsers` directory** due to a packaging bug in `setup.py`.

- Line 35 in setup.py only includes: `["mlx_lm", "mlx_lm.models", "mlx_lm.quant", "mlx_lm.tuner"]`
- Missing: `"mlx_lm.tool_parsers"`

**Solution:** Install from git repository in editable mode:
```bash
git clone https://github.com/ml-explore/mlx-lm.git
cd mlx-lm
git checkout v0.30.1
uv pip install -e .
```

### Version Timeline

- **v0.30.0** (Dec 18, 2024) - Added MiniMax M2, transformers v5 support
- **v0.30.1** (Jan 6, 2025) - Released ~30 minutes before we checked! 
  - Includes: PR #700 "support minimax m2"
  - Includes: PR #711 "Improve reasoning and tool call parsing in server"
  - **Still has the packaging bug**

## What Works

1. **KV Cache Performance** (Verified with testing script)
   - First request: ~5-6 tok/s (cold cache)
   - Subsequent requests: 40-55 tok/s (6-10x speedup!)
   - Cache is working excellently

2. **Tool Calling**
   - minimax_m2 parser available
   - Reasoning parser included
   - Message converter configured
   - Auto tool choice enabled

3. **Context Length**
   - Model supports: 196,608 tokens (maximum)
   - Currently using: 120,000 tokens (configurable via --max-tokens)
   - Can be increased up to model maximum if needed

## Installation Steps Taken

1. Converted models to MLX format:
   - 4-bit quantization (~61GB) - Currently in use
   - 6-bit quantization (~88GB) - Available for higher quality
2. Cloned mlx-lm from git and applied custom patches
3. Installed mlx-lm in editable mode with `--prompt-cache-size` patch
4. Configured mlx-lm server with:
   - Tool calling parsers (minimax_m2)
   - 120K max tokens
   - Prompt cache size: 1 (optimized for single user)
   - Port 8000
5. Added to OpenCode config

## Repository Structure

- `mlx-lm-repo/` - Cloned and patched mlx-lm (editable install)
- `local-models/` - Converted MLX models
- `convert-model.sh` - Script to convert HuggingFace models
- `setup-mlx-lm-repo.sh` - Script to clone and patch mlx-lm
- `start-server.sh` - Start server in foreground
- `stop-server.sh` - Stop server gracefully  
- `install-service.sh` - Install as macOS launchd service
- `uninstall-service.sh` - Remove service
- `com.local.mlx-native-server.plist` - Service configuration

## OpenCode Configuration

Added to `~/.config/opencode/opencode.json`:

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

Note: Update the model ID in your config if you switch between 4-bit and 6-bit models.

## Performance Characteristics

- **Model**: 50B parameters, 4-bit quantization
- **Size**: ~61GB on disk
- **Initial response**: ~5-6 tok/s (cold cache - processing from scratch)
- **Follow-ups**: 40-55 tok/s (warm cache - KV cache working excellently)
- **Cache speedup**: 6-10x improvement on subsequent messages
- **Memory usage**: ~65-75GB (model + single conversation cache)

## Current Status

- **Active Model**: 4-bit quantization (good balance of speed and quality)
- **Prompt Cache**: Set to 1 (optimized for single-user, saves 40-70GB memory)
- **Installation**: Editable mode from local mlx-lm-repo
- **Updates**: Can pull upstream mlx-lm changes via git rebase

## Future Improvements

1. Switch to 6-bit quantization if higher quality needed
2. Increase max-tokens to 196K if needed for very long conversations
3. Monitor when PyPI packaging is fixed (mlx-lm 0.30.2+)
4. Consider contributing `--prompt-cache-size` patch upstream

## Testing

Verified with cache testing script:
```bash
python3 /tmp/test_cache_detailed.py
```

Results showed excellent cache performance with proper token reuse across conversation turns.

## References

- mlx-lm repo: https://github.com/ml-explore/mlx-lm
- mlx-lm server: https://github.com/ml-explore/mlx-lm
- Model source: https://huggingface.co/0xSero/MiniMax-M2.1-REAP-50

## Date

Setup completed: January 5, 2026
mlx-lm v0.30.1 released: January 6, 2026 (during setup session!)
