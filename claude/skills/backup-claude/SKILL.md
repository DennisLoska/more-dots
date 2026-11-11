---
name: backup-claude
description: Backup claude code config to ~/work/more-dots. Executes ~/scripts/claude-backup.sh to sync ~/.claude -> ~/work/more-dots/claude and git add/commit/push. Use when user wants to backup claude, backup claude code, sync dotfiles, persist claude setup, or save claude changes.
---

# backup-claude

Syncs local Claude Code config into dotfiles repo (`more-dots`) and optionally commits/pushes, while stripping/excluding secrets and runtime state.

## What it does

- Runs `~/scripts/claude-backup.sh` (bash, `MORE_DOTS_DIR` var at top)
- Copies `~/.claude/` -> `~/work/more-dots/claude/` via `rsync -av --delete` excluding `.git`, `.credentials.json`, `mcp-needs-auth-cache.json`, `history.jsonl`, `.last-cleanup`, `backups`, `cache`, `projects`, `session-env`, `sessions`, `shell-snapshots`, `state`, `plugins`, and `skills/synced`
- Scans and redacts any inline API keys or tokens before staging
- In `~/work/more-dots` git repo: `git add claude`, `git commit -m "backup: claude <timestamp>"`, `git push` if changes exist

## Usage

When this skill is invoked, execute:

```bash
bash ~/scripts/claude-backup.sh
```

No args needed - defaults to copy + commit + push if changes.

## Options (pass through to script)

- `--no-commit` - copy only, skip git
- `--no-push` - commit but don't push
- `--dry-run` - preview rsync + git status without writing
- `-m "msg"` / `--commit-msg "msg"` - custom commit message
- `-h` / `--help` - help

Examples:

```bash
bash ~/scripts/claude-backup.sh --dry-run
bash ~/scripts/claude-backup.sh --no-push
bash ~/scripts/claude-backup.sh -m "backup: claude manual"
```

## Notes

- `MORE_DOTS_DIR` is defined at top of script - edit there to change target.
- `.credentials.json`, OAuth caches, and session histories are excluded and scanned to ensure no API keys or tokens ever leak.
- If repo has no changes, script exits cleanly with "nothing to commit".
