---
name: loop
description: >
  Autonomous dev loop with idle-safe auto-continue, scheduling, verification, and background daemon via @bybrawe/opencode-loop (0.5.35). Trigger: /loop, /loop-help, /loop-status, /loop-doctor. Re-runs until <promise>DONE</promise> or limits hit, with compaction and verification gates.
---

# Loop Skill — ByBrawe opencode-loop (installed 0.5.35)

Idle-safe auto-continue, scheduled prompt/command/shell jobs, compact scheduling, verification/checkpoints, background daemon `opencode-loopd`.

**Installed:** `@bybrawe/opencode-loop@0.5.35` via `npx -y @bybrawe/opencode-loop@latest --loop-only`. Plugin: `./plugins/opencode-loop.ts` (4876 lines, was 211). Old minimal plugin backed up to `/tmp/backup-loop/loop`.

Restart OpenCode then verify:

```
/loop-help
/loop-doctor
/loop-status
```

## Mental Model

1. **When due?** idle, timer, watch trigger, or `/loop-now`
2. **When safe?** Only when session actually idle — timer expiry waits for idle, no stacked turns.

## Commands

| Command | Purpose |
|---------|---------|
| `/loop <prompt>` | unlimited idle loop — every safe idle |
| `/loop idle <prompt>` | explicit idle form |
| `/loop every <dur> <prompt>` | recurring timer, first after dur |
| `/loop after <dur> <prompt>` / `/loop in <dur> <prompt>` | one-shot delayed |
| `/loop <dur> <prompt>` | legacy recurring (now=idle) |
| `/loop-command <interval> <cmd>` / `/loop-cmd` | schedule slash command |
| `/loop-shell <interval> <sh>` | schedule shell command |
| `/loop-ask <interval> <q>` | recurring check |
| `/loop-status` | schedule + state (waiting/due/enabled/paused) |
| `/loop-logs` | scheduler/runtime events |
| `/loop-doctor` | diagnose busy/retry stale state |
| `/loop-now [id/all]` | mark due now (waits idle) |
| `/loop-pause` `/loop-resume` `/loop-remove` `/loop-clear` | lifecycle |
| `/loop-init` | create `progress.md` starter |
| `/loop-export` | export state |
| `opencode-loopd --every 5m --prompt-file loop-prompt.md` | background daemon survives TUI close |

Durations: `ms|s|m|h|d` e.g. `5m`, `1h`, `200m`.

## Flags

Lifecycle: `--name <name> --max-runs <n> --max-runtime <dur> --max-failures <n> --timeout <dur> --no-now --now`
Safety: `--safe --ask-never --no-overlap --verify "npm test" --preflight "npm install" --postrun "git status" --pause-on-verify-fail`
Context: `--progress-file progress.md --prompt-file loop-prompt.md --include-file ARCHITECTURE.md --batch 5 --compact-every 20 --watch progress.md`
Checkpoints: `--checkpoint-only --git-checkpoint` (stages/commits — intentional only)

## How It Works (replaces old minimal)

1. `/loop continue` → due on next safe idle, repeats every idle until stopped or limit hit
2. Plugin checks `<promise>DONE</promise>` in last assistant turn
3. If not done → increment iteration, send `Continue working. Iteration N/M`
4. Auto-compact every N iterations
5. Timer jobs (`every`/`after`) become due on clock but still wait for idle — no overlap
6. Stale `busy/retry` after plugin ack is cross-checked against msg tail → recovery `status-message-idle-recovery` logged

## Recommended Loops

Dev loop:
```
/loop --name dev --ask-never --safe --no-overlap --batch 5 --compact-every 200m --checkpoint-only --progress-file progress.md Treat progress.md as state. Continue next unfinished TODO, implement, verify, update progress.md.
```

Test/fix (mirrors oneshot Phase 6 adversarial 5-round):
```
/loop --name testfix --ask-never --safe --verify "npm test" --max-failures 3 --progress-file progress.md Continue from progress.md. If tests fail, fix and rerun.
```

Oneshot 5-round PASS+green gate can use `/loop --max-runs 5 --verify "npm test" --pause-on-verify-fail` and let reviewer emit `<promise>DONE</promise>` only on PASS+green.

## AI Behavior

- Emit `<promise>DONE</promise>` only when fully complete, verified, no loose ends
- `loop_blocked` if stuck, `loop_complete` if done (tools still available)
- Each iteration concrete progress — don't redo completed work, inspect `progress.md`/git state
- Short prompts `continue`/`devam et` interpreted as project continuation, not new task invention (reads files/TODO/git)

## State & Diagnostics

- Runtime: `.opencode/opencode-loop/<session-id>.json` (was `.opencode/loop/state.json` single file)
- Logs: `.opencode/opencode-loop/loop.log` + `checkpoints/`
- Add `.opencode/opencode-loop/` to `.gitignore` if not committing runtime
- `/loop-status` shows `schedule=every idle | state=waiting for idle` vs `due in 3m` — `enabled=true paused=false runCount=0` with no runs = stale busy suspected
- `/loop-doctor` reports other sessions with enabled never-run jobs (old loops visible not lost)

## Background Daemon

Session-bound `/loop` dies with TUI. For daemon:
```
opencode-loopd --project . --every 5m --prompt-file loop-prompt.md
opencode-loopd --every 0s --prompt "continue from progress.md"
opencode-loopd --session ses_xxx --every 5m --max-runs 20 --timeout 30m --prompt-file loop-prompt.md
opencode-loopd install-task --project "C:\\path" --every 10m --prompt-file loop-prompt.md --name OpenCodeLoop
```

## Migration Note

Old minimal plugin (211 lines) replaced. Backup at `/tmp/backup-loop/loop`. Commands expanded from 3 (`/loop`, `/cancel-loop`, `/loop-status`) to 20+ (`/loop-*`, daemon). Existing `/loop continue` semantics preserved (idle loop).

See `https://github.com/ByBrawe/opencode-loop` and `docs/SCHEDULING.md` for schedule truth table, CHANGELOG.
