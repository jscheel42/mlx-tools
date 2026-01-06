#!/bin/bash
#
# Setup mlx-lm-repo with custom prompt cache size patch
#
# This script:
# 1. Clones the mlx-lm repository from upstream
# 2. Applies the prompt-cache-size patch
# 3. Sets up the repository for future updates
#
# To update mlx-lm in the future while keeping the patch:
#   cd mlx-lm-repo
#   git fetch upstream
#   git rebase upstream/main
#   # Resolve any conflicts if the patch area changed
#

set -e

UPSTREAM_URL="https://github.com/ml-explore/mlx-lm.git"
PATCH_FILE="mlx-lm-prompt-cache-size.patch"

echo "=================================================="
echo "  MLX-LM Repository Setup"
echo "=================================================="
echo ""
echo "This will:"
echo "  1. Clone mlx-lm from: $UPSTREAM_URL"
echo "  2. Apply prompt-cache-size patch"
echo "  3. Configure for future updates"
echo ""

# Change to script directory
cd "$(dirname "$0")"

# Check if mlx-lm-repo already exists
if [ -d "mlx-lm-repo" ]; then
    echo "⚠️  mlx-lm-repo directory already exists!"
    echo ""
    read -p "Remove and re-clone? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing mlx-lm-repo..."
        rm -rf mlx-lm-repo
    else
        echo "Cancelled"
        exit 0
    fi
fi

# Clone the repository
echo ""
echo "Cloning mlx-lm from upstream..."
git clone "$UPSTREAM_URL" mlx-lm-repo
cd mlx-lm-repo

# Add upstream remote (for future updates)
echo ""
echo "Configuring remotes..."
git remote rename origin upstream

# Create a local branch for our changes
echo ""
echo "Creating local branch with patches..."
git checkout -b local-patches

# Apply the patch
echo ""
echo "Applying prompt-cache-size patch..."
if git apply --check "../$PATCH_FILE" 2>/dev/null; then
    git apply "../$PATCH_FILE"
    git add -A
    git commit -m "Add --prompt-cache-size CLI argument

This adds a configurable prompt cache size to control memory usage.

- Added --prompt-cache-size argument (default: 10)
- Pass cache size to LRUPromptCache initialization
- Allows limiting memory usage for single-user scenarios"
    echo "✓ Patch applied successfully"
else
    echo "⚠️  Patch failed to apply cleanly"
    echo ""
    echo "This might mean:"
    echo "  - The upstream code has changed"
    echo "  - The patch needs to be updated"
    echo ""
    echo "Attempting to apply anyway..."
    git apply "../$PATCH_FILE" || {
        echo ""
        echo "❌ Failed to apply patch"
        echo ""
        echo "Manual steps:"
        echo "  1. Review the changes in ../$PATCH_FILE"
        echo "  2. Manually edit mlx_lm/server.py"
        echo "  3. Run: git add mlx_lm/server.py"
        echo "  4. Run: git commit -m 'Add --prompt-cache-size CLI argument'"
        exit 1
    }
fi

echo ""
echo "=================================================="
echo "  Setup Complete!"
echo "=================================================="
echo ""
echo "Repository location: mlx-lm-repo/"
echo "Current branch: local-patches"
echo "Upstream remote: upstream (ml-explore/mlx-lm)"
echo ""
echo "To update from upstream in the future:"
echo "  cd mlx-lm-repo"
echo "  git fetch upstream"
echo "  git rebase upstream/main"
echo ""
echo "If rebase conflicts occur:"
echo "  1. Resolve conflicts in mlx_lm/server.py"
echo "  2. Run: git add mlx_lm/server.py"
echo "  3. Run: git rebase --continue"
echo ""
echo "To reinstall after updates:"
echo "  cd mlx-lm-repo"
echo "  source ../.venv/bin/activate"
echo "  uv pip install -e ."
echo ""
