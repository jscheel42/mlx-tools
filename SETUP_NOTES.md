# Setup Notes - MLX OpenAI Server with MiniMax M2.1

## Summary

Successfully configured MiniMax M2.1 REAP 50 (6-bit quantization) with mlx-lm server for OpenCode integration, with full tool calling support.

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
   - Model supports: 196,608 tokens
   - Currently using: 131,072 tokens (4x default)
   - Can be increased if needed

## Installation Steps Taken

1. Converted model to MLX 6-bit quantization (~88GB)
2. Created symlink: `local/MiniMax-M2.1-REAP-50-MLX-6bit`
3. Installed mlx-lm 0.30.1 from git (editable mode)
4. Configured mlx-lm server with:
   - Tool calling parsers (minimax_m2)
   - 131K context length
   - Port 8000
5. Added to OpenCode config with clean model ID

## Files Created

- `start-server.sh` - Start server in foreground
- `stop-server.sh` - Stop server gracefully  
- `install-service.sh` - Install as macOS launchd service
- `uninstall-service.sh` - Remove service
- `com.local.mlx-native-server.plist` - Service configuration
- `README.md` - Complete documentation
- `local/` - Symlinked model directory

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
        "local/MiniMax-M2.1-REAP-50-MLX-6bit": {
          "name": "MiniMax M2.1 REAP 50 (6-bit)"
        }
      }
    }
  }
}
```

## Performance Characteristics

- **Model**: 50B parameters, 6-bit quantization
- **Size**: ~88GB on disk
- **Initial response**: Slow (~6 tok/s) - large model processing from scratch
- **Follow-ups**: Fast (40-55 tok/s) - KV cache working excellently
- **Cache speedup**: 6-10x improvement on subsequent messages

## Future Improvements

1. Try 4-bit quantization for faster performance
2. Increase context to 196K if needed for very long conversations
3. Monitor when PyPI packaging is fixed
4. Consider mlx-lm's native server if better conversation tracking needed

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
