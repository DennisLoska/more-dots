---
name: generate-instrumental
description: Generate instrumental background music via local ComfyUI using Stable Audio 3 Medium (SA3) and ACE Step 1.5 XL. Aware of both workflows, sequential single-queue, 10-300s duration. Use when user wants bgm, instrumental, background music, score, or audio without vocals.
---

# Generate-Instrumental (ComfyUI)

Instrumental music via `comfy-mcp` ONLY — local. Requires `server_info` first, `validate_workflow` preflight, `run_workflow`+`fetch_outputs`. No cloud. Supports **SA3 Medium** (reprompt+duration, cinematic/ambient) and **ACE Step 1.5 XL** (bpm/key control, longer). Single-worker sequential.

## MCP-Only Rule (MANDATORY)

All ComfyUI work via `comfy-mcp` tools only:

* Allowed: `server_info`, `search_models(folder=checkpoints)`, `nodes(action=get)`, `validate_workflow`, `run_workflow`, `job(action=status|wait|queue)`, `fetch_outputs`, `system_stats`/`free_memory`
* Forbidden: `bash` cat/find/ls on `/run/media/dennis/ai/comfy-ui/**`, direct read of checkpoints outside MCP
* Workflows: `templates/sa3_medium_api_base.json` (34K, SA3 reprompt) + `templates/ace_1.5_xl_api_base.json` (2.9K, ACE). Copy to `/tmp/<id>.json` per run via `default.write`, edit `prompt/duration/seed`, never cwd.

If file outside allowed dirs, use MCP or bundled templates — never bash path.

## Workflow Basis

**SA3 Medium** (`stable_audio_3_medium_base.safetensors 8.6G`, `t5gemma_b_b_ul2`, `qwen3.5_2b_bf16`):

* `Prim StringMultiline 52:31` prompt, `ComfyMathExpression 52:36` duration (also `EmptyLatentAudio 52:11 seconds`), `KSampler 52:3 lcm 50 cfg7`, `VAEDecodeAudio 52:12` -> `SaveAudioMP3 19` (`quality V0` -> `mp3` 44.1k). Reprompt chain `52:49 JsonExtract -> 52:38 SYSTEM_PROMPTS -> 52:39 USER_INPUT -> 52:40 AUDIO_LENGTH -> 52:34 Switch` rewrites prompt via `qwen3.5_2b`+`TextGenerate 52:28` if `52:35 Enable_Reprompt true`. Default `Enable_Reprompt true`, prompt `experimental emo pop... BPM: X Length: Y`.
* Duration 10-300s, best 30-120s instrumental. Fast LCM 50 steps.

**ACE 1.5 XL** (`acestep_v1.5_xl_base_bf16 7.2G`, `acestep_v1.5_turbo` variant, `DualCLIP qwen_0.6b+qwen_4b`, `ace_1.5_vae`):

* `TextEncodeAceStepAudio1.5 94` `tags, lyrics=[instrumental], bpm 72, duration 120, keyscale E minor, timesignature 4`, `EmptyAceStep1.5LatentAudio 98 seconds`, `KSampler 3 euler 50 cfg6`, `VAEDecodeAudio 18` -> `SaveAudioMP3`. Params: `tags` = prompt, `duration` = seconds, `bpm` controls tempo, `keyscale` harmonic.
* Duration 30-300s, excels 60-180s with bpm/key control. Use when user wants specific tempo/key.

**Choice:** SA3 = cinematic/ambient/detailed reprompt, shorter; ACE = bpm/key precise, longer, slower.

## Helper Script

`scripts/generate_instrumental.py` wraps MCP-equivalent REST to ComfyUI (for agents without MCP client) but prefer `comfy-mcp` in skill:

```bash
# SA3 60s via helper (still uses ComfyUI HTTP 8188, sequential)
python ~/.config/opencode/skills/generate-instrumental/scripts/generate_instrumental.py --prompt "ambient mystical strings, harp, calm, 72 bpm" --duration 60 --engine sa3 --out ./renders/bgm.mp3
# ACE 120s with bpm/key
python ~/.config/opencode/skills/generate-instrumental/scripts/generate_instrumental.py --prompt "slow harmonic heavenly peaceful long strings, harp, evening, no beat" --duration 120 --engine ace --bpm 72 --key "E minor" --out ./renders/bgm_ace.mp3
# dry-run preview
python ~/.config/opencode/skills/generate-instrumental/scripts/generate_instrumental.py --prompt "test" --duration 30 --engine sa3 --dry-run
```

Args: `--prompt` (required), `--duration 10-300` (default 60), `--engine {sa3,ace}` (default sa3), `--bpm 40-180`, `--key "C major"`, `--seed`, `--out` (default `./renders/bgm_<engine>_<duration>s.mp3`), `--out-dir`, `--no-reprompt` (SA3 only)

## Agent Loop (comfy-mcp)

1. `server_info` (VRAM >=24GB good; `stable_audio_3_medium 8.6G` loads ~8GB, 5090 32GB ok). If `vram_free <10GB` -> `free_memory` + re-check.
2. Resolve workflow: `sa3` -> copy `templates/sa3_medium_api_base.json` to `/tmp/bgm_sa3_<id>.json`, edit `52:31.value=prompt`, `52:36` via `52:41 values.a` = duration (also `52:11`). `ace` -> copy `templates/ace_1.5_xl_api_base.json`, edit `94.tags=prompt`, `94.duration=duration`, `98.seconds=duration`, `94.bpm=...`, `109 seed`.
3. `validate_workflow(workflow_path=/tmp/...)` must pass.
4. `run_workflow(workflow_path=/tmp/..., wait=False)` -> `prompt_id`, `job(action=wait, prompt_id, timeout_seconds=600)` (audio 60s ~40s gen, 120s ~90s). Poll.
5. `fetch_outputs(prompt_id, out_dir=./renders)` -> `audio/stable_audio_3_*.mp3` or `ace_*.mp3`. Move to `--out`.
6. Verify `ffprobe -show_entries stream=duration,codec_name` + `ls -lh`.

Never parallelize: one `run_workflow` at a time (audio 300 priority but queue single). Always sequential.

## Manual MCP (if not using helper)

```json
// SA3: run_workflow with /tmp/bgm_sa3.json containing:
{"52:31": {"inputs": {"value": "cinematic ambient... BPM:72 Length:60 seconds"}}, "52:36": {"inputs": {"value": 60}}}
```
```json
// ACE: /tmp/bgm_ace.json:
{"94": {"inputs": {"tags": "slow harmonic ...", "bpm": 72, "duration": 60, "keyscale": "E minor"}}, "98": {"inputs": {"seconds": 60}}}
```

Use `default.write` to create `/tmp/*.json`, `default.bash` only for `ffprobe`/`ls`.

## Telos Extension

Local skill `telos-instrumental` (`.opencode/skills/telos-instrumental/SKILL.md`) extends this global: reads `AGENTS.md Script File Contract` hook, builds telos-specific prompt per project (`The Witches of Thessaly` -> `mystical violet moon cocoon 72bpm`), duration = voice `assets/audio/slug.wav` `ffprobe duration` +5s or fixed 60/120s, saves to `projects/NN_slug/assets/audio/bgm.mp3` (tracked, sibling to voice). See telos-instrumental for per-project batch + ducking.

## Notes

* SA3 reprompt is LLM rewrite — keep prompt concise, let `TextGenerate` expand. Set `--no-reprompt` to use raw prompt.
* ACE `lyrics` must stay `[instrumental]` — never inject vocals.
* Output is `mp3 V0` from `SaveAudioMP3`; for `wav` use `SaveAudio` variant (not in base, convert via `ffmpeg -i bgm.mp3 bgm.wav` or helper `--to wav`).
* VRAM: `system_stats` vram_free check before long 180s+; call `free_memory` if needed.
