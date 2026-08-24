---
name: generate-thumbnail
description: Generate high-contrast YouTube thumbnails of the narrator (young man wearing glasses) via generate-comfy-image. Uses narrator + style loras (void vision, luna art, pixel art, pencil, classic), composes loras correctly, adds vector text overlay post-diffusion, and loops with image critique until 3 good thumbnails exist. Use when user wants thumbnail, youtube thumb, narrator thumb, or "myself + style".
---

# generate-thumbnail Skill

Wrapper over `generate-comfy-image` for YouTube thumbnails. Fixes two failures seen in 2026-08-24 batch: 1) text fractured when generated in diffusion (`Trans-/humiai`), 2) cwd spam with `z_batch_*.json`. Always generates **text-free** in diffusion, adds text as vector overlay, writes workflows to `/tmp`, images to current dir `./renders` (or `./thumbnails`), and loops with visual critique until 3 good thumbs.

## When to use

* User says `thumbnail`, `youtube thumb`, `thumb of myself/narrator`, `narrator + <style>` (void vision, luna art, pixel art, pencil, classic, coloring, anime), or any style from `generate-comfy-image` registry.
* Map: `myself`/`me`/`narrator` → `the_narrator` (always add `the young man wearing glasses` AFTER triggers). Styles: `void`→`void_vision`, `luna`→`luna_art`, `pixel`→`pixel art`, `pencil`→`pencil sketch`, `classic`→`classic painting`, etc. If unknown style, `search_models(folder=loras)` then map.

## Depends on

* `generate-comfy-image` — for Z-Image Turbo, LoraLoader chaining, resolutions, trigger prefixes. Follow its MCP-Only Rule: `server_info`, `search_models`, `nodes`, `validate_workflow`, `run_workflow`, `job`, `fetch_outputs`. No bash/fs on `/run/media`.
* This skill adds: thumbnail composition, text overlay, critique loop.

## Thumbnail Spec (enforced)

* Layout: 16:9 `1280x720` (default thumb) — subject on **right 50%**, **left 40% negative space** clean for text (no clutter, no generated text). `batch_size 1`.
* Framing: extreme close-up portrait, face + small upper chest only, eye-level, sharp focus on face, no full body, no second person, no drawing/sketch artifact.
* Narrator: `the_narrator` + `the young man wearing glasses` (triggers first, description after) — brown hair, glasses. Eyes normal by default. **Optional eye effect** only if user explicitly requests `terminator`/`cybernetic`/`red eye`: then `subject's right eye (screen-left, viewer's left side of his face) glowing bright red Terminator cybernetic (circular, emissive), left eye normal dark` — and must be correct side. Do NOT add red eye unless requested.
* Background: clean/neutral by default. Holographic world suffix `shiny holographic glow ... fractal labyrinth portal mandala` ONLY if user explicitly requests `luna/holographic/glass world` style. Otherwise use simple `neutral background` or keep empty. Do not pollute empty prompt with mandala filler.
* Text: **NOT in diffusion**. Prompt contains `left side empty clean area for typography, no text, no watermark, no letters`. Text added post as vector overlay on left.
* Style intensity via lora weights (see Experiment).

## Lora Composition (delegates to generate-comfy-image)

* Use `templates/z_image_turbo_api_base.json` (flat API) cloned to `/tmp/zthumb_<seed>.json`.
* Chain `LoraLoader` (Model+CLIP) not `ModelOnly`. Order = trigger order = node order.
  * 0 loras: no LoraLoader, `27.clip ["30",0]`, `11.model ["28",0]`
  * 1 lora: `51` with `strength_model=strength_clip=weight`
  * 2 loras: `51→52` (e.g. narrator 1.0 → luna 0.75), `27.clip ["52",1]`, `11.model ["52",0]`
  * 3 loras: `51→52→53` — lower weights to avoid bleed (e.g. 1.0→0.7→0.4, sum <1.8)
* Triggers: always prepend in chain order, e.g. `the_narrator, luna_art` then descriptive `the young man wearing glasses` AFTER triggers. Example 2-lora: `the_narrator, luna_art, the young man wearing glasses, <thumb prompt>` → nodes 51 luna? No, order matters — ensure chain and prefix match.

## Text Overlay (post-diffusion, mandatory)

Diffusion never renders `Transhumanismus` fractured again. Steps:

* Generate text-free image to `./renders/thumb_raw_<id>.png` via `fetch_outputs(prompt_id, out_dir="./renders")`
* Overlay vector text on left 40%: use `hyperframes` HTML or `PIL`/`ffmpeg`. Preferences:
  * Style: very large, contrast-rich, bold print, `Transhumanismus` left-aligned, hyphen optional, black or white with subtle drop shadow for contrast depending on background luminance (sample left area). Font size ~1/3 height.
  * Position: left `x=5%` `y=15%` stacked, `line-height 0.9`, keep subject face unobstructed.
  * Save final as `./renders/thumb_final_<id>.png` or `./thumbnails/thumb_final_<id>.png` in current dir. Keep raw for comparison.
* If user explicitly wants no text, skip overlay.

Do not generate text in diffusion even if user says "text Transhumanismus" — treat as overlay instruction.

## Loop: Generate → Adversarial Critique → Visual-Diff Validation until 3 Good (capped)

This skill **loops adversarially** — generate more than requested, pick best, then validate text against references. Capped to prevent runaway.

**Rule: User says "3 thumbnails" → skill may generate 5-20 RAW, pick best 3, then apply text + validate. User always gets exactly 3 finals, but internally we over-generate adversarially.**

**Caps:**
- **RAW generation:** may generate 5-20 to pick 3 best (not fuzzy — thumbnail skill's "3" means 3 finals, but 5-20 RAW candidates). `generate-comfy-image` when told `N` still generates exactly `N` (exact, not fuzzy) — thumbnail wraps it with over-generation.
- **Validation loop:** max **10 rounds per final image** (per picked RAW → overlay → visual-diff). If still not `good` after 10, return best attempt with warning, don't infinite loop.
- **Total images per request:** hardest case 3 finals × 10 rounds × 2-3 text variants = up to ~30 overlay attempts, but RAW diffusion capped at 20.

### 1. Generate RAW batch (via generate-comfy-image — exact)

* `server_info` → check `running` + `VRAM >=8GB`
* `search_models(folder=loras)` verify filenames.
* Decide over-generate count: requested finals `F=3` → generate `R = min(max(F*3, 5), 20)` RAW candidates (e.g. 9 RAW for 3 finals). If user says `F=1` → 5 RAW, `F=3` → 9 RAW, `F=5` → 15 RAW.
* Build `/tmp/zthumb_batch_<seed>.json` per variant distinct file. `13: 1280x720`, `3.seed` varied, `9.filename_prefix="thumb-raw"`.
* `validate_workflow` once, then `run_workflow(wait=False)` for `R` variants **exactly** (generate-comfy-image guarantees exact count — not fuzzy, not "about 9" but 9). Collect `prompt_id`s, `fetch_outputs` to `./renders`.
* **Compatibility note:** `generate-comfy-image` when told `N` always generates exactly `N` (single `batch_size 1` per distinct file, N files). Thumbnail skill wraps this with `R = ceil(F*3)` to allow picking.

### 2. Adversarial RAW Critique (batch_critique vs references)

Run `scripts/batch_critique.py --dir renders` adversarially — strict:

* [ ] Subject on right 50%, left 40% clean (edge_density ratio)
* [ ] Extreme close-up, sharp focus `blur >80`
* [ ] Background clean left vs right, no watermark/letters
* Score `good / near-miss / bad` with reason. **Rank all R candidates by (good > near-miss > bad, then blur desc, left/right ratio asc). Pick top F (3) best.** If <F good, still pick best near-miss — adversarial: we generate more to avoid bad.

Example: `F=3, R=9` → scores 2 good, 4 near-miss, 3 bad → pick 2 good + best near-miss (ratio 0.84).

### 3. Overlay Text (per picked RAW, style-driven)

For each picked RAW (3), run `scripts/overlay_helper.py --input raw.png --output final.png --lines ... --style <style>`:
- Style drives font `Anton 900`, duplicate shadow `4px` (not halo), scale `1.35`, gold block / per-word orange/heavenly etc (from `styles/reference_styles.json` v2, no outer border).

### 4. Adversarial Visual-Diff Validation (max 10 rounds per final)

Run `scripts/batch_critique.py --final final.png --style <style>`:
- `FAIL outer border` (top 8px solid gold/marine) → recreate overlay with `--border none` (already default)
- `FAIL pink #E85D7A` → switch to gold
- `WARN ben gold block low` → increase `highlight_last` width or retry same RAW with larger block
- `WARN per-word color missing` → retry with `--per-word` adjusted
- **Adversarial loop:** For each final, up to **10 rounds**: `overlay → visual-diff → fix params → re-overlay` (no new diffusion, just text). If still `near-miss` after 10, keep best and warn. If `bad` after 10, discard that RAW pick and try next best RAW candidate (from the 9) with fresh 10-round loop — worst case 20 RAW ensures fallback.

### 5. Loop until F good finals or caps hit

- RAW generation is one shot `R = 5-20` (not looped). Visual-diff loop is per final, capped 10.
- If after 10 rounds a final still `bad`, pick next RAW candidate (4th best) and run its 10-round loop — up to `R` candidates.
- Stop when `F` finals are `good` on visual-diff, or `R` exhausted. Return `F` finals + raw scores + visual-diff logs + rounds used. If loop via `/loop`, emit `<promise>DONE</promise>` when `F` good.

Example batch `F=3, R=9` seeds 1001-1009 → RAW scores → pick top 3 (1003, 1007, 1001) → overlay each → visual-diff: 1003 good, 1007 near-miss (gold block low) → re-overlay larger block round 2 good, 1001 good → 3 finals in 4 overlay attempts (well under 30 cap).

## Agent Workflow (invocation)

1. Parse user: `narrator + <style>` + optional text (e.g. Transhumanismus) + optional weight hints. Default: `narrator 1.0 + luna 0.75` if no style given, text `Transhumanismus` overlay.
2. `server_info` → `search_models(folder=loras)` → `nodes(get=LoraLoader)` if needed.
3. Generate first batch (4 images) text-free to `./renders` via `/tmp` workflows (see above). Use `validate_workflow` then `run_workflow`+`fetch_outputs`.
4. Read 4 images, score with checklist. If 3 good → overlay text on those 3 and done.
5. Else experiment weights/prompts → next batch of 4 → read → score → repeat until 3 good. Each loop iteration creates new `/tmp` files, no cwd spam.
6. For each good raw, overlay vector text on left (if requested) → save `thumb_final_<id>.png` in `./renders` (or `./thumbnails`). Return final paths + seeds + loras/weights.
7. Confirm: `read` on `./renders` shows only `*.png` (no `*.json`), 3 finals with correct eye side, clean left text area, high contrast.

## Building Blocks (reuses generate-comfy-image)

* `~/.config/opencode/skills/generate-comfy-image/templates/z_image_turbo_api_base.json` — base, clone to `/tmp`
* `~/.config/opencode/skills/generate-comfy-image/templates/z_image_turbo_lora_2_example.json` — 2-lora example (narrator 1.0 → luna 0.75)
* This skill adds overlay step: use `PIL`: `Image.open(raw); draw.text((x,y), "Transhumanismus", font=bold_large, fill=black/white, stroke); save` or `hyperframes` HTML render. Prefer PIL for loop speed.

## Example

User: `generate thumbnail of myself with luna art, text Transhumanismus`

→ resolve `the_narrator_v1_000003000:1.0` + `luna_art_v2_000003000:0.75`, prompt V1 text-free, `/tmp/zthumb_batch_1001..1004.json` → `validate` → `run` → `fetch` to `./renders/thumb_raw_*.png` → read 4, score 1 good (eye correct, clean left) → experiment `weight luna 0.6` + prompt V2 → next batch 4 → read → score 2 more good → overlay `Transhumanismus` large left on 3 goods → `renders/thumb_final_*.png` done.

User: `generate thumbnail with void vision and pixel art`

→ 3-lora chain `narrator 1.0 → void 0.75 → pixel 0.5` triggers `the_narrator, void_vision, pixel art, the young man wearing glasses, ...` (triggers first, then description) → same loop until 3 good.

## Anti-patterns

* Do not generate text in diffusion — always overlay post.
* Do not write workflow JSONs to cwd/renders — use `/tmp` only.
* Do not use `LoraLoaderModelOnly` — use `LoraLoader`.
* Do not reuse same seed/file while queued — distinct `/tmp` file per seed.
* Do not stop after one batch — loop with critique until 3 good.
* Do not ignore eye side when terminator requested — explicitly `subject's right eye (screen-left)`; check each image visually. If no eye effect requested, verify both eyes normal.
* Do not change resolution to fix style — vary weights/prompts instead.

## Reference Material Consolidated (24 thumbs embedded)

All kept inspira after garbage deletion now lives **inside skill**: `references/` (24 JPG) + `references/manifest.json` + `styles/reference_styles.json` v2.

```
references/
  ben/ (6)          ben_9J-oOOLwba4.jpg DAS DENKT ER WIRKLICH! etc — lesson: left 58% top y=8% Anton 900, last line gold block #D4AF37
  peterson/ (3)     pet_BSfHwiR7I24.jpg JUNG'S WARNING — lesson: per-word white/orange
  peterson_clips/ (7) petclip_XOev-o4YPM4.jpg PRETEND YOU LOVE HER 10 MIN etc — bottom plate per-word orange #FF7B2E + heavenly #38BDF8 italic
  chris/ (8)        chris_edbIJ7PpVlc.jpg "BIOLOGY HAS NO LIMITS." — centered quote, heavenly underline
```

`manifest.json` counts, handles, traits, allowed palette `dark/black/gold/yellow/orange/heavenly #2E86AB/marine #0F172A/violet #6D28D9`, forbidden `pink #E85D7A`.

## Reference Style Map v2 (allowed palette only, no outer border)

`styles/reference_styles.json` v2 — all entries inherit `base` (Anton 900, scale 1.35, duplicate shadow 4px not halo stroke, no outer frame per user).

- `ben_dark_gold` — left 58% top y=8% Anton, white fill + black duplicate 4px, gold block #D4AF37 behind last line, brush white under, scale 1.35 line 0.82 (replaces Ben pink #E85D7A). Use: German/telos witches.
- `peterson_heavenly` — bottom y=62% Anton, plate rgba(0,0,0,0.85), per-word orange #FF7B2E / heavenly #38BDF8 italic, white 2px rule, scale 1.25.
- `chris_heavenly` — centered y=30% Anton, heavenly #2E86AB highlight, cyan underline 3px, quote marks, scale 1.25.
- `luna_art` — violet #140028 duplicate 4px, holographic right only.
- `base` — white+black duplicate 4px, NO outer border/frame (user forbids surrounding frame on entire image — style outer_border is "none" everywhere).

Shared core: `Anton 900 condensed, duplicate 4px shadow not halo, 2-3 lines fill 55-70% width, NO border, allowed colors only, readable 168px`.

Add new channel: copy `ben_dark_gold` block in `reference_styles.json`, change 2-3 keys within allowed_palette (gold/marine/violet/...), keep no border.

**Usage (no border):**
```bash
python scripts/overlay_helper.py --input renders/raw.png --output renders/final.png --lines "NO" "SHORTCUT" --style ben_dark_gold --subtitle "THE WITCHES OF THESSALY"
python scripts/overlay_helper.py --input raw.png --output final.png --lines "WHY" "PARADISE WOULD BORE YOU" --style peterson_heavenly --per-word "PARADISE:orange,BORE:orange"
python scripts/overlay_helper.py --input raw.png --output final.png --lines '"BIOLOGY HAS NO' 'LIMITS."' --style chris_heavenly --per-word "LIMITS.:heavenly"
# explicit border only if you really want: --border gold,8 (not default)
```

## Validation Extended (visual-diff vs references)

`scripts/batch_critique.py` v2 now two-phase:

1. **RAW check** (blur, left clean ratio 1.2, right subject) — run on RAW only, finals inflate left edge. Thresholds tuned to v2 refs: `blur 80, left 20, ratio 1.2` → 11/30 good demo.
2. **Visual-diff final vs reference** — when `--final <png> --style <name>` given, checks:
   - No outer border/frame (top 8px solid gold/marine → FAIL per user)
   - No forbidden pink #E85D7A
   - Style lesson: ben gold block ~51% in left mid band, peterson orange/heavenly per-word in bottom 40%, chris heavenly underline 3px
   - Allowed palette only

```bash
python scripts/batch_critique.py --dir renders --final renders/final.png --style ben_dark_gold
python scripts/batch_critique.py --references  # list 24 embedded thumbs + styles
python scripts/batch_critique.py --dir renders --json out.json
```

Loop: Generate → RAW critique → overlay with style → visual-diff final → repeat until `good` on both.

**Fonts bundled:** `fonts/BebasNeue-Regular.ttf` 60K + `Anton-Regular.ttf` 167K + `Montserrat-Variable.ttf` 728K + `Oswald-Variable.ttf` 169K — local dep, no yay, checked via PIL.


