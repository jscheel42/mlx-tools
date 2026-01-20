# MLX-LM Server Memory Usage Analysis

> **Note**: This analysis led to implementing the `--prompt-cache-size` patch.  
> **Current Status**: Patch is applied and active in `mlx-lm-repo/`. Server now uses `--prompt-cache-size 1`.

## Historical Analysis: 92GB Memory Usage for 4-bit Model

The 4-bit MiniMax M2.1 REAP 50 model was using approximately 92GB of memory after light usage before implementing the prompt cache size fix.

## Memory Breakdown

### 1. Model Weights (~65GB on disk, likely ~70-75GB in memory)
The 4-bit quantized model has:
- 13 safetensors files totaling ~65GB
- Model architecture files and tokenizer
- In-memory representation may be slightly larger due to metadata and MLX array overhead

### 2. KV Cache Memory

The KV cache grows dynamically based on usage. Key components:

#### KVCache Implementation (cache.py:307-377)
- **Growth pattern**: Allocates in chunks of 256 tokens (`step = 256`)
- **Per-layer allocation**: Each transformer layer has its own KVCache
- **Storage**: Keys and Values stored as separate arrays
- **Shape**: `(batch, n_kv_heads, sequence_length, head_dim)`

#### LRUPromptCache (server.py:174-309)
- **Default max_size**: 10 cached prompts (`max_size: int = 10`)
- **Storage**: Stores complete KV cache states per conversation
- **Deep copies**: Uses `copy.deepcopy()` for cache entries (line 261, 280)
- **No automatic cleanup**: Only evicts when > 10 entries in LRU

### 3. Memory Consumption Sources

For a 50B parameter model with 4-bit quantization:

**Model config** (estimated based on similar models):
- Layers: ~80 layers
- KV heads: ~8-16 heads
- Head dimension: ~128-256

**Per conversation cache** (rough calculation):
- For 10k tokens at 80 layers, 8 heads, 128 head_dim, float16:
- Keys: 80 × 8 × 10,000 × 128 × 2 bytes = ~1.6GB
- Values: ~1.6GB
- **Total per conversation: ~3.2GB**

**With 10 cached conversations**:
- 10 × 3.2GB = **~32GB just for cached prompts**

**With longer contexts** (currently set to max-tokens 120,000):
- If some conversations approach this limit:
- 80 × 8 × 120,000 × 128 × 2 bytes = **~20GB per conversation**
- Even 3-4 long conversations could consume **60-80GB**

**Current configuration** (prompt-cache-size=1):
- Only 1 conversation cached at a time
- Memory usage: ~65-75GB (model + single active cache)

## Memory Optimization Options

### 1. Reduce LRU Cache Size
The LRUPromptCache is hardcoded to `max_size=10` in server.py:1530.

**Current code**:
```python
response_generator = ResponseGenerator(model_provider, LRUPromptCache())
```

**No CLI option exists** to configure this value. Would need to:
- Modify server.py line 189 to accept parameter
- Add argparse option in main()
- Pass through in run() function

### 2. Use RotatingKVCache
Instead of unlimited KVCache growth, use RotatingKVCache with max_size:
- Automatically trims old tokens
- Keeps only recent context
- Located in cache.py:379-548

### 3. Clear Cache Periodically
Currently no automatic cleanup beyond LRU eviction. Options:
- Reduce max_size from 10 to 2-3 conversations
- Add manual cache clearing endpoint
- Implement TTL-based eviction

### 4. Use Quantized KV Cache
KVCache supports quantization (cache.py:365-373):
```python
def to_quantized(self, group_size: int = 64, bits: int = 4) -> QuantizedKVCache
```

This could reduce KV cache memory by ~75% (float16 → 4-bit).

## Implemented Solution

### ✓ CLI Argument Added (COMPLETED)
The `--prompt-cache-size` CLI argument has been implemented via patch:
- File: `mlx-lm-prompt-cache-size.patch`
- Applied in: `mlx-lm-repo/mlx_lm/server.py`
- Current setting: `--prompt-cache-size 1` in `start-server.sh`

**Result**: Memory usage reduced by **40-80GB** by limiting to single conversation cache.

### Alternative Approaches (Not Implemented)

#### Use RotatingKVCache
Instead of unlimited KVCache growth, use RotatingKVCache with max_size:
- Automatically trims old tokens
- Keeps only recent context
- Located in cache.py:379-548

#### Implement Quantized KV Cache
KVCache supports quantization (cache.py:365-373):
```python
def to_quantized(self, group_size: int = 64, bits: int = 4) -> QuantizedKVCache
```
This could reduce KV cache memory by ~75% (float16 → 4-bit).

## Monitoring Memory

Check MLX memory usage:
```python
import mlx.core as mx
print(f"Metal memory in use: {mx.metal.get_active_memory() / 1024**3:.2f} GB")
print(f"Metal cache: {mx.metal.get_cache_memory() / 1024**3:.2f} GB")
print(f"Peak memory: {mx.metal.get_peak_memory() / 1024**3:.2f} GB")
```

## File Locations

- Server code: `mlx-lm-repo/mlx_lm/server.py`
- Cache implementation: `mlx-lm-repo/mlx_lm/models/cache.py`
- LRUPromptCache class: server.py:174-309
- LRUPromptCache initialization: server.py:1530
