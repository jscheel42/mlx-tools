# AGENTS.md — mlx-tools

## Purpose
This repository wires a local MLX-powered OpenAI-compatible server around a
patched `mlx-lm` checkout. Most code edits happen under `mlx-lm-repo/` (the
vendored MLX-LM repo) plus a handful of shell scripts at the repo root that
manage models and the server lifecycle.

## Repo Layout (high-level)
- `start-server.sh`, `stop-server.sh` — run/stop the server locally (legacy, single-model).
- `install-service.sh`, `uninstall-service.sh` — macOS launchd service control (legacy, single-model).
- `convert-model.sh` — convert HF models to MLX format.
- `setup-mlx-lm-repo.sh` — clone/patch the MLX-LM repo.
- `deploy/` — multi-model deployment configuration directory (recommended).
- `mlx-lm-repo/` — editable MLX-LM source tree (tests and code live here).
- `local-models/` — converted models (git-ignored).
- `logs/` — server logs.

## Deployment Structure

The `deploy/` directory contains individual model deployments. Each deployment has:

```
deploy/
└── [deployment-name]/
    ├── config.json      # Model configuration
    ├── install.sh       # Install as launchd service
    ├── uninstall.sh     # Uninstall service
    └── logs/            # Service logs (created on install)
```

### Config Schema (config.json)
```json
{
  "name": "deployment-name",
  "display_name": "Human Readable Name",
  "model_path": "./local-models/model-name",
  "parameters": {
    "temp": 0.6,
    "top_p": 0.95,
    "top_k": 20,
    "max_tokens": 100000
  },
  "kv_cache": {
    "bits": 6,
    "group_size": 64,
    "quantized_start": 0
  },
  "server": {
    "host": "0.0.0.0",
    "port": 8000,
    "model_id": "mlx-local",
    "trust_remote_code": true,
    "prompt_cache_size": 1
  }
}
```

### Multi-Model Deployment Commands
Use `manage-deployments.sh` to manage multiple models:

```bash
./manage-deployments.sh list                    # List all deployments
./manage-deployments.sh install <name>          # Install a deployment
./manage-deployments.sh install <name> --start  # Install and start
./manage-deployments.sh uninstall <name>        # Uninstall a deployment
./manage-deployments.sh start <name>            # Start a deployment
./manage-deployments.sh stop <name>             # Stop a deployment
./manage-deployments.sh restart <name>          # Restart a deployment
./manage-deployments.sh status <name>           # Show deployment status
./manage-deployments.sh logs <name> [lines]     # Show logs
./manage-deployments.sh watch <name>            # Watch download/startup progress
./manage-deployments.sh install-all             # Install all deployments
./manage-deployments.sh uninstall-all           # Uninstall all deployments
./manage-deployments.sh start-all               # Start all deployments
./manage-deployments.sh stop-all                # Stop all deployments
```

Each deployment gets a unique launchd service name: `com.local.mlx-[name]`

## Build / Run Commands
These are the canonical commands referenced in repo docs.

### Setup (first time)
```bash
./setup-mlx-lm-repo.sh
source .venv/bin/activate
cd mlx-lm-repo && uv pip install -e . && cd ..
```

### Start / Stop Server
```bash
./start-server.sh
./stop-server.sh
```

### Launchd Service (macOS)
```bash
./install-service.sh
./uninstall-service.sh
launchctl start com.local.mlx-native-server
launchctl stop com.local.mlx-native-server
```

### Multi-Model Deployment (Recommended)
```bash
./manage-deployments.sh list
./manage-deployments.sh install <deployment-name>
./manage-deployments.sh install <deployment-name> --start
./manage-deployments.sh start <deployment-name>
./manage-deployments.sh stop <deployment-name>
./manage-deployments.sh logs <deployment-name>
```

### Model Conversion
```bash
./convert-model.sh <hf-model> <output-name> <bits>
```

### Updating mlx-lm for New Model Support
When encountering a "Model type X not supported" error for a new/recent model:

1. **Check upstream first** — New model architectures are frequently added to mlx-lm.
   Pull the latest changes before attempting to write custom model support:
   ```bash
   cd mlx-lm-repo
   git fetch origin
   git log origin/main --oneline -10  # Check for relevant commits
   git pull origin main
   ```

2. **Reinstall after pulling:**
   ```bash
   source .venv/bin/activate
   cd mlx-lm-repo && uv pip install -e . && cd ..
   ```

3. **Restart the deployment:**
   ```bash
   ./manage-deployments.sh restart <deployment-name>
   ```

**Important:** Do NOT attempt to add model remappings (`MODEL_REMAPPING` in `utils.py`)
or write new model files unless you've confirmed the architecture is genuinely missing
from upstream mlx-lm.

## Lint / Format Commands
Linting is handled via `pre-commit` in `mlx-lm-repo/`.

### Install hooks
```bash
pip install pre-commit
pre-commit install
```

### Run formatters or all hooks
```bash
pre-commit run --all-files
black path/to/file.py
clang-format -i path/to/file.cpp
```

### Run on specific files
```bash
pre-commit run --files file1.py file2.py
```

## Test Commands
Tests live in `mlx-lm-repo/tests` and use `unittest`.

### Run all tests
```bash
cd mlx-lm-repo
python -m unittest discover tests/
```

### Run a single file
```bash
cd mlx-lm-repo
python -m unittest tests/test_models.py
```

### Run a single test case or method
```bash
cd mlx-lm-repo
python -m unittest tests.test_models.TestModelLoad
python -m unittest tests.test_models.TestModelLoad.test_llama
```

## Cursor / Copilot Rules
No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` files
exist in this repository at time of writing.

## Code Style Guidelines (Python)
Follow the existing MLX-LM style in `mlx-lm-repo/mlx_lm/`.

### Formatting
- Use Black-compatible formatting (4 spaces, 88-char line length).
- Keep one statement per line; prefer trailing commas in multiline literals.
- Use triple-quoted docstrings for public helpers and module-level functions.

### Imports
- Order: standard library → third-party → local imports.
- Group imports with blank lines between groups.
- Avoid wildcard imports; import only what you need.

### Typing
- Use type hints for public functions and data classes.
- Prefer `Optional[T]` for nullable values and `dict[str, Any]` for configs.
- Keep type aliases near usage; avoid heavy generics where not required.

### Naming
- `snake_case` for functions/variables.
- `PascalCase` for classes and dataclasses.
- `UPPER_SNAKE_CASE` for constants.
- Keep abbreviations consistent (`kv_cache`, `hf_repo`, `model_path`).

### Error Handling
- Raise specific exceptions (`ValueError`, `FileNotFoundError`, `RuntimeError`).
- Include actionable error messages; avoid bare `except`.
- Use `try/except ImportError` around optional dependencies (see `utils.py`).

### Data Structures
- Prefer dataclasses for structured config args.
- Use `Path` from `pathlib` for filesystem paths.
- Keep config dictionaries shallow and documented when possible.

### MLX Patterns
- Use `mlx.core` as `mx` and `mlx.nn` as `nn` consistently.
- Use `mlx.utils.tree_*` helpers for nested parameter operations.
- When adding model support, mirror the structure in `mlx_lm/models/`.

## Shell Script Guidelines
- Maintain existing Bash style; keep scripts POSIX-compatible where possible.
- Use explicit paths and quote variables (`"${var}"`).
- Preserve `start-server.sh` flags and memory-related tuning comments.

## Documentation Conventions
- Update top-level docs (`README.md`, `QUICKSTART.md`) if behavior changes.
- Keep command snippets copy-pastable and up to date.

## Contribution Notes
- If adding a new model, add a test in `mlx-lm-repo/tests/test_models.py`.
- Run `python -m unittest discover tests/` before submitting PRs.
- Keep patches minimal; this repo tracks a patched MLX-LM snapshot.
