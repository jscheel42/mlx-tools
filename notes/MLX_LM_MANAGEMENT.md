# MLX-LM Repository Management

## Overview

This project uses a locally modified version of mlx-lm with custom patches. The `mlx-lm-repo` directory is managed separately from the main mlx-tools repository to allow for easy updates while preserving our changes.

## Directory Structure

```
mlx-tools/                          # Main project (tracked in git)
├── mlx-lm-repo/                    # Modified mlx-lm (git ignored, managed separately)
│   └── .git/                       # Separate git repo
├── setup-mlx-lm-repo.sh            # Script to clone and patch mlx-lm
├── mlx-lm-prompt-cache-size.patch  # Our custom patch
└── .venv/                          # Server virtual environment
    └── lib/.../mlx_lm/             # Symlinked to mlx-lm-repo (editable install)
```

## Our Custom Patches

### 1. Prompt Cache Size Configuration

**File**: `mlx-lm-prompt-cache-size.patch`

**What it does**:
- Adds `--prompt-cache-size` CLI argument to control memory usage
- Default: 10 cached conversations
- Recommended for single-user: 1 (saves 40-70GB memory)

**Changes**:
- Added CLI argument in `main()` function
- Modified `LRUPromptCache` initialization to accept `max_size` parameter
- Extracted cache size from CLI args in `run()` function

## Initial Setup

### Clone and Apply Patches

```bash
./setup-mlx-lm-repo.sh
```

This script will:
1. Clone mlx-lm from upstream (https://github.com/ml-explore/mlx-lm.git)
2. Rename origin to upstream
3. Create a `local-patches` branch
4. Apply the prompt-cache-size patch
5. Commit the changes

### Install in Server Environment

After cloning, install mlx-lm in editable mode:

```bash
source .venv/bin/activate
cd mlx-lm-repo
uv pip install -e .
cd ..
```

With editable mode, changes to `mlx-lm-repo/mlx_lm/server.py` take effect immediately without reinstalling.

## Updating MLX-LM

When you want to update to the latest upstream version:

### 1. Fetch Latest Upstream Changes

```bash
cd mlx-lm-repo
git fetch upstream
```

### 2. Rebase Your Patches

```bash
git rebase upstream/main
```

This will:
- Apply upstream changes first
- Then re-apply your local patches on top
- May result in conflicts if upstream modified the same areas

### 3. Resolve Conflicts (if any)

If rebase reports conflicts:

```bash
# Edit the conflicting files (likely mlx_lm/server.py)
# Look for conflict markers: <<<<<<<, =======, >>>>>>>

# After resolving:
git add mlx_lm/server.py
git rebase --continue
```

### 4. Verify Changes

```bash
# Check that your patch is still applied correctly
git log -1 --stat

# Test the server
cd ..
./start-server.sh
```

### 5. Regenerate Patch (Optional)

If you want to update the patch file after resolving conflicts:

```bash
# From mlx-lm-repo directory
git diff upstream/main > ../mlx-lm-prompt-cache-size.patch
```

## Alternative: Cherry-Pick Specific Updates

If you want to pull in specific upstream commits instead of rebasing everything:

```bash
cd mlx-lm-repo
git fetch upstream

# View available commits
git log upstream/main --oneline -20

# Cherry-pick specific commits
git cherry-pick <commit-hash>
```

## Troubleshooting

### Patch Won't Apply

If `setup-mlx-lm-repo.sh` fails to apply the patch:

1. **Manual application**:
   ```bash
   cd mlx-lm-repo
   # Edit mlx_lm/server.py manually
   # Add the changes from mlx-lm-prompt-cache-size.patch
   git add mlx_lm/server.py
   git commit -m "Add --prompt-cache-size CLI argument"
   ```

2. **Update the patch**: The upstream code may have changed significantly. Review the patch and create a new one based on the current upstream code.

### Rebase Conflicts

If rebase conflicts are difficult to resolve:

1. **Abort the rebase**:
   ```bash
   git rebase --abort
   ```

2. **Try a merge instead**:
   ```bash
   git merge upstream/main
   # Resolve conflicts
   git add .
   git commit
   ```

3. **Start fresh**: If all else fails, re-run `setup-mlx-lm-repo.sh` to start over.

### Verify Editable Install

Check that mlx-lm is installed in editable mode:

```bash
source .venv/bin/activate
pip show mlx-lm
```

Should show:
```
Location: .venv/lib/python3.12/site-packages
Editable project location: <your-path>/mlx-tools/mlx-lm-repo
```

## Testing the Patch

Verify the `--prompt-cache-size` argument works:

```bash
source .venv/bin/activate
cd mlx-lm-repo
python -m mlx_lm.server --help | grep prompt-cache-size
```

Should output:
```
  --prompt-cache-size PROMPT_CACHE_SIZE
                        Maximum size of the LRU prompt cache (default: 10)
```

## Git Workflow Summary

```bash
# Initial setup
./setup-mlx-lm-repo.sh

# Install in server environment
source .venv/bin/activate
cd mlx-lm-repo && uv pip install -e . && cd ..

# Update from upstream (periodically)
cd mlx-lm-repo
git fetch upstream
git rebase upstream/main
# Resolve conflicts if needed
cd ..

# Verify server still works
./start-server.sh
```

## Why This Approach?

1. **Separate git repos**: The main mlx-tools repo doesn't track mlx-lm-repo, avoiding nested git issues
2. **Easy updates**: Can pull upstream changes while preserving patches
3. **Editable install**: Server uses symlinked code, so changes take effect immediately
4. **Patch tracking**: The `.patch` file documents our changes and can be re-applied if needed
5. **Clean separation**: Model conversion uses a fresh mlx-lm clone, server uses patched version
