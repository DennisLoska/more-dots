---
name: backup-opencode
description: Backup opencode config to ~/work/more-dots. Executes ~/scripts/opencode-backup.sh to sync ~/.config/opencode -> ~/work/more-dots/opencode and git add/commit/push. Use when user wants to backup opencode, sync dotfiles, persist opencode setup, or save opencode changes.
---

# backup-opencode

Syncs local opencode config into dotfiles repo (`more-dots`) and optionally commits/pushes.

## What it does

- Runs `~/scripts/opencode-backup.sh` (bash, `MORE_DOTS_DIR` var at top)
- Copies `~/.config/opencode/` → `~/work/more-dots/opencode/` (not `.opencode`) via `rsync -av --delete --exclude=node_modules --exclude=.git` (fallback `cp -a`)
- In `~/work/more-dots` git repo: `git add opencode`, `git commit -m "backup: opencode <timestamp>"`, `git push` if changes exist

## Usage

When this skill is invoked, execute:

```bash
bash ~/scripts/opencode-backup.sh
```

No args needed — defaults to copy + commit + push if changes.

## Options (pass through to script)

- `--no-commit` — copy only, skip git
- `--no-push` — commit but don't push
- `--dry-run` — preview rsync + git status without writing
- `-m "msg"` / `--commit-msg "msg"` — custom commit message
- `-h` / `--help` — help

Examples:

```bash
bash ~/scripts/opencode-backup.sh --dry-run
bash ~/scripts/opencode-backup.sh --no-push
bash ~/scripts/opencode-backup.sh -m "backup: opencode manual"
```

## Notes

- `MORE_DOTS_DIR` is defined at top of script — edit there to change target.
- `node_modules` and `.git` are excluded from sync (huge, ignored by git).
- If repo has no changes, script exits cleanly with "nothing to commit".
