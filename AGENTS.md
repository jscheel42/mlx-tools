# AGENTS.md — MLX Tools

## Purpose
This repository wires a local MLX-powered OpenAI-compatible server around a patched `mlx-lm` checkout. Most edits occur in `mlx-lm-repo/` plus root shell scripts for model/server management.

## Quick Commands

### Setup (one-time)
```bash
./setup-mlx-lm-repo.sh && source .venv/bin/activate && cd mlx-lm-repo && uv pip install -e . && cd ..
```

### Testing
```bash
cd mlx-lm-repo

# All tests
python -m unittest discover tests/

# Single test class
python -m unittest tests.test_models.TestModels -v

# Single test method
python -m unittest tests.test_models.TestModelLoad.test_llama -v

# Specific test modules
python -m unittest tests.test_server.TestServer -v
python -m unittest tests.test_tool_parsing -v
python -m unittest tests.test_prompt_cache -v
```

**Tip**: Run individual test methods with `-k`:
```bash
python -m unittest tests.test_models.TestModelLoad.test_llama -v
```

**Tip**: If the local venv is unavailable, run tests with `uvx` and explicit deps:
```bash
cd mlx-lm-repo
uvx --with mlx --with huggingface_hub --with sentencepiece --with tokenizers --with transformers \
  python -m unittest tests.test_prompt_cache -v
```

### Linting & Formatting
```bash
cd mlx-lm-repo

# Install hooks once
pip install pre-commit
pre-commit install

# Run all hooks
pre-commit run --all-files

# Run on specific files
pre-commit run --files path/to/file.py

# Direct formatter tools
black path/to/file.py
isort path/to/file.py
```

## Multi-Model Deployment

**Structure:**
```bash
deploy/
├── <name>/
│   ├── config.json          # Deployment configuration
│   ├── install.sh           # Auto-generated service script
│   ├── uninstall.sh
│   ├── start.sh             # Auto-generated startup script
│   └── logs/
```

### Config Example
```json
{
  "name": "qwen3-5-35b",
  "display_name": "Qwen3.5 35B",
  "model_path": "./local-models/qwen3-5-35b",
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

### Management Commands
```bash
# List all deployments
./manage-deployments.sh list

# Install deployment with optional auto-start
./manage-deployments.sh install <name> [--start]

# Lifecycle management
./manage-deployments.sh start/stop/restart <name>

# View logs (default: 50 lines)
./manage-deployments.sh logs <name> [lines]

# Monitor startup progress
./manage-deployments.sh watch <name>

# Batch operations
./manage-deployments.sh install-all
./manage-deployments.sh uninstall-all
```

### Model Conversion
```bash
./convert-model.sh <hf-model> <name> <bits> [auto|text|multimodal]
```

- `auto` (default): detect modality and choose converter automatically
- `text`: force text-only conversion via `mlx_lm.convert`
- `multimodal`: force multimodal conversion via `mlx_vlm.convert`

**Tip**: Model conversion uses an isolated environment; see `notes/MODEL_CONVERSION.md` for details.

## Code Style Guidelines (Python)

Follow the existing MLX-LM style in `mlx-lm-repo/mlx_lm/`.

### Formatting
- Black-compatible formatting: 4 spaces, 88-char line length
- One statement per line; trailing commas in multiline literals
- Triple-quoted docstrings for public helpers and module-level functions

### Imports
```python
# Order: standard library → third-party → local imports
import copy
import json
from pathlib import Path
from typing import Optional, Dict, Any

import mlx.core as mx
import mlx.nn as nn
from huggingface_hub import snapshot_download

from mlx_lm.models.cache import KVCache
from .utils import load
```
- Group imports with blank lines between groups
- Avoid wildcard imports; import only what you need

### Typing
```python
from dataclasses import dataclass
from typing import Optional, Dict, Any

@dataclass
class Config:
    temp: float = 0.6
    top_p: float = 0.95
    metadata: Optional[Dict[str, Any]] = None
```
- Use type hints for public functions and dataclasses
- Prefer `Optional[T]`, `dict[str, Any]`, `List[T]`, `Tuple[T, ...]`
- Keep type aliases near usage

### Naming
- `snake_case` for functions and variables
- `PascalCase` for classes and dataclasses
- `UPPER_SNAKE_CASE` for constants
- Consistent abbreviations: `kv_cache`, `hf_repo`, `model_path`

### Error Handling
```python
# Raise specific exceptions with actionable messages
if not path.exists():
    raise FileNotFoundError(f"Model not found: {path}")

if temp < 0 or temp > 2:
    raise ValueError(f"Temperature must be 0-2, got {temp}")

# Handle optional dependencies
try:
    from modelscope import snapshot_download
except ImportError:
    raise ImportError("Run `pip install modelscope` to use ModelScope.")
```
- Avoid bare `except`; always specify exception types

### MLX Patterns
```python
import mlx.core as mx
import mlx.nn as nn
from mlx.utils import tree_flatten, tree_map, tree_unflatten

# Use tree utilities for nested parameter operations
weights = tree_map(weights, lambda x: x.astype(mx.float16))
```
- Use `mlx.core` as `mx` and `mlx.nn` as `nn` consistently
- Mirror model structure in `mlx_lm/models/` when adding new models
- Leverage quantized operations for memory efficiency

## Shell Script Guidelines

- Maintain existing Bash style; keep POSIX-compatible where possible
- Use explicit paths and quote variables (`"${var}"`)
- Preserve `start-server.sh` flags and memory-related tuning comments
- Follow the pattern in `manage-deployments.sh` for deployment management

## Custom Patches

This repo uses patched `mlx-lm` with:
- `mlx-lm-prompt-cache-size.patch` — Adds `--prompt-cache-size` CLI argument
- `mlx-small.patch` — Adds `--model-id`, `--wired-limit-mb`, KV cache quantization args

### Managing Patches
When updating `mlx-lm`:
```bash
cd mlx-lm-repo
git fetch upstream
git rebase upstream/main
# Resolve conflicts if needed
cd ..
source .venv/bin/activate && uv pip install -e . && cd ..
manage-deployments.sh restart <name>
```

## Documentation

- Update `README.md`, `QUICKSTART.md` if behavior changes
- Keep command snippets copy-pastable and up to date
- Update this file when adding new commands or workflows
- Maintain `notes/` directory for detailed technical documentation

## Notes

**Code style references:**
- No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` files exist
- Don't add model remappings unless architecture is genuinely missing from upstream
- For model conversion, use `./convert-model.sh` (creates isolated environment)

**Key directories:**
- `mlx-lm-repo/` — Patched MLX-LM library source
- `deploy/` — Multi-model deployment configurations
- `local-models/` — Converted model artifacts
- `notes/` — Technical documentation and guides

**Testing patterns:**
- Use `unittest` for all test files
- Structure tests by component (models, server, tools, cache)
- Leverage `-k` flag for targeted test execution
- Run `pre-commit` hooks before committing changes
