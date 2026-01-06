#!/bin/bash
#
# Convert HuggingFace models to MLX format with quantization
#
# This script uses a separate virtual environment from the server to avoid
# dependency conflicts. It clones mlx-lm fresh each time to ensure clean conversion.
#
# Usage:
#   ./convert-model.sh <hf-model-path> <output-name> <bits>
#
# Examples:
#   ./convert-model.sh 0xSero/MiniMax-M2.1-REAP-50 MiniMax-M2.1-REAP-50-MLX-4bit 4
#   ./convert-model.sh 0xSero/MiniMax-M2.1-REAP-50 MiniMax-M2.1-REAP-50-MLX-6bit 6
#

set -e

# Parse arguments
HF_MODEL="${1:-0xSero/MiniMax-M2.1-REAP-50}"
OUTPUT_NAME="${2:-MiniMax-M2.1-REAP-50-MLX-4bit}"
BITS="${3:-4}"

echo "=================================================="
echo "  MLX Model Conversion"
echo "=================================================="
echo ""
echo "Source Model: $HF_MODEL"
echo "Output Name:  $OUTPUT_NAME"
echo "Quantization: ${BITS}-bit"
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

python -m mlx_lm.convert \
    --hf-path "$HF_MODEL" \
    --mlx-path "../../local-models/$OUTPUT_NAME" \
    -q --q-bits "$BITS" \
    --trust-remote-code

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
