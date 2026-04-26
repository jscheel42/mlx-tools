# AGENTS.md — MLX Tools

## Architecture

This repo is **meta-tooling** around a cloned+patched `mlx-lm` checkout. Two separate git repos live here:

- **Main repo** (this directory) — shell scripts, deploy configs, docs. Git-ignores `mlx-lm-repo/`, `local-models/`, `.venv/`.
- **`mlx-lm-repo/`** — separate git repo with `upstream` remote (original `origin` was renamed). Branch `main` tracks upstream; patches are committed on top.

The server runs as an **editable install**: `.venv/` symlinks into `mlx-lm-repo/`, so edits to `mlx-lm-repo/mlx_lm/` take effect immediately.

## Quick Commands

### One-time setup
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
Fetches from `mlx-lm-repo` origin/main (not upstream) and applies `mlx-small.patch`. Alternatively:
```bash
cd mlx-lm-repo
git fetch upstream && git rebase upstream/main
# resolve conflicts → git add → git rebase --continue
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

**Active patch**: `mlx-small.patch` — large patch covering:
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
cd mlx-lm-repo && git diff upstream/main > ../mlx-small.patch
```

## Key Files & Directories

| Path | Purpose |
|------|---------|
| `mlx-lm-repo/mlx_lm/server.py` | OpenAI-compatible server (patched) |
| `mlx-lm-repo/mlx_lm/models/cache.py` | KV/Prompt cache implementation (patched) |
| `mlx-lm-repo/mlx_lm/generate.py` | Generation engine (KV quantization patched) |
| `mlx-lm-repo/mlx_lm/tool_parsers/` | Model-specific tool calling parsers |
| `mlx-lm-repo/tests/` | 17 test modules for the library |
| `deploy/<name>/config.json` | Per-deployment config (port, model, params, kv_cache) |
| `local-models/` | Converted model artifacts (git-ignored) |
| `notes/` | Deep-dive docs — see table below |

## Notes Directory Guide

| File | When to read |
|------|-------------|
| `notes/MLX_LM_MANAGEMENT.md` | Updating mlx-lm while preserving patches |
| `notes/MODEL_CONVERSION.md` | Conversion workflow, quantization levels |
| `notes/KV_CACHE_QUANTIZATION.md` | KV cache bits, memory savings, tuning |
| `notes/CACHE_CONFIGURATION.md` | `--prompt-cache-size` tuning |
| `notes/PROMPT_CACHE_EVICTION_PLAN.md` | TTL eviction + pin-largest-session design |
| `notes/memory_analysis.md` | Memory breakdown, cache sizing rationale |

## Gotchas

- **`mlx-lm-repo/` is git-ignored** but has its own `.git/`. Never `git add mlx-lm-repo/` from the main repo.
- **Two venvs**: `.venv/` for the server; `.mlx-conversion-temp/` is ephemeral and cleaned up automatically.
- **`setup-mlx-lm-repo.sh` renames `origin` → `upstream`** and creates `local-patches` branch. `update-mlx-lm.sh` fetches from `origin` (which is the fork/remote you set up).
- **`--prompt-cache-size 1`** is the recommended default for single-user (saves 40–70 GB). Set to `0` to disable caching entirely.
- **KV quantization disables batching**: when `kv_bits` is set, the server falls back to non-batched generation (`_is_batchable` returns `False`).
- **Deployment `config.json` keys**: `kv_cache.bits`, `kv_cache.group_size`, `kv_cache.quantized_start` map to `--kv-bits`, `--kv-group-size`, `--quantized-kv-start` CLI args.
- **Multimodal deployments** need `server.backend: "mlx_vlm"` in config (e.g. `qwen3.6-35b-a3b-vlm-8bit`).
- **Pre-commit hooks** must be installed inside `mlx-lm-repo/` (the hooks repo lives there).
- **`start-server.sh` does not exist** — deployments use `manage-deployments.sh` and per-deploy `start.sh` scripts generated at install time.
- **`install-service.sh` / `uninstall-service.sh` do not exist** — use `manage-deployments.sh install/uninstall` instead.
- **`notes/QUICKSTART.md` and `notes/README.md` are stale** — they reference old single-deployment workflow and scripts that no longer exist.

## Code Style (mlx-lm-repo)

- Black-compatible: 4 spaces, 88-char line length.
- Import order: stdlib → third-party → local. Group with blank lines.
- `mlx.core` as `mx`, `mlx.nn` as `nn`.
- `snake_case` functions/vars, `PascalCase` classes, `UPPER_SNAKE_CASE` constants.
- No bare `except`; raise specific exceptions with actionable messages.
