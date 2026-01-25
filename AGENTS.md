# AGENTS.md — mlx-tools

## Purpose
This repository wires a local MLX-powered OpenAI-compatible server around a patched `mlx-lm` checkout. Most edits happen in `mlx-lm-repo/` plus root shell scripts for model/server management.

## Key Commands

### Quick Reference
```bash
# Setup environment
./setup-mlx-lm-repo.sh && source .venv/bin/activate && cd mlx-lm-repo && uv pip install -e . && cd ..

# Run single test
cd mlx-lm-repo
python -m unittest tests.test_models.TestModelLoad.test_llama -v

# Start server
./start-server.sh
```

### Server Lifecycle
```bash
./start-server.sh        # Start legacy single-model server
./stop-server.sh         # Stop server
./manage-deployments.sh list       # List all deployments
./manage-deployments.sh install <name> --start  # Install & start
./manage-deployments.sh start/stop/restart <name>  # Control deployment
./manage-deployments.sh logs <name>  # View logs
./convert-model.sh <hf-model> <name> <bits>  # Convert model
```

### Launchd Services (macOS)
```bash
./install-service.sh / uninstall-service.sh  # Legacy single-model
./manage-deployments.sh install-all/uninstall-all  # Multi-model
```

### Testing
```bash
cd mlx-lm-repo
python -m unittest discover tests/                  # All tests
python -m unittest tests.test_models.TestModelLoad  # Single test class
python -m unittest tests.test_models.TestModelLoad.test_llama  # Single method
```

### Linting & Type Checking
```bash
cd mlx-lm-repo
pre-commit run --all-files                         # Run all hooks
pre-commit run --files path/to/file.py             # Run on specific files
python -m pytest tests/                            # Run pytest if available
```

### Updating mlx-lm
```bash
cd mlx-lm-repo && git pull origin main && source .venv/bin/activate && uv pip install -e . && cd .. && ./manage-deployments.sh restart <name>
```

**Note:** Don't add model remappings unless architecture is genuinely missing from upstream.

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

## Cursor / Copilot Rules
No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` files
exist in this repository at time of writing.

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
