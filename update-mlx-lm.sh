#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLX_REPO_DIR="${SCRIPT_DIR}/mlx-lm-repo"
PATCH_FILE="${SCRIPT_DIR}/mlx-lm-server-enhancements.patch"

if [ ! -d "$MLX_REPO_DIR" ]; then
    echo "Error: mlx-lm-repo directory not found at $MLX_REPO_DIR"
    exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Patch file not found at $PATCH_FILE"
    exit 1
fi

echo "Updating mlx-lm-repo to latest upstream version..."
cd "$MLX_REPO_DIR"

echo "Stashing any local changes..."
if ! git diff --quiet || ! git diff --cached --quiet; then
    git stash push -m "Auto-stash before update $(date)"
fi

echo "Fetching latest changes from origin..."
git fetch origin

echo "Checking current branch..."
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Switching to main branch..."
    git checkout main
fi

echo "Pulling latest changes from origin/main..."
git pull origin main

echo "Applying local patches..."
if git apply --check "$PATCH_FILE" 2>/dev/null; then
    echo "Applying patch file..."
    git apply "$PATCH_FILE"
    echo "Patch applied successfully"
else
    echo "Warning: Patch could not be applied cleanly"
    echo "Attempting to apply with 3-way merge..."
    if git apply --3way "$PATCH_FILE"; then
        echo "Patch applied with 3-way merge"
    else
        echo "Error: Failed to apply patch"
        echo "You may need to resolve conflicts manually"
        exit 1
    fi
fi

echo "Reinstalling mlx-lm in development mode..."
if [ -f "${SCRIPT_DIR}/.venv/bin/activate" ]; then
    source "${SCRIPT_DIR}/.venv/bin/activate"
    if command -v uv >/dev/null 2>&1; then
        uv pip install -e .
    else
        pip install -e .
    fi
else
    echo "Warning: Virtual environment not found at ${SCRIPT_DIR}/.venv"
    echo "Please run: ./setup-mlx-lm-repo.sh"
fi

echo "Running basic tests to verify update..."
cd "$MLX_REPO_DIR"
if python -m unittest tests.test_models.TestModelLoad.test_llama -v 2>/dev/null; then
    echo "Basic test passed"
else
    echo "Warning: Basic test failed, but update completed"
fi

cd "$SCRIPT_DIR"
echo "Update completed successfully!"
echo ""
echo "Next steps:"
echo "1. Restart any running servers: ./manage-deployments.sh restart <name>"
echo "2. Run full tests if desired: cd mlx-lm-repo && python -m unittest discover tests/"