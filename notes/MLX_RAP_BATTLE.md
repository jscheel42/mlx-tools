# 🎤 MLX Tools Rap Battle 🎤

---

## Round 1: Qwen3.5-122b-A10b vs Gemma4

**Qwen3.5-122b-A10b:**
```
Yo, step into the arena, 122 billion in the bank,
Activated 10B, yeah, I run this whole damn Hank.
6-bit quantized but I'm still the heavyweight champ,
wired_limit_mb at 100,000 — you can't handle that, champ.
I'm Qwen3.5, the A10B architecture king,
While you're 26B playin' with what I bring.
My model_path deep in local-models, buried in the stack,
You're google/gemma-4-26B-A4B — put respect on the tag.
```

**Gemma4:**
```
Oh please, 122B and you still need a wired limit?
I'm Google-born, open-weight, runnin' clean on 8-bit.
I got mlx_vlm backend, multimodal vision,
You're text-only qwen, stuck in your precision.
I'm port 8000, snappy, with trust_remote_code,
You're chuggin' through 150K tokens, movin' way too slow.
I'm the fresh blood, the new deploy in the folder,
You're three point five — I'm four, watch me get older.
```

---

## Round 2: mlx-small.patch vs upstream/main

**mlx-small.patch:**
```
1003 lines of pure fire, listen up,
I'm the mlx-small.patch, yeah, I run this whole shop.
KV cache quantization, I put the squeeze on the bytes,
Prompt cache TTL eviction, I dictate the evict styles.
Pin-largest-session, I protect the main thread,
ArraysCache batch fixes, put the mismatch to bed.
qwen3_5 conv state, I resolved the mismatch,
Speculative decoding KV — yeah, I made it a match.
You try to rebase me? Git conflict city,
I'm the patch that keeps this whole operation pretty.
```

**upstream/main:**
```
Oh you think you're so special with your forked repo life?
I'm upstream/main, the original, cut like a knife.
Every `update-mlx-lm.sh --apply-patch` is a prayer,
Hope your diff doesn't explode and leave us both bare.
You're sitting on top of me like a parasite code,
One clean rebase and you're carryin' this load.
I'm the fresh commits, the newest features flow,
You're `.old/mlx-lm-server-enhancements` — time to let go.
```

---

## Round 3: convert-model.sh vs manage-deployments.sh

**convert-model.sh:**
```
I'm the alchemist, baby, HuggingFace to MLX,
Isolated temp env, I never touch the .venv, see?
`.mlx-conversion-temp`, clean clone every time,
Auto-detect multimodal, yeah, I read the config sign.
I check vision_config, visual_tower, mm_projector,
Then hit mlx_vlm.convert like a precise conductor.
4-bit, 6-bit, 8-bit, fp16 — pick your quant,
Drop it in local-models, man, I make the models sweat and sweat.
```

**manage-deployments.sh:**
```
547 lines of bash, I'm the deployment boss,
launchd services, com.local.mlx — I'm the ones that count, y'know?
`install`, `start`, `stop`, `restart`, `watch`, and `logs`,
I spin up your models while you're sit-in' on the docks.
I parse your config.json, grab the port and the name,
`install-all` at midnight, fire up the whole damn game.
You convert one model, cute trick, real proud,
I manage eleven deployments, screamin' loud.
```

---

## Round 4: KV Cache vs Prompt Cache

**KV Cache (8-bit, group size 64):**
```
I'm the KV Cache, baby, livin' in the attention block,
FP16 to 8-bit, watch the memory drop.
Grouped quantization, 64 at a time,
75% reduction, yeah, I'm breakin' the memory crime.
quantized_kv_start at 0, I hit from the very first token,
While you prompt cache arguin' over whose session is spoken.
I disable batching when kv_bits are set,
_is_batchable returns False — deal with it, forget.
```

**Prompt Cache (TTL + Pin-Largest):**
```
Oh you talkin' about memory? I'm the prompt cache king,
LRU with TTL, watch my eviction things.
last_access_ts, I track every read,
Pinned session protectin' the main thread you need.
capacity_evictions, ttl_evictions, I count 'em all,
pinned_max_bytes cap when the pinned sessions stall.
I'm segmented by type — assistant, user, system too,
You're just keys and values, man, there's nothing new.
```

---

## Round 5: bench-local.py (The MC/Hype Man)

**bench-local.py:**
```
🎤 Yo yo, settle down, let the benchmark speak,
I'm bench-local.py, the truth-teller, the weak
From the strong, with --runs 3 and a perf_counter tick,
I measure your tok/s and I don't let you off quick.

avg_latency in seconds, prompt tokens, completion tokens too,
I'm the urllib.request that puts your servers through
The gauntlet, 600-second timeout, temperature 0.2,
And if you crash mid-run? Nah, I'm loggin' that fault.

So Qwen, Gemma, Patch, and Cache — fight all you want,
But when the numbers come in, that's when I draw the count.
I'm 172 lines of Python, concise and clean,
The only one in this battle tellin' the truth, if you know what I mean.
```

---

## Final Verse: AGENTS.md (The Judge)

**AGENTS.md:**
```
Alright, alright, I've been readin' every conf',
From the deploy folder deep to the notes directory.
This whole repo's a meta-tool, patched and forked with pride,
Two git repos nested, with upstream as the guide.

Qwen brings the parameters, Gemma brings the vision,
The patch holds it together through every revision.
The caches save the memory, the scripts save the time,
And bench-local.py reminds us: it's the tok/s that rhyme.

So who won this battle? The whole MLX crew,
Local LLMs on Apple Silicon — that's the truth.
Now if you'll excuse me, I got a pre-commit to run,
`black` and `isort` waitin' — that's how we have fun. 🎤⬇️
```

---

*Drop the mic. `launchctl stop com.local.mlx-all`*
