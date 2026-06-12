---
name: silicon-seeds
description: Use when working on the silicon-seeds project — Bun+HTMX+Kysely+Websocket app with LM Studio + ComfyUI media generation, DB-backed job queues, SSE-driven UI updates, and DaisyUI components
---

# Silicon-Seeds

Bun-based generative media orchestration app. LM Studio + ComfyUI + SQLite + HTMX SSE UI.

## Tech Stack

- **Bun** runtime + hot reload (`bun start:hot`)
- **Hono + JSX** — SSR, typed-htmx, Hono JSX templates
- **SQLite + Kysely** — schema in `src/schema.ts`, migrations in `src/migrations/`, queries in `src/db/`
- **HTMX + SSE** — `hx-trigger="sse:<event>"`, fragment fetches on notification
- **DaisyUI v5** — UI components, styled via Tailwind CSS v4 (`bun run build:css`)
- **LM Studio** — text/prompt/autocut generation via HTTP
- **ComfyUI** — image/video/audio/song generation via WebSocket + queue
- **WhisperX** — external transcription CLI
- **yt-dlp** — YouTube download
- **Zod** — request validation
- **Logtape** — structured logging

## Key Architecture

### SSE Update Model
1. Server publishes `job-update` SSE event for specific job
2. Browser receives SSE → HTMX re-fetches progress fragment
3. Server returns fresh HTML fragment

### DB-Backed Queue
- Single media generation slot globally
- Priority: audio=300, image=200, video/transition=100
- Events ordered by `priority desc`, `index asc`, `created_at asc`
- Recovery on startup: fail broken jobs, requeue running events

### Event Ordering
- Chronological: `DB.Events.findByJobIdChronological(jobId)` — UI timelines
- Sequencing: `DB.Events.findByJobId(jobId)` — compose media (index-aware)

## Common Commands

```
bun start:hot        # dev with hot reload
bun db:migrate       # run pending migrations
bun db:rollback      # rollback last migration
bun run build:css    # rebuild Tailwind
bun run lint         # lint
bunx tsc --noEmit    # typecheck
```

## Routes Structure

- `GET /, /dashboard` — dashboard
- `GET /compose` — compose video
- `GET /create/image` — image generation
- `GET /create/audio` — song generation
- `GET /create/autocut` — AI video editing
- `GET /settings` — settings
- `GET /gallery` — generated media gallery
- `GET /jobs` — job list
- `GET /jobs/details/:jobId` — job detail
- `POST /api/jobs/videos/compose` — compose pipeline
- `POST /api/jobs/videos/autocut` — AutoCut
- `POST /api/jobs/images` — image gen
- `POST /api/jobs/audio` — song gen
- `POST /api/jobs/:job_id/cancel` — cancel job
- `POST /api/jobs/:job_id/events/:event_id/regenerate` — retry event
- `GET /jobs/stream?job_id=...` — SSE stream

## Key Directories

```
src/api/         HTTP routes
src/audio/       speech/song via ComfyUI
src/autocut/     AI video editing
src/comfyui/     ComfyUI client + workflows
src/db/          schema, queries, migrations
src/jobs/        job orchestration
src/llm/         LM Studio + MCP client
src/prompts/     scene/image/video prompt gen
src/queue/       DB-backed queue manager
src/socket/      ComfyUI WebSocket listener
src/sse/         SSE publisher
src/styles/      art style defs + presets
src/templates/   JSX templates + fragments
src/video/       video/transition/composition
src/whisperx/    transcription wrapper
src/yt/          YouTube download
```

## Common Pitfalls

- Compose image prompts created in parallel — use `index` not `created_at` for ordering
- Several templates build `/assets/...` inline instead of shared helper
- Timestamps use millisecond precision for new rows
- Read `/docs/` before any changes — project docs in `docs/bun.md`, `docs/kysely.md`, `docs/daisyui.md`, `docs/lm-studio.md`
- Verify via `curl http://localhost:3000/?job_id=...&tab=status`
