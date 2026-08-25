---
name: generate-comfy-image
description: Generate images via local ComfyUI Z-Image Turbo with dynamic LoraLoader chain (0-N loras, 0.1-1.9), favorite loras, 720p default + 480p/1080p/2k/4k. Use when user wants comfy image, zimage, thumbnail, lora blend, or youtube thumb.
---

# generate-comfy-image Skill

Z-Image Turbo via `comfy-mcp` ONLY — local. Requires `server_info` first, `validate_workflow` preflight, `run_workflow`+`fetch_outputs`. No cloud, no bash/fs reads of ComfyUI workspace.

## MCP-Only Rule (MANDATORY)

All ComfyUI work via `comfy-mcp` tools only. No exceptions for image generation:

* Allowed: `server_info`, `search_models(folder=loras)`, `search_templates`/`fetch_template`/`get_template`, `nodes(action=get)`, `validate_workflow`, `run_workflow`, `job(action=status|wait|queue)`, `fetch_outputs`, `system_stats`/`free_memory`
* FORBIDDEN for generation: `bash` (cat/find/ls/python), `filesystem_read_text_file`/`filesystem_list` on `/run/media/dennis/ai/comfy-ui/**`, direct read of `src/comfyui/api/*.json`. That path is outside allowed FS and fails — use MCP instead.
* Workflow JSONs: NEVER in cwd. Use `/tmp/` only: `/tmp/zimage_<seed>.json` or `/tmp/zimage_batch_<id>.json`. Skill `templates/` (`~/.config/opencode/skills/generate-comfy-image/templates/`) is the only persistent source — clone from there into `/tmp/` per run.
* Images: ALWAYS in current project `./renders/` (e.g. `/home/dennis/work/telos/renders` or invocation cwd). Create via `fetch_outputs(prompt_id, out_dir="./renders")`. No json in renders.
* Use `default.write`/`default.edit` to create workflow JSONs in `/tmp/` — not cwd, not bash heredocs.

If a file is outside allowed dirs, fetch it via MCP or use the bundled `templates/` — never try to `cat` it.

## Workflow Basis

Bundled API base: `templates/z_image_turbo_api_base.json` (flat API-format, no subgraph — validated 2026-08-24). Proven nodes:

* `UNETLoader 28` (`z_image_turbo_bf16.safetensors`), `CLIPLoader 30` (`qwen_3_4b.safetensors` lumina2), `VAELoader 29` (`ae.safetensors`), `EmptySD3LatentImage 13`, `CLIPTextEncode 27`, `ConditioningZeroOut 33`, `ModelSamplingAuraFlow 11` (shift 3), `KSampler 3` (steps 8 cfg 1 `res_multistep` `simple` denoise 1), `VAEDecode 8` → `SaveImage 9`
* Gallery alternative: `fetch_template(name="image_z_image_turbo", out_path="/tmp/gallery_z_image.json")` gives frontend `subgraphs` format — also valid but harder to inject loras. Prefer API base for lora chaining. If gallery used, write to `/tmp/` as well.

Lora insertion uses `LoraLoader` (Model+CLIP) — NOT `LoraLoaderModelOnly` (model-only, wrong for this workflow). Verify via `nodes(action=get, name=LoraLoader)` — inputs `model`/`clip`/`lora_name`/`strength_model`/`strength_clip`, outputs `MODEL`+`CLIP`.

Stored templates in this skill:
* `templates/z_image_turbo_api_base.json` — 0-lora base (copy+edit)
* `templates/z_image_turbo_lora_2_example.json` — 2-lora chain `the_narrator_v1_000003000 1.0 → luna_art_v2_000003000 0.75` (validated)
* Chain snippet: `28→51→52→27/11` — see Lora Chaining Rules.

## Favorite Loras Registry (prefer these)

| Key | Filename | Trigger | Typical phrasing / usage | Note |
|-----|----------|---------|--------------------------|------|
| `pencil` | `Zimage_pencil_sketch.safetensors` | `pencil sketch` | `pencil sketch, paper sketch` | Core pencil sketch, default 0.7 in base |
| `pixel` | `pixel_art_style_z_image_turbo.safetensors` | `pixel art` | `pixel art, digital art, layered art` | Pixel art |
| `classic` | `Classic_Painting_Z_Image_Turbo_v1_renderartist_1750.safetensors` | `classic painting` | `classic painting, layered art` | Classic painting |
| `coloring` | `Coloring_Book_Z_Image_Turbo_v1_renderartist_2000.safetensors` | `coloring book` | `coloring book, paper sketch` | Coloring book |
| `narrator_base` | `the_narrator_v0.safetensors` | `the_narrator` | Default when narrator used: add `a man` AFTER triggers (only if narrator lora active and user gave no specific appearance — no extra hair/eye details by default) | Primary narrator v0 base — user favorite |
| `narrator_v1_3000` | `the_narrator_v1_000003000.safetensors` | `the_narrator` | Same, v1 3000 — maps to user "narrator 1.0" | Narrator v1 1.0 |
| `narrator_2750`..`3750` | `the_narrator_v0_000002750.safetensors` .. `the_narrator_v0_000003750.safetensors`, `the_narrator_v1_000003250.safetensors` etc | `the_narrator` | Same as above, steps 2750-3750 | Narrator steps |
| `void_v1` | `void_vision_v1.safetensors` | `void_vision` | Prefix `void_vision, ...` + world suffix | Void base |
| `void_v4` | `void_vision_v4_000003250.safetensors` | `void_vision` | Prefix `void_vision, ...` + world suffix | Favorite void v4 |
| `void_v3` | `void_vision_v3.safetensors` | `void_vision` | Prefix `void_vision, ...` + world suffix | Void v3 |
| `luna_base` | `luna_art_lora.safetensors` | `luna_art` | Prefix `luna_art, ...` + world suffix | Luna base |
| `luna_v2_3000` | `luna_art_v2_000003000.safetensors` | `luna_art` | Prefix `luna_art, ...` + world suffix | Luna v2 3000 — correct, v3 does not exist |
| `luna_v2`.. | `luna_art_v2.safetensors` + `luna_art_v2_000002000`..`000003750` | `luna_art` | Same | Luna v2 steps |
| `anime_like` | `illustration-1.0-qwen-image.safetensors` | `illustration` | `illustration, digital art` | Anime/illustration (closest to anime tag) |

Full 63 list via `search_models(folder=loras)` — 4 void, 9 narrator, 10 luna, 6 turbo styles. Avoid non-ZImage loras (`wan2.2_*`, `ltx2.3*`) for this workflow.

**Trigger keywords are mandatory — prepend FIRST to prompt (comma-separated) before any other text, in lora chain order.** E.g. chain `narrator_v1_3000 + luna_v2_3000` → prompt starts `the_narrator, luna_art, a man, ...`.

**Person rule (MANDATORY):** If `the_narrator` NOT in chain, prompt must contain `no person, no human, no face, no body` and must NOT contain `a man` or portrait framing. Use abstract landscape (e.g. `pixel art, abstract pixel art landscape`, `luna_art, shiny holographic glow fractal labyrinth`, `void_vision, dark void abstract landscape`, `abstract surreal landscape` for nolora). When `the_narrator` present, append `a man` AFTER triggers and add portrait framing `extreme close-up portrait of a man on right side, left side empty clean area`.

**Holographic world suffix** — for these 3 custom loras (and usually pencil/pixel/classic), typical prompt tail is layered world description. Use as *background guidance*, not forced every time, but agent should know style:
```
shiny holographic glow drawn sketch in a dark parallel digital glass like world many layers, deep, surreal, abstract, translucent, multiple dimension, fractal, deep, caleidoscope, layered, optical illusion, labyrinth, first person perspective, wide horizon, recursive, mandelbrot like, never ending, portals, optical illusion, peaceful, patterns, mandala, nature like, organic, trees
```
plus variants: `paper sketch, pencil sketch, digital art, layered art` (short forms). Agent should blend: trigger prefix + user subject + optional suffix fragments, not overwrite user intent verbatim. For `the_narrator`, default descriptive is `a man` added AFTER triggers only when narrator lora is used and user provided no custom appearance; no extra details injected by default. **When narrator absent, never add person descriptive — use no-person abstract instead.**

## Resolutions

Default `720p` = `1280x720` `batch_size 1`. Map:
* `480p` `640x480`
* `720p` `1280x720` (default)
* `1080p` `1920x1080`
* `2k` `2560x1440`
* `4k` `3840x2160`
* `720p_vertical` `720x1280` if user says portrait/9_16
* Freeform `width x height` (64-8192 clamp). Pin `batch_size 1` per run; multi-variant = loop runs.

## Lora Chaining Rules

* `N=0` → base `templates/z_image_turbo_api_base.json` as-is: `27.clip ["30",0]`, `11.model ["28",0]`
* `N=1` → single `LoraLoader 51` `lora_name` + `strength_model=strength_clip=weight` wiring `28/30 → 51 → 27/11`
* `N>=2` → chain `51→52→53…` serial `model/clip`:
  ```
  28 model + 30 clip → 51 model/clip → 52 model/clip → 53 → CLIP[52,1]→27 + MODEL[52,0]→11
  ```
  Set `strength_model=strength_clip=weight` per node (0.1 - 1.9). When chaining, lower weights to avoid bleeding: e.g. `1.0` solo → `0.7/0.5/0.35` for 3. Suggest `0.6-0.8` for 2, `0.4-0.6` for 3, never sum >1.8 total.
* Use `LoraLoader` (Model and CLIP) — not `LoraLoaderModelOnly`. Verified via `nodes(get=LoraLoader)`.
* Prefer canonical filename with `.safetensors` suffix.
* Weights outside 0.1-1.9 warn but allow.
* Composition: triggers in chain order must match node order. Example validated: `51 the_narrator_v1_000003000 1.0 → 52 luna_art_v2_000003000 0.75` with prompt prefix `the_narrator, luna_art, a man, ...` — this ordering is what `templates/z_image_turbo_lora_2_example.json` demonstrates.

## Agent Workflow

### 1. server_info
Call `server_info` first, check `server.running true`, `hardware.gpu.vram_bytes >= 8GB` for ZImage. Snapshot at startup already shows RTX 5090 32GB — still call to verify live.

### 2. Resolve loras
Call `search_models(folder=loras)` to verify filenames exist if unsure. Map user short names via registry above. Confirm via `nodes(action=get, name=LoraLoader)` if wiring doubt.

### 3. Build API JSON — NO CWD SPAM
Clone `templates/z_image_turbo_api_base.json` → edit → write to `/tmp/` ONLY:

* `13.width/height` per resolution, `13.batch_size 1`
* `27.text` = **constructed prompt**: `trigger_prefix + person_phrase + user_prompt` (+ `optional_suffix` ONLY if user explicitly requests world/style)
  * `trigger_prefix` = comma-join triggers in chain order, e.g. `the_narrator, luna_art` (or `pencil sketch,` etc).
  * `person_phrase` = `a man` + portrait framing `extreme close-up portrait of a man on right side, left side empty clean area for typography` ONLY when `the_narrator` in chain (user can override appearance). When `the_narrator` NOT in chain, person_phrase = `no person, no human, no face, no body, empty scene, abstract landscape` — never add `a man`.
  * `optional_suffix` = holographic world fragments ONLY on explicit request (user says `holographic`/`glass world`/`mandala`/`labyrinth` or asks for that style). Never auto-append. When not requested, suffix = empty. When requested, use short fragment `, shiny holographic glow ...` etc limited to 2-4 keywords, not full paragraph.
* `3.seed` = random or user seed, `11.model` = last lora `MODEL` or `["28",0]` if 0 loras, `27.clip` = last lora `CLIP` or `["30",1]`
* Insert N `LoraLoader` nodes `51+` with filenames + weights (see templates/z_image_turbo_lora_2_example.json)
* `9.filename_prefix` = requested or `thumb_<id>` for thumbnails
* For `N>=1`, rewire: `51.model ["28",0]`, `51.clip ["30",0]`; `52.model ["51",0]`, `52.clip ["51",1]`; then `27.clip ["52",1]`, `11.model ["52",0]` (extend for 53...)

Write to: `/tmp/zimage_<seed>.json` (single) or `/tmp/zimage_batch_<seed>.json` per variant (batch). NEVER write to cwd (`./z_batch_*.json` or `./z_narrator*.json`). Cwd stays clean — only `./renders/*.png` appears there.

**Image save location:** `fetch_outputs(prompt_id, out_dir="./renders")` where `./renders` is the current project cwd (e.g. `/home/dennis/work/telos/renders` or invocation dir). Create dir via `filesystem_create_directory` if missing. Workflow JSON stays in `/tmp/`, image copy lands in `./renders/`.

Prompt assembly example (2 loras, current directory renders):
```
the_narrator, luna_art, a man, extreme close-up portrait of a man on right side, left side empty clean area for typography, a lone figure at a glass horizon at night
→ workflow /tmp/zimage_1001.json → fetch to ./renders/<prompt_id>_000.png
```
No-person example (no narrator):
```
pixel art, abstract pixel art landscape, layered digital art, no person, no human, no face, no body, empty scene, left side empty clean area for typography, no text
→ workflow /tmp/zimage_1001.json → fetch to ./renders/<prompt_id>_000.png
```

### 4. validate_workflow
`validate_workflow(workflow_path=/tmp/zimage_*.json)` → if invalid (missing lora file, node typo, wrong LoraLoader) fix before run. Path must be `/tmp/` file.

### 5. Run + fetch — batch + loop safe

Single: `run_workflow(workflow_path=/tmp/zimage_42.json, wait=True)` → `fetch_outputs(prompt_id, out_dir="./renders")`

Batch `variants=N` (loop-safe):
* Create DISTINCT `/tmp/` files per variant (`/tmp/zimage_batch_1001.json` ... `/tmp/zimage_batch_1020.json`, 1 file per seed) — never overwrite same file while queue drains (queued job reads file at execution time). Each file has `3.seed` varied, same loras.
* Submit via `run_workflow(wait=False)` sequentially, collect `prompt_id`s, then poll via `job(action=status|wait)` or `fetch_outputs` per id.
* `fetch_outputs(prompt_id, out_dir="./renders")` — out_dir is always current directory `./renders`; never `/tmp/`.
* Cleanup (optional): after fetch, workflow `/tmp/` files can be left for debugging or removed — they are in `/tmp/` so they never spam cwd/renders.

Loop mode: this workflow is loop-safe — `/tmp/` files are unique per iteration, `server_info` re-checked each loop, `validate_workflow` before each `run_workflow`, and `fetch_outputs` always targets `./renders` of the loop's cwd. Safe to run via `/loop generate 20 thumbs with narrator+luna` — each iteration creates new `/tmp/zimage_<iter>.json`, validates, runs, fetches, no cwd accumulation.

Example batch 20 (current dir renders, no cwd spam):
```
prompt "the_narrator, luna_art, a man, close up portrait ... Transhumanismus ..." 
loras [{"name":"the_narrator_v1_000003000","weight":1.0},{"name":"luna_art_v2_000003000","weight":0.75}]
resolution 1280x720 steps 8 cfg 1
→ clone templates/z_image_turbo_api_base.json → 20× write /tmp/zimage_batch_1001..1020.json (seed varied, LoraLoader chain 51→52) → validate one → 20× run_workflow(wait=False) → 20× fetch_outputs to ./renders
→ first result 10.5s on RTX 5090, ~2-3s per queued job, cwd contains only renders/*.png
```

### 6. Confirm
Return `out_dir` file, resolution, loras+weights used. Poll `job(action=queue)` to monitor remaining. Verify cwd: `read` on `./renders` shows only `*.png`, no `*.json`.

## Loop Support & Exact-Count Guarantee

**Exact-count guarantee (not fuzzy):** When told to generate `N` images, this skill generates **exactly N** distinct files (`/tmp/zimage_batch_<seed>.json` per variant, `batch_size 1` each, N files, N `run_workflow(wait=False)` calls, N `fetch_outputs`). Never "about N", never batch_size >1 shortcut. If queue drops one, retry that seed file — still N on disk.

**Thumbnail compatibility:** `generate-thumbnail` may ask for `R = 5-20` RAW candidates to pick best `F=3` finals. It calls this skill with `N=R` exactly. This skill fulfills exactly `R`, thumbnail does adversarial picking (top F). No fuzzy inflation inside this skill — fuzzy over-generation lives only in thumbnail wrapper.

* Idempotent: each loop iteration writes a new `/tmp/zimage_<seed>.json` (unique seed/timestamp), validates, runs, fetches to `./renders`. No state carries between iterations that would pollute cwd.
* Composable: call with different seeds/prompts per loop iteration; lora chain re-built from `templates/` each time, so weight/order changes are safe.
* Resume: if loop interrupted, `job(action=queue)` lists pending prompt_ids; `fetch_outputs` can be re-run for those ids — images still fetch to `./renders`.
* Caps: `generate-thumbnail` caps RAW at 20 and visual-diff text loops at 10 rounds per final (text-only overlays, no new diffusion). This skill has no text loop cap — its cap is the `N` you asked for.
* Usage: `/loop generate 20 narrator+luna thumbs in ./renders --max-iterations 20` or `/loop --compact-every 5` — skill handles `/tmp` hygiene, loop handles iteration.

## Example Invocations

**Solo pencil 720p:**
```
prompt "cinematic youtube thumbnail shocked face neon border" loras [{"name":"Zimage_pencil_sketch","weight":0.7}] resolution 720p
→ LoraLoader 51 in /tmp/zimage_1234.json → fetch to ./renders
```

**2-lora chain 1.0/0.75 720p (no cwd spam):**
```
prompt "narrator luna blend cinematic" loras [
  {"name":"the_narrator_v1_000003000","weight":1.0},
  {"name":"luna_art_v2_000003000","weight":0.75}
] resolution 720p
→ chain 51 1.0 → 52 0.75 in /tmp/zimage_batch_*.json → fetch to ./renders
→ final CLIP text: "the_narrator, luna_art, a man, narrator luna blend cinematic" (suffix only if requested)
```

**No lora 1080p:**
```
prompt "high contrast thumbnail bold text area" loras [] resolution 1080p
→ use templates/z_image_turbo_api_base.json → /tmp/zimage_*.json → ./renders
```

**Loop 20 thumbs:**
```
/loop generate 20 thumbs prompt="Transhumanismus ..." loras [narrator 1.0, luna 0.75] to ./renders
→ each iteration: /tmp/zimage_loop_<n>.json → validate → run → fetch → ./renders/<id>.png
```

## Anti-patterns
* Do not use `run_template` for this — use `run_workflow` with custom chain.
* Do not use `LoraLoaderModelOnly` — use `LoraLoader` (Model and CLIP).
* Do not `cat`/`find` ComfyUI workspace — use `fetch_template` or `templates/` bundle.
* Do not write workflow JSONs to cwd or renders — use `/tmp/` only. Previous run spammed `./z_batch_*.json` + `./z_narrator*.json` in cwd — fixed to `/tmp/`.
* Do not use `apply_slots` to add loras — cannot create nodes.
* Do not set `batch_size >1` for multi-variant — loop distinct `/tmp/` files/runs.
* Do not chain wan/ltx loras on ZImage.
* Do not include `%` or numeric percentages in prompt for layout — use `right side`/`left side` word form; `%` hallucinates as text (e.g. `50%`) despite `no text`.
* Do not overwrite same workflow JSON while jobs queued — use distinct `/tmp/` files per seed.

## Templates in this skill
* `templates/z_image_turbo_api_base.json` — flat API base, 0 loras, 1280x720, steps 8. Clone to `/tmp/` for all runs.
* `templates/z_image_turbo_lora_2_example.json` — same base with `the_narrator_v1_000003000 1.0 → luna_art_v2_000003000 0.75` chain (proven 2026-08-24 for Transhumanismus thumb). Copy to `/tmp/` and vary seed.
* Future: add `templates/z_image_turbo_frontend_subgraph.json` if subgraph preference needed (from `fetch_template image_z_image_turbo` → save to `/tmp/` then move to templates).
