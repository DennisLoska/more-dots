---
name: backup-codex
description: Backup codex config to ~/work/more-dots. Executes ~/scripts/codex-backup.sh to sync ~/.codex -> ~/work/more-dots/codex and git add/commit/push. Use when user wants to backup codex, sync dotfiles, persist codex setup, or save codex changes.
---

# backup-codex

Syncs local Codex config into dotfiles repo (`more-dots`) and optionally commits/pushes, while stripping/excluding secrets and runtime state.

## What it does

- Runs `~/scripts/codex-backup.sh` (bash, `MORE_DOTS_DIR` var at top)
- Copies `~/.codex/` -> `~/work/more-dots/codex/` via `rsync -av --delete` excluding `.git`, `auth.json`, `auth.lock`, `mcp-oauth-locks`, `*.sqlite*`, `history.jsonl`, `installation_id`, `models_cache.json`, `version.json`, `state`, `sessions`, `shell_snapshots`, `cache`, `packages`, `plugins`, `tmp`, `.tmp`, and `skills/.system`
- Scans and redacts any inline API keys or tokens before staging
- In `~/work/more-dots` git repo: `git add codex`, `git commit -m "backup: codex <timestamp>"`, `git push` if changes exist

## Usage

When this skill is invoked, execute:

```bash
bash ~/scripts/codex-backup.sh
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
bash ~/scripts/codex-backup.sh --dry-run
bash ~/scripts/codex-backup.sh --no-push
bash ~/scripts/codex-backup.sh -m "backup: codex manual"
```

## Notes

- `MORE_DOTS_DIR` is defined at top of script - edit there to change target.
- `auth.json`, SQLite DBs, and runtime caches are excluded and scanned to ensure no API keys or tokens ever leak.
- If repo has no changes, script exits cleanly with "nothing to commit".
