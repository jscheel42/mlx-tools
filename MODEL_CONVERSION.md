# Model Conversion Guide

This guide explains how to convert HuggingFace models to MLX format for use with the MLX server.

## Quick Start

```bash
./convert-model.sh <hf-model-path> <output-name> <bits>
```

### Examples

Convert MiniMax M2.1 to 4-bit quantization:
```bash
./convert-model.sh 0xSero/MiniMax-M2.1-REAP-50 MiniMax-M2.1-REAP-50-MLX-4bit 4
```

Convert MiniMax M2.1 to 6-bit quantization:
```bash
./convert-model.sh 0xSero/MiniMax-M2.1-REAP-50 MiniMax-M2.1-REAP-50-MLX-6bit 6
```

Convert other models:
```bash
./convert-model.sh meta-llama/Llama-3.1-70B-Instruct Llama-3.1-70B-MLX-4bit 4
```

## How It Works

The `convert-model.sh` script:

1. **Creates a temporary environment** (`.mlx-conversion-temp/`)
   - Clones a fresh copy of mlx-lm
   - Sets up a separate Python 3.12 virtual environment
   - Installs mlx-lm and dependencies

2. **Converts the model**
   - Downloads from HuggingFace (if not cached)
   - Converts to MLX format
   - Applies quantization (4-bit, 6-bit, etc.)
   - Saves to `local-models/<output-name>/`

3. **Cleans up**
   - Removes temporary directory
   - Leaves only the converted model

## Why a Separate Environment?

The conversion process uses a **separate virtual environment** from the server:

- **Server environment**: `.venv/` - runs mlx-lm server with our modifications
- **Conversion environment**: `.mlx-conversion-temp/` - fresh mlx-lm for conversion

This separation prevents:
- Dependency conflicts
- Version mismatches
- Accidental contamination of the server environment

## Quantization Levels

| Bits | Size (50B model) | Quality | Speed | Use Case |
|------|------------------|---------|-------|----------|
| 4-bit | ~61GB | Good | Faster | Development, testing |
| 6-bit | ~88GB | Better | Slower | Production, quality |
| 8-bit | ~100GB | Best | Slowest | Maximum quality |

### Recommendations

- **4-bit**: Best for most use cases. Good balance of speed and quality.
- **6-bit**: Use when you have memory to spare and want better quality.
- **8-bit**: Only if you need maximum quality and have 192GB+ RAM.

## Model Storage

Converted models are stored in `local-models/`:

```
local-models/
├── MiniMax-M2.1-REAP-50-MLX-4bit/   (61GB)
├── MiniMax-M2.1-REAP-50-MLX-6bit/   (88GB)
└── <your-model-name>/               (varies)
```

**Note**: `local-models/` is git-ignored to avoid committing large binary files.

## Using a Converted Model

After conversion, update `start-server.sh` to use your new model:

```bash
exec python -m mlx_lm server \
    --model ./local-models/YOUR-MODEL-NAME \
    --host 0.0.0.0 \
    --port 8000 \
    ...
```

Then restart the server:
```bash
./stop-server.sh
./start-server.sh
```

## Advanced Usage

### Manual Conversion

If you need more control, you can manually run the conversion:

```bash
# Create conversion environment
rm -rf .mlx-conversion-temp
mkdir .mlx-conversion-temp
cd .mlx-conversion-temp
git clone https://github.com/ml-explore/mlx-lm.git
cd mlx-lm

# Setup environment
uv venv --python 3.12 .venv
source .venv/bin/activate
uv pip install -e .

# Convert with custom options
python -m mlx_lm.convert \
    --hf-path 0xSero/MiniMax-M2.1-REAP-50 \
    --mlx-path ../../local-models/MiniMax-M2.1-REAP-50-MLX-custom \
    -q --q-bits 4 \
    --q-group-size 64 \
    --q-bits-embedding 8 \
    --trust-remote-code

# Clean up
cd ../..
rm -rf .mlx-conversion-temp
```

### Conversion Options

- `--hf-path`: HuggingFace model ID or local path
- `--mlx-path`: Output directory for MLX model
- `-q`: Enable quantization
- `--q-bits`: Quantization bits (2, 4, 6, 8)
- `--q-group-size`: Group size for quantization (default: 64)
- `--q-bits-embedding`: Embedding quantization bits
- `--trust-remote-code`: Trust remote code (required for some models)

## HuggingFace Cache

Downloaded models are cached in `~/.cache/huggingface/`:

- First conversion: Downloads full model (~100GB+ for 50B models)
- Subsequent conversions: Reuses cached model (much faster)

To clear cache:
```bash
rm -rf ~/.cache/huggingface/hub
```

## Troubleshooting

### Out of Memory

If conversion fails with OOM:
1. Close other applications
2. Try lower quantization (4-bit instead of 6-bit)
3. Ensure you have sufficient swap space

### Download Fails

If HuggingFace download fails:
1. Check internet connection
2. Verify model exists: https://huggingface.co/<model-id>
3. Check if you need authentication:
   ```bash
   huggingface-cli login
   ```

### Conversion Errors

If conversion fails:
1. Check the error message
2. Verify model supports MLX conversion
3. Try updating mlx-lm:
   ```bash
   cd .mlx-conversion-temp/mlx-lm
   git pull
   uv pip install -e . --upgrade
   ```

## Supported Models

Most HuggingFace models are supported, including:

- **Llama** (Meta)
- **Mistral** (Mistral AI)
- **Qwen** (Alibaba)
- **MiniMax M2** (MiniMax)
- **Phi** (Microsoft)
- **Gemma** (Google)

Check [mlx-lm documentation](https://github.com/ml-explore/mlx-lm) for full compatibility list.

## References

- [mlx-lm GitHub](https://github.com/ml-explore/mlx-lm)
- [HuggingFace Models](https://huggingface.co/models)
- [MLX Documentation](https://ml-explore.github.io/mlx/)
