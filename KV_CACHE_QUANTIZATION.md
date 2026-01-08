# KV Cache Quantization

## Overview

KV (Key-Value) cache quantization reduces memory usage during inference by compressing the cached attention keys and values from 16-bit to 4-bit or 8-bit precision. This is especially beneficial for long context windows.

## Memory Savings

For a 120,000 token context with MiniMax M2.1 REAP 50 (4-bit model):

| KV Cache Precision | Approximate Memory Usage | Memory Reduction |
|-------------------|--------------------------|------------------|
| FP16 (no quant)   | ~100-110 GB             | Baseline         |
| 8-bit             | ~50-60 GB               | ~50%             |
| 4-bit (default)   | ~25-35 GB               | ~70-75%          |

## Quality Impact

- **4-bit quantization**: Minimal quality degradation, barely noticeable in most tasks
- **8-bit quantization**: Virtually no quality loss
- **Recommended**: 4-bit for best memory/quality tradeoff

## Configuration

Edit `start-server.sh` to adjust KV cache quantization:

```bash
--kv-bits 4              # 4-bit quantization (default, recommended)
--kv-group-size 64       # Group size for quantization (default: 64)
--quantized-kv-start 0   # Start quantizing from token 0 (default)
```

### Options

**--kv-bits**
- `4`: Maximum memory savings (~75% reduction)
- `8`: Moderate memory savings (~50% reduction), higher quality
- Omit parameter: Disable quantization (full precision)

**--kv-group-size**
- Quantization group size (default: 64)
- Smaller values = more precision, less compression
- Larger values = more compression, less precision

**--quantized-kv-start**
- Token position to start quantization
- `0`: Quantize from the beginning (recommended)
- Higher values: Keep first N tokens in full precision

## Technical Details

The KV cache stores the attention keys and values for all previous tokens. Without quantization, these are stored in FP16 (16-bit floating point). With quantization, they are compressed to 4-bit or 8-bit integers with minimal quality loss.

The quantization uses grouped quantization where keys/values are quantized in groups (default size: 64) to maintain accuracy while achieving significant compression.

## Monitoring Memory Usage

Check memory usage while running:
```bash
# macOS
top -pid $(pgrep -f "mlx_lm server") -stats mem
```

Or use Activity Monitor to watch the Python process memory.

## When to Use Different Settings

- **4-bit (default)**: Best for most use cases, especially with limited memory
- **8-bit**: If you have memory to spare and want maximum quality
- **No quantization**: Only if you have >128GB RAM and need absolute maximum quality

## Related Settings

Combine with other memory optimizations:
- `--prompt-cache-size 1`: Reduces prompt cache memory (single-user optimization)
- `--max-tokens 65536`: Reduces maximum context window if needed
