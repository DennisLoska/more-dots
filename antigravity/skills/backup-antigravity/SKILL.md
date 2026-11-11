---
name: backup-antigravity
description: Backup antigravity config to ~/work/more-dots. Executes ~/scripts/antigravity-backup.sh to sync ~/.gemini/config (and CLI settings) -> ~/work/more-dots/antigravity and git add/commit/push. Use when user wants to backup antigravity, sync dotfiles, persist antigravity setup, or save antigravity changes.
---

# backup-antigravity

Syncs local Antigravity config into dotfiles repo (`more-dots`) and optionally commits/pushes, while stripping/excluding secrets and runtime state.

## What it does

- Runs `~/scripts/antigravity-backup.sh` (bash, `MORE_DOTS_DIR` var at top)
- Copies `~/.gemini/config/` (and `~/.gemini/antigravity-cli/settings.json` as `cli-settings.json`) -> `~/work/more-dots/antigravity/` via `rsync -av --delete` excluding `.git`, `state`, `auth.json`, and `.credentials.json`
- Scans and redacts any inline API keys or tokens before staging
- In `~/work/more-dots` git repo: `git add antigravity`, `git commit -m "backup: antigravity <timestamp>"`, `git push` if changes exist

## Usage

When this skill is invoked, execute:

```bash
bash ~/scripts/antigravity-backup.sh
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
bash ~/scripts/antigravity-backup.sh --dry-run
bash ~/scripts/antigravity-backup.sh --no-push
bash ~/scripts/antigravity-backup.sh -m "backup: antigravity manual"
```

## Notes

- `MORE_DOTS_DIR` is defined at top of script - edit there to change target.
- Runtime state, conversation DBs, and auth files are excluded and scanned to ensure no API keys or tokens ever leak.
- If repo has no changes, script exits cleanly with "nothing to commit".
