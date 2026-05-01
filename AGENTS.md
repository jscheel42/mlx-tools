# AGENTS.md — MLX Tools

## Architecture

This repo is **meta-tooling** around an `mlx-lm` checkout. Two separate git repos:

- **Main repo** (this directory) — shell scripts, deploy configs, docs. Git-ignores `mlx-lm-repo/`, `local-models/`, `.venv/`.
- **`mlx-lm-repo/`** — separate git repo. `origin` points to `ml-explore/mlx-lm` (upstream). `main` tracks it; `mlx-small.patch` is applied as unstaged changes.

The server runs as an **editable install**: `.venv/` symlinks into `mlx-lm-repo/`, so edits to `mlx-lm-repo/mlx_lm/` take effect immediately.

## Quick Commands

### Setup
```bash
./setup-mlx-lm-repo.sh
source .venv/bin/activate
cd mlx-lm-repo && uv pip install -e . && cd ..
```

### Model conversion
```bash
./convert-model.sh <hf-model> <output-name> <bits> [auto|text|multimodal]
```
- `auto` (default): detects modality from `config.json` and picks `mlx_lm.convert` or `mlx_vlm.convert`.
- Uses an **isolated temp environment** (`.mlx-conversion-temp/`) — never touches `.venv/`.
- Outputs to `local-models/<output-name>/` (git-ignored).

### Deployment management
```bash
./manage-deployments.sh list
./manage-deployments.sh install <name> [--start]
./manage-deployments.sh start/stop/restart/status/logs/watch <name> [lines]
./manage-deployments.sh install-all/uninstall-all
```
Deployments live in `deploy/<name>/` with `config.json` + auto-generated `install.sh`/`uninstall.sh`/`start.sh`. Each registers as a macOS launchd service (`com.local.mlx-<name>`).

### Update mlx-lm from upstream
```bash
./update-mlx-lm.sh --apply-patch
```
Fetches from `mlx-lm-repo` origin/main and applies `mlx-small.patch`. Alternatively:
```bash
cd mlx-lm-repo && git stash && git pull origin main && git stash pop
cd .. && source .venv/bin/activate && cd mlx-lm-repo && uv pip install -e . && cd ..
```

### Testing (in mlx-lm-repo)
```bash
cd mlx-lm-repo
python -m unittest discover tests/              # all tests
python -m unittest tests.test_prompt_cache -v   # single module
python -m unittest tests.test_prompt_cache.TestPromptCache.test_quantized_cache_nbytes -v  # single test
```
If `.venv` is unavailable:
```bash
cd mlx-lm-repo
uvx --with mlx --with huggingface_hub --with sentencepiece --with tokenizers --with transformers \
  python -m unittest tests.test_prompt_cache -v
```

### Linting (in mlx-lm-repo)
```bash
cd mlx-lm-repo
pip install pre-commit && pre-commit install
pre-commit run --all-files
```
Uses `black` (25.1.0) and `isort` (6.0.0, black profile).

### Benchmark
```bash
python3 bench-local.py --runs 3
python3 bench-local.py --base-url http://localhost:8000/v1 --model mlx-local
```

## Patch Management

**Active patch**: `mlx-small.patch` — covers:
- KV cache quantization (`--kv-bits`, `--kv-group-size`, `--quantized-kv-start`)
- Prompt cache TTL eviction + pin-largest-session (`--prompt-cache-ttl-seconds`, `--prompt-cache-pin-largest-session`, `--prompt-cache-pinned-max-bytes`)
- `--model-id` override for `/v1/models` response
- `ArraysCache` batch dimension fixes
- `qwen3_5`/`qwen3_next` batch-size mismatch in conv state
- Speculative decoding KV quantization propagation
- `LRUPromptCache` TTL + pinning logic

**Superseded**: `.old/mlx-lm-server-enhancements.patch` (old prompt-cache-size patch).

When updating mlx-lm, always regenerate `mlx-small.patch` from the working `mlx-lm-repo`:
```bash
cd mlx-lm-repo && git diff origin/main > ../mlx-small.patch
```

## Deployment Config Format

Each `deploy/<name>/config.json` uses this structure. Only the keys listed below are actually consumed by `install.sh`. Others sit in the JSON but have no effect.

### Text model deployments (text/install.sh)

| Key | CLI arg | Default |
|-----|---------|---------|
| `model_path` | `--model` | — |
| `parameters.temp` | `--temp` | 0.6 |
| `parameters.top_p` | `--top-p` | 0.95 |
| `parameters.top_k` | `--top-k` | 20 |
| `parameters.min_p` | `--min-p` | 0.0 |
| `parameters.max_tokens` | `--max-tokens` | 100000 |
| `server.host` | `--host` | 0.0.0.0 |
| `server.port` | `--port` | 8000 |
| `server.model_id` | `--model-id` | mlx-local |
| `server.prompt_cache_size` | `--prompt-cache-size` | 10 |
| `server.log_level` | `--log-level` | INFO |
| `server.trust_remote_code` | `--trust-remote-code` | true |
| `server.chat_template_args` | `--chat-template-args` (JSON) | `{}` |

**Not wired into install.sh** (listed in old docs but consumed nowhere): `presence_penalty`, `repetition_penalty`, `server.backend`, `server.wired_limit_mb`, `server.prompt_cache_ttl_seconds`, `server.prompt_cache_pin_largest_session`, `server.prompt_cache_pinned_max_mb`.

### VLM deployments (VLM/install.sh)

VLM deploy scripts read a subset of keys and use `mlx_vlm.server` instead of `mlx_lm.server`:

| Key | CLI arg | Default |
|-----|---------|---------|
| `model_path` | resolved to absolute path → symlinked as `server.model_id` alias | — |
| `server.host` | `--host` | 0.0.0.0 |
| `server.port` | `--port` | 8001 |
| `server.model_id` | `MLX_VLM_MODEL_ID` env var + symlink target | mlx-local-vlm |
| `server.trust_remote_code` | `--trust-remote-code` | true |

VLM install.sh auto-installs `mlx-vlm`, `torch`, `torchvision` into `.venv` if missing.

## Key Files

| Path | Purpose |
|------|---------|
| `mlx-lm-repo/mlx_lm/server.py` | OpenAI-compatible server (patched) |
| `mlx-lm-repo/mlx_lm/models/cache.py` | KV/Prompt cache implementation (patched) |
| `mlx-lm-repo/mlx_lm/generate.py` | Generation engine (KV quantization patched) |
| `mlx-lm-repo/mlx_lm/tool_parsers/` | Model-specific tool calling parsers |
| `mlx-lm-repo/tests/` | 17 test modules for the library |
| `deploy/<name>/config.json` | Per-deployment config |
| `local-models/` | Converted model artifacts (git-ignored) |
| `mlx-local` | Symlink → current active model for opencode |
| `mlx-local-vlm` | Symlink → current active VLM model for opencode |
| `notes/` | Deep-dive docs — see table below |

## Notes Directory Guide

| File | When to read |
|------|-------------|
| `notes/MLX_LM_MANAGEMENT.md` | Updating mlx-lm while preserving patches |
| `notes/MODEL_CONVERSION.md` | Conversion workflow, quantization levels |
| `notes/KV_CACHE_QUANTIZATION.md` | KV cache bits, memory savings, tuning |
| `notes/CACHE_CONFIGURATION.md` | Prompt cache sizing |
| `notes/PROMPT_CACHE_EVICTION_PLAN.md` | TTL eviction + pin-largest-session design |
| `notes/memory_analysis.md` | Memory breakdown, cache sizing rationale |

`notes/README.md`, `notes/QUICKSTART.md`, and `notes/SETUP_NOTES.md` are **stale** — reference old single-deployment workflow and scripts that no longer exist.

## Gotchas

- **`mlx-lm-repo/` is git-ignored** but has its own `.git/`. Never `git add mlx-lm-repo/` from the main repo.
- **Two venvs**: `.venv/` for the server; `.mlx-conversion-temp/` is ephemeral and cleaned up automatically.
- **`mlx-lm-repo` remote is `origin`** (not `upstream`). The old `setup-mlx-lm-repo.sh` script still references `upstream` — ignore it; the repo is already set up correctly.
- **Multiple deployments share port 8000** by default — only one can be active at a time. VLM deployments typically use 8001.
- **`--prompt-cache-size`**: set to `0` to disable caching entirely. Per-deployment values vary (1–50).
- **KV quantization disables batching**: when `kv_bits` is set, the server falls back to non-batched generation (`_is_batchable` returns `False`).
- **Pre-commit hooks** must be installed inside `mlx-lm-repo/` (the hooks repo lives there).
- **`mlx-local` / `mlx-local-vlm` symlinks** point to models for opencode's own model config (see `README.md` for opencode integration). They are separate from deployments — deployments use `deploy/<name>/config.json` directly.
- **`mlx-local` currently points to a VLM model** — naming mismatch. Do not assume `mlx-local` is text-only.
- **`presence_penalty` and `repetition_penalty` are not supported** by the current `mlx_lm.server` CLI — install.sh prints a warning for these.

## Code Style (mlx-lm-repo)

- Black-compatible: 4 spaces, 88-char line length.
- Import order: stdlib → third-party → local. Group with blank lines.
- `mlx.core` as `mx`, `mlx.nn` as `nn`.
- `snake_case` functions/vars, `PascalCase` classes, `UPPER_SNAKE_CASE` constants.
- No bare `except`; raise specific exceptions with actionable messages.
