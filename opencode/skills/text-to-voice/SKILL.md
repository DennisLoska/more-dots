---
name: text-to-voice
description: Turn any text/book/script into speech via local Voicebox TTS. Handles huge inputs via sequential sentence-boundary chunking, single-worker loop, and ffmpeg concat to single wav. Use when user wants audiobook, TTS, voice synthesis, telos script -> audio, or "generate voice/audio from text".
---

# Text-to-Voice (Voicebox)

Local TTS via `voicebox` at `http://127.0.0.1:17493` (UI `http://0.0.0.0:5173`). Turns arbitrary text — telos scripts, markdown, entire books — into a single `wav` by chunking and sequential generation. Never parallelize: one chunk at a time, single subagent loop.

## Service Map

* API: `http://127.0.0.1:17493` — REST, OpenAPI docs `http://0.0.0.0:17493/docs` (also `http://127.0.0.1:17493/docs`). Health `GET /health`. All generation `POST /generate` -> poll `GET /generate/{id}/status` (SSE `data:` lines until `completed`/`failed`).
* UI: `http://0.0.0.0:5173`
* Data: `/home/dennis/work/voicebox/data/generations/*.wav` (`audio_path: generations/<id>.wav` from API)
* Docs to reference inside skill: `http://0.0.0.0:17493/docs` + local `~/work/voicebox/README.md`
* MCP (optional): `http://0.0.0.0:17493/mcp` with `X-Voicebox-Client-Id: claude-code` — tools `voicebox.speak`, `voicebox.list_profiles`, `voicebox.transcribe`. MCP needs binding `PUT /mcp/bindings {client_id, profile_id}` to resolve default voice. REST preferred for skills because it needs no binding and works without MCP client config.

## Why REST Not MCP Here

You *can* say "use Voicebox MCP `voicebox.speak`" if user has `mcpServers.voicebox` configured (see user config). But MCP adds per-client binding indirection and still returns async `id` to poll. For a reliable global skill, bake REST directly: `POST /generate {profile_id, text, language}` is explicit, needs no binding, and works everywhere Voicebox runs. Mention MCP as alternative: if MCP configured, you may call `voicebox.speak(profile, text)` then poll via REST anyway.

## Voice Profiles (GET /profiles)

Resolve name->id via `GET http://127.0.0.1:17493/profiles`. Common:

| name | lang | use |
|------|------|-----|
| `the_narrator_en` | en | default English audiobook |
| `the_narrator_de` | de | German narration |
| `luna_darko` | de | female German |
| `david_goggins` | en | `david_goggins` persona |
| `_preset_af_bella` etc | en | Kokoro presets (no clone) |

For telos scripts: default `the_narrator_en` unless script header says `de` -> switch to `the_narrator_de`. Check `projects/NN_*/<slug>.md` language.

## Chunking Rule (MANDATORY for books)

* Voicebox `GenerationRequest.text` max `50000`, but quality degrades >800. Default `max_chunk_chars=700` (range 100-5000).
* Skill must split huge text at sentence/paragraph boundaries, never hard cut mid-sentence except for >700-char sentences (then word-boundary).
* Sequential only: one `POST /generate` + poll at a time. No parallel subagents, no `Promise.all`, no concurrent `run`. Voicebox queue is single-slot, VRAM shared — parallel causes OOM and nondeterministic concat order.
* Use helper `~/.config/opencode/skills/text-to-voice/scripts/voicebox_tts.py` which already implements this loop + ffmpeg concat.

## Output Rule

* Save in invocation `cwd` by default, or user-specified `--out` / `--out-dir`.
* Telos convention: `projects/NN_slug/assets/audio/<slug>.wav` or `<slug>.mp3` if user wants. Skill respects `--out-dir` / `--out`.
* Final is single `wav` (ffmpeg concat demuxer `-c copy`, fallback re-encode). Keep wavs in `.tts_chunks_<stem>/` only if `--keep-chunks`.

## Helper Script

`scripts/voicebox_tts.py` — all logic baked, single entry:

```bash
# book -> audiobook (cwd = where you invoked skill)
python ~/.config/opencode/skills/text-to-voice/scripts/voicebox_tts.py --input ~/work/books/library/alice_in_wonderland.txt --out ./alice.wav --voice the_narrator_en
python ~/.config/opencode/skills/text-to-voice/scripts/voicebox_tts.py --input projects/01_the_witches_of_thessaly/the_witches_of_thessaly.md --out projects/01_the_witches_of_thessaly/assets/audio/the_witches_of_thessaly.wav --voice the_narrator_en
echo "Hello world" | python ~/.config/opencode/skills/text-to-voice/scripts/voicebox_tts.py --stdin --out ./hello.wav --voice the_narrator_de --lang de
# dry-run to preview chunking for huge inputs
python ~/.config/opencode/skills/text-to-voice/scripts/voicebox_tts.py --input ~/work/books/library/crime_and_punishment.txt --dry-run --max-chunk 700
# keep chunks for debugging
python ~/.config/opencode/skills/text-to-voice/scripts/voicebox_tts.py --input input.txt --keep-chunks
```

Exit codes: 0 ok, non-zero fail (profile not found, health unreachable, ffmpeg missing).

## Agent Loop (single subagent)

When invoked for a book or long text:

1. Resolve profile: `curl -s http://127.0.0.1:17493/profiles | jq` -> map name to id. Default `the_narrator_en` / `the_narrator_de` via profile language.
2. Validate input length / health: `curl -s http://127.0.0.1:17493/health`
3. Dry-run preview: run `voicebox_tts.py --dry-run` to log chunk count for user (e.g. `154k chars -> 193 chunks` needs ~20-40min).
4. Spawn **one** subagent to run `voicebox_tts.py` sequentially (do not fan out). Stream progress `[{i}/{n}]` back.
5. Verify output: `ls -lh <out>.wav`, `ffprobe` duration, optionally `curl -s "http://127.0.0.1:17493/history?limit=1"` last item.
6. Telos integration: if `cwd` is telos project, auto-suggest `projects/NN_slug/assets/audio/` as out-dir and include in commit.

Never use `voicebox.speak` in parallel across chunks. If MCP is available, you may implement same loop with MCP tool + REST polling, but still one at a time.

## Manual REST (if not using helper)

```bash
# resolve profile id
PROFILE_ID=$(curl -s http://127.0.0.1:17493/profiles | python3 -c "import json,sys; d=json.load(sys.stdin); print([p for p in d if p['name']=='the_narrator_en'][0]['id'])")
# generate one chunk
GEN_ID=$(curl -s http://127.0.0.1:17493/generate -H "Content-Type: application/json" -d "{\"profile_id\":\"$PROFILE_ID\",\"text\":\"Hello world\",\"language\":\"en\"}" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
# poll SSE until completed (last data line)
curl -s http://127.0.0.1:17493/generate/$GEN_ID/status --no-buffer | grep "data:"  # until completed
# wav at /home/dennis/work/voicebox/data/generations/$GEN_ID.wav or generations/<id>.wav from history
curl -s "http://127.0.0.1:17493/history?limit=1" | python3 -m json.tool
```

For books: repeat above in loop, collect wavs, `ffmpeg -f concat -safe 0 -i concat.txt -c copy audiobook.wav`.

## Telos Specific

`telos` script files live `projects/NN_slug/<slug>.md` (1706 chars example). For bulk audiobook of all telos projects, iterate dirs, run helper per file:

```bash
for md in projects/*/*.md; do stem=$(basename "$md" .md); python ~/.config/opencode/skills/text-to-voice/scripts/voicebox_tts.py --input "$md" --out "projects/$(dirname $md | xargs basename)/assets/audio/$stem.wav" --voice the_narrator_en; done
```

## Prerequisites Check

Before run: `curl -s http://127.0.0.1:17493/health | jq` must be `healthy` and `model_loaded true`, `ffmpeg` present (`which ffmpeg`). If `model_loaded false`, still proceeds — API auto-loads model (adds ~5s).

## Failure Modes

* `profile not found` -> list via `/profiles`, ask user.
* `500` on `/generate` -> model OOM, call `curl -s http://127.0.0.1:17493/health` check `vram_used_mb`, reduce `--max-chunk` to 500.
* Missing wav -> check `/home/dennis/work/voicebox/data/generations/` + `GET /history`.
* No ffmpeg -> `pacman -S ffmpeg` or `ffmpeg` via nix.

