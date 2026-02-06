# AGENTS.md — mlx-tools

## Purpose
This repository wires a local MLX-powered OpenAI-compatible server around a patched `mlx-lm` checkout. Most edits happen in `mlx-lm-repo/` plus root shell scripts for model/server management.

## Key Commands

### Quick Reference
```bash
# Setup environment (one-time)
./setup-mlx-lm-repo.sh && source .venv/bin/activate && cd mlx-lm-repo && uv pip install -e . && cd ..

# Run single test
cd mlx-lm-repo
python -m unittest tests.test_models.TestModelLoad.test_llama -v

# Start server (legacy single-model)
./start-server.sh

# Start multi-model deployment (recommended)
./manage-deployments.sh start <name>
```

### Server Lifecycle
```bash
./start-server.sh              # Start legacy single-model server
./stop-server.sh               # Stop server
manage-deployments.sh list     # List all deployments
manage-deployments.sh install <name> [--start]  # Install deployment
manage-deployments.sh start/stop/restart <name>  # Control deployment
manage-deployments.sh logs <name> [lines]  # View logs (default: 50)
manage-deployments.sh watch <name>  # Monitor startup/download progress
convert-model.sh <hf-model> <name> <bits>  # Convert HuggingFace model
```

### Launchd Services (macOS)
```bash
# Legacy single-model (deprecated, use manage-deployments.sh instead)
./install-service.sh / uninstall-service.sh

# Multi-model (recommended)
manage-deployments.sh install-all / uninstall-all
manage-deployments.sh install <name> [--start]
```

### Testing
```bash
cd mlx-lm-repo
python -m unittest discover tests/                  # All tests
python -m unittest tests.test_models.TestModels     # Single test class
python -m unittest tests.test_models.TestModels.test_llama -v  # Single method
python -m unittest tests.test_server.TestServer -v  # Server tests
python -m unittest tests.test_tool_parsing -v       # Tool parsing tests
python -m unittest tests.test_prompt_cache -v       # Prompt cache tests
```

### Linting & Type Checking
```bash
cd mlx-lm-repo
pre-commit run --all-files                         # Run all hooks
pre-commit run --files path/to/file.py             # Run on specific files
black path/to/file.py                              # Format with Black
isort path/to/file.py                              # Sort imports
```

### Updating mlx-lm
```bash
cd mlx-lm-repo
git fetch upstream
git rebase upstream/main
# Resolve conflicts if needed
cd ..
source .venv/bin/activate && uv pip install -e . && cd ..
manage-deployments.sh restart <name>
```

**Note:** Don't add model remappings unless architecture is genuinely missing from upstream.

## Lint / Format Commands
Linting is handled via `pre-commit` in `mlx-lm-repo/`.

**Configuration**: `.pre-commit-config.yaml` uses Black 25.1.0 and isort 6.0.0 (with Black profile).

### Install hooks
```bash
pip install pre-commit
pre-commit install
```

### Run formatters or all hooks
```bash
pre-commit run --all-files
black path/to/file.py
isort path/to/file.py
```

### Run on specific files
```bash
pre-commit run --files file1.py file2.py
```

## Cursor / Copilot Rules
No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` files
exist in this repository at time of writing.

## Multi-Model Deployment

### Deployment Structure
Deployments are managed via `manage-deployments.sh` and stored in `deploy/`:

```
deploy/
├── <name>/
│   ├── config.json          # Deployment configuration
│   ├── install.sh           # Service installation script (auto-generated)
│   ├── uninstall.sh         # Service uninstallation script
│   ├── start.sh             # Server startup script (auto-generated)
│   └── logs/                # Server logs
```

### Configuration (config.json)
```json
{
  "name": "model-name",
  "display_name": "Model Name",
  "model_path": "./local-models/model-name",
  "server": {
    "port": 8000,
    "model_id": "mlx-local",
    "host": "0.0.0.0",
    "wired_limit_mb": 0,
    "trust_remote_code": true
  },
  "parameters": {
    "temp": 0.6,
    "top_p": 0.95,
    "top_k": 20,
    "max_tokens": 100000
  },
  "kv_cache": {
    "bits": 8,
    "group_size": 64,
    "quantized_start": 0
  }
}
```

### Common Tasks
```bash
# Create new deployment
mkdir deploy/my-model
# Create config.json in deploy/my-model/
./manage-deployments.sh install my-model --start

# View deployment status
./manage-deployments.sh status my-model

# Watch startup/download progress
./manage-deployments.sh watch my-model

# Uninstall all deployments
./manage-deployments.sh uninstall-all
```

### Custom Patches
This repo uses patched mlx-lm with:
- `--prompt-cache-size` argument (in `mlx-lm-prompt-cache-size.patch`)
- `--model-id` override for consistent API responses (in `mlx-small.patch`)
- `--wired-limit-mb`, `--kv-bits`, `--kv-group-size`, `--quantized-kv-start` for memory management

## Special Considerations

## Code Style Guidelines (Python)
Follow the existing MLX-LM style in `mlx-lm-repo/mlx_lm/`.

### Formatting
- Use Black-compatible formatting (4 spaces, 88-char line length).
- Keep one statement per line; prefer trailing commas in multiline literals.
- Use triple-quoted docstrings for public helpers and module-level functions.
- No comments unless specifically requested.

### Imports
- Order: standard library → third-party → local imports.
- Group imports with blank lines between groups.
- Avoid wildcard imports; import only what you need.
- No comments in import blocks.

### Typing
- Use type hints for public functions and data classes.
- Prefer `Optional[T]` for nullable values and `dict[str, Any]` for configs.
- Keep type aliases near usage; avoid heavy generics where not required.
- No comments in type hints.

### Naming
- `snake_case` for functions/variables.
- `PascalCase` for classes and dataclasses.
- `UPPER_SNAKE_CASE` for constants.
- Keep abbreviations consistent (`kv_cache`, `hf_repo`, `model_path`).
- No comments in naming rules.

### Error Handling
- Raise specific exceptions (`ValueError`, `FileNotFoundError`, `RuntimeError`).
- Include actionable error messages; avoid bare `except`.
- Use `try/except ImportError` around optional dependencies (see `utils.py`).
- No comments in error handling section.

### Data Structures
- Prefer dataclasses for structured config args.
- Use `Path` from `pathlib` for filesystem paths.
- Keep config dictionaries shallow and documented when possible.
- No comments in data structures section.

### MLX Patterns
- Use `mlx.core` as `mx` and `mlx.nn` as `nn` consistently.
- Use `mlx.utils.tree_*` helpers for nested parameter operations.
- When adding model support, mirror the structure in `mlx_lm/models/`.
- No comments in MLX patterns section.

## Custom Patches

### Patch Files
- `mlx-lm-prompt-cache-size.patch` - Adds `--prompt-cache-size` CLI argument
- `mlx-small.patch` - Adds `--model-id`, `--wired-limit-mb`, KV cache quantization args

### Managing Patches
When updating mlx-lm:
1. `cd mlx-lm-repo && git fetch upstream && git rebase upstream/main`
2. Resolve conflicts if patch areas changed
3. Regenerate patch: `git diff upstream/main > ../mlx-lm-prompt-cache-size.patch`

## Shell Script Guidelines
- Maintain existing Bash style; keep scripts POSIX-compatible where possible.
- Use explicit paths and quote variables (`"${var}"`).
- Preserve `start-server.sh` flags and memory-related tuning comments.

## Documentation Conventions
- Update top-level docs (`README.md`, `QUICKSTART.md`) if behavior changes.
- Keep command snippets copy-pastable and up to date.
- Update this AGENTS.md file when adding new commands or workflows.

## Contribution Notes
- If adding a new model, add a test in `mlx-lm-repo/tests/test_models.py`.
- Run `python -m unittest discover tests/` before submitting PRs.
- Keep patches minimal; this repo tracks a patched MLX-LM snapshot.
- For model conversion, use `./convert-model.sh` (creates isolated environment).
