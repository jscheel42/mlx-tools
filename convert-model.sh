#!/bin/bash
#
# Convert HuggingFace models to MLX format with quantization
#
# This script uses a separate virtual environment from the server to avoid
# dependency conflicts. It clones mlx-lm fresh each time to ensure clean conversion.
#
# Usage:
#   ./convert-model.sh <hf-model-path> <output-name> <bits> [auto|text|multimodal]
#
# Examples:
#   ./convert-model.sh 0xSero/MiniMax-M2.1-REAP-50 MiniMax-M2.1-REAP-50-MLX-4bit 4
#   ./convert-model.sh 0xSero/MiniMax-M2.1-REAP-50 MiniMax-M2.1-REAP-50-MLX-6bit 6
#   ./convert-model.sh Qwen/Qwen2.5-VL-7B-Instruct Qwen2.5-VL-7B-MLX-4bit 4 multimodal
#   ./convert-model.sh Qwen/Qwen2.5-VL-7B-Instruct Qwen2.5-VL-7B-TEXT-MLX-4bit 4 text
#

set -e

# Parse arguments
HF_MODEL="${1:-0xSero/MiniMax-M2.1-REAP-50}"
OUTPUT_NAME="${2:-MiniMax-M2.1-REAP-50-MLX-4bit}"
BITS="${3:-4}"
CONVERSION_MODE="${4:-auto}"

if [[ "$CONVERSION_MODE" != "auto" && "$CONVERSION_MODE" != "text" && "$CONVERSION_MODE" != "multimodal" ]]; then
    echo "Error: conversion mode must be one of: auto, text, multimodal"
    echo "Usage: ./convert-model.sh <hf-model-path> <output-name> <bits> [auto|text|multimodal]"
    exit 1
fi

echo "=================================================="
echo "  MLX Model Conversion"
echo "=================================================="
echo ""
echo "Source Model: $HF_MODEL"
echo "Output Name:  $OUTPUT_NAME"
echo "Quantization: ${BITS}-bit"
echo "Mode:         $CONVERSION_MODE"
echo ""
echo "This will:"
echo "  1. Create temporary mlx-lm clone"
echo "  2. Set up conversion environment"
echo "  3. Convert model to MLX format"
echo "  4. Save to local-models/$OUTPUT_NAME"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Change to script directory
cd "$(dirname "$0")"

# Create local-models directory if it doesn't exist
mkdir -p local-models

# Clean up any existing conversion environment
echo ""
echo "Cleaning up previous conversion environment..."
rm -rf .mlx-conversion-temp
mkdir .mlx-conversion-temp
cd .mlx-conversion-temp

# Clone mlx-lm
echo ""
echo "Cloning mlx-lm..."
git clone https://github.com/ml-explore/mlx-lm.git
cd mlx-lm

# Create and activate virtual environment
echo ""
echo "Setting up Python environment..."
uv venv --python 3.12 .venv
source .venv/bin/activate

# Install mlx-lm in editable mode
echo ""
echo "Installing mlx-lm..."
uv pip install -e .

# Run conversion
echo ""
echo "=================================================="
echo "  Starting conversion..."
echo "=================================================="
echo ""

echo "Resolving conversion mode..."
IS_MULTIMODAL=$(python - "$HF_MODEL" <<'PY'
import json
import sys
from pathlib import Path


def looks_multimodal(config: dict) -> bool:
    if not isinstance(config, dict):
        return False

    multimodal_keys = {
        "vision_config",
        "visual",
        "visual_config",
        "multimodal_config",
        "vision_tower",
        "mm_projector_type",
        "audio_config",
    }

    if any(key in config for key in multimodal_keys):
        return True

    model_type = str(config.get("model_type", "")).lower()
    if any(tag in model_type for tag in ["vl", "vision", "llava", "pixtral", "mllama"]):
        return True

    text_config = config.get("text_config", {})
    if isinstance(text_config, dict) and any(key in text_config for key in multimodal_keys):
        return True

    return False


model_ref = sys.argv[1]
config = None
local_config = Path(model_ref) / "config.json"

if local_config.exists():
    config = json.loads(local_config.read_text())
else:
    from huggingface_hub import hf_hub_download

    config_path = hf_hub_download(repo_id=model_ref, filename="config.json")
    with open(config_path, "r") as f:
        config = json.load(f)

print("1" if looks_multimodal(config) else "0")
PY
)

USE_MULTIMODAL=0
if [[ "$CONVERSION_MODE" == "multimodal" ]]; then
    USE_MULTIMODAL=1
elif [[ "$CONVERSION_MODE" == "text" ]]; then
    USE_MULTIMODAL=0
else
    USE_MULTIMODAL="$IS_MULTIMODAL"
fi

if [[ "$USE_MULTIMODAL" == "1" ]]; then
    if [[ "$CONVERSION_MODE" == "multimodal" ]]; then
        echo "Mode forced to multimodal. Using mlx-vlm converter."
    else
        echo "Detected multimodal model. Using mlx-vlm converter to preserve vision/audio support."
    fi
    uv pip install -U "mlx-vlm[torch]"

    MODEL_TYPE=$(python - "$HF_MODEL" <<'PY'
import json
import sys
from pathlib import Path

model_ref = sys.argv[1]
local_config = Path(model_ref) / "config.json"

if local_config.exists():
    config = json.loads(local_config.read_text())
else:
    from huggingface_hub import hf_hub_download

    config_path = hf_hub_download(repo_id=model_ref, filename="config.json")
    with open(config_path, "r") as f:
        config = json.load(f)

print(config.get("model_type", ""))
PY
)

    if ! python - "$MODEL_TYPE" <<'PY'
import importlib
import sys

model_type = sys.argv[1]
try:
    importlib.import_module(f"mlx_vlm.models.{model_type}")
except Exception:
    raise SystemExit(1)
raise SystemExit(0)
PY
    then
        echo "Installed mlx-vlm does not support model_type='$MODEL_TYPE'."
        echo "Installing latest mlx-vlm from GitHub main..."
        uv pip install -U "git+https://github.com/Blaizzy/mlx-vlm.git" torch torchvision
    fi

    CONVERT_CMD="mlx_vlm.convert"
    TRUST_REMOTE_CODE_ARG=""
else
    if [[ "$CONVERSION_MODE" == "text" ]]; then
        echo "Mode forced to text. Using mlx-lm converter."
    else
        echo "Detected text-only model. Using mlx-lm converter."
    fi
    CONVERT_CMD="mlx_lm.convert"
    TRUST_REMOTE_CODE_ARG="--trust-remote-code"
fi

"$CONVERT_CMD" \
    --hf-path "$HF_MODEL" \
    --mlx-path "../../local-models/$OUTPUT_NAME" \
    -q --q-bits "$BITS" \
    ${TRUST_REMOTE_CODE_ARG}

echo ""
echo "=================================================="
echo "  Conversion complete!"
echo "=================================================="
echo ""
echo "Model saved to: local-models/$OUTPUT_NAME"
echo ""
echo "To use this model, update start-server.sh:"
echo "  --model ./local-models/$OUTPUT_NAME \\"
echo ""

# Clean up
cd ../..
echo "Cleaning up temporary files..."
rm -rf .mlx-conversion-temp

echo ""
echo "Done!"
