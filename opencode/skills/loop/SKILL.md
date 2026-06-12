---
name: loop
description: >
  Autonomous development loop. Re-runs a task prompt until the model signals
  completion via `<promise>DONE</promise>` or max iterations hit. Uses the loop
  plugin for auto-continuation, compaction, cancellation, and status reporting.
  Trigger: `/loop <task>`, user mentions "loop", "keep going", "auto-continue".
---

# Loop Skill

## Commands

| Command | Description |
|---------|-------------|
| `/loop <task> [--max-iterations N] [--compact-every N]` | Start a loop |
| `/cancel-loop` | Cancel active loop |
| `/loop-status` | Check loop state |

## How It Works

1. User runs `/loop Refactor auth module`
2. AI works on the task for one turn
3. When AI finishes, plugin checks for `<promise>DONE</promise>` in last response
4. If not done, plugin increments iteration and sends "Continue working"
5. Loops until DONE or max iterations (default 25)
6. Auto-compacts context every 5th iteration (configurable via `--compact-every`)

## AI Behavior

- Output `<promise>DONE</promise>` **only** when fully complete — all subtasks done, verified, no loose ends
- Call `loop_blocked` tool if stuck and cannot proceed
- Each iteration should make concrete, verifiable progress
- Prefer completing one thing fully over touching many things partially

## Options

```
/loop task --max-iterations 50   (default 25)
/loop task --compact-every 10    (default 5)
/loop task --max-iterations 10 --compact-every 3
```
