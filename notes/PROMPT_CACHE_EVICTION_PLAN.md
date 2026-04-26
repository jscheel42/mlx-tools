# Prompt Cache Eviction Plan (`mlx_lm.server`)

## Goals

1. Add optional time-based cache expiration for prompt KV cache entries.
2. Add optional protection for the "largest session" (intended main agent thread).
3. Keep behavior unchanged by default unless flags are explicitly enabled.
4. Implement through local `mlx-lm-repo` changes and preserve via `mlx-small.patch`.

## Scope

In scope:

- `mlx_lm.server` request/cache flow
- `mlx_lm/models/cache.py` prompt cache policy
- deployment/config wiring for new flags
- tests for eviction behavior

Out of scope:

- `mlx_vlm.server` cross-request prompt KV reuse
- upstream architectural changes for multimodal cache batching

## Current State (Summary)

- Prompt cache eviction is capacity-based (count/bytes), not TTL-based.
- Cache is bucketed by segment type (`assistant`, `user`, `system`) and evicted with LRU-like policy.
- No explicit "session id" concept in eviction policy.

## Proposed Features

### A) TTL Eviction (Phase 1)

Add optional global TTL for prompt cache entries.

New server arg:

- `--prompt-cache-ttl-seconds` (int, default `0`; `0` means disabled)

Behavior:

- On cache read/insert/periodic maintenance, drop entries whose `now - last_access_ts > ttl_seconds`.
- TTL eviction runs before capacity eviction.
- Existing behavior remains unchanged when `ttl_seconds == 0`.

### B) Pin Largest Session (Phase 2)

Add optional protection of one inferred "largest session".

New server args:

- `--prompt-cache-pin-largest-session` (bool, default `false`)
- `--prompt-cache-pinned-max-bytes` (int, default `0`; `0` means no separate cap)

Inferred session strategy:

- Use a deterministic session key derived from request context (chat history lineage / cache key root).
- Track aggregate bytes and token length by session.
- Mark the largest session as protected during normal capacity eviction.

Safety:

- If pinned bytes exceed `prompt-cache-pinned-max-bytes` (when set), allow eviction from pinned set.
- TTL still applies to pinned entries unless explicitly disabled.

## Data Model Changes

Add metadata per cache entry in prompt cache store:

- `created_ts`
- `last_access_ts`
- `session_key` (nullable)
- `session_tokens` (approx lineage length)
- `entry_bytes` (already derivable; store for fast accounting)

Add aggregate session index:

- `session_key -> {total_bytes, total_tokens, entry_ids}`

## Eviction Order

When inserting/updating:

1. TTL eviction pass (if enabled).
2. Capacity eviction pass.
3. During capacity eviction:
   - Prefer non-pinned entries first.
   - Keep existing type/LRU ordering within non-pinned set.
   - Evict pinned entries only if no non-pinned entries remain or pinned cap exceeded.

## API/CLI/Config Wiring

`mlx_lm.server`:

- parse and store new args in server config
- pass policy options into prompt cache manager

Deployment scripts/config:

- allow optional keys under `server` for TTL and pin settings
- keep defaults off to preserve behavior

## Testing Plan

Unit tests (`tests/test_prompt_cache.py` and/or server tests):

1. TTL disabled keeps old behavior.
2. TTL enabled evicts stale entries.
3. Access refreshes `last_access_ts`.
4. Capacity eviction still works with TTL off/on.
5. Pin-largest enabled preserves largest session during eviction.
6. Pinned max bytes cap forces pinned eviction when exceeded.
7. Mixed segment types (`system/user/assistant`) still behave correctly.

Integration smoke tests:

- repeated long-context chat with one main thread + subagent requests
- verify main thread hit ratio improves vs baseline

## Rollout Plan

Phase 1:

- Implement TTL only.
- Ship with defaults disabled.
- Validate no regression in throughput and cache hits when disabled.

Phase 2:

- Implement pin-largest-session + pinned cap.
- Measure hit-rate/latency impact under multi-agent workload.

Phase 3:

- Tune defaults per deployment (if desired), otherwise leave opt-in.

## Observability Additions

Add optional debug logs/counters:

- `ttl_evictions`
- `capacity_evictions`
- `pinned_evictions`
- `pinned_session_key`
- `cache_bytes_total`, `cache_bytes_pinned`

## Risks

- Session inference may misclassify if request lineage is ambiguous.
- Over-pinning can reduce overall cache utility for parallel subagents.
- Extra metadata/accounting may add slight CPU overhead.

Mitigations:

- opt-in flags
- pinned byte cap
- metrics-driven tuning

## Patch Workflow

1. Implement in `mlx-lm-repo`.
2. Run targeted tests (`test_prompt_cache`, relevant server tests).
3. Regenerate `mlx-small.patch` from modified `mlx-lm-repo` files.
4. Verify with `./update-mlx-lm.sh --apply-patch`.
5. Reinstall/restart target deployment and validate logs/behavior.
