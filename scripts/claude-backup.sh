#!/usr/bin/env bash
set -euo pipefail

# --- Config (edit here) ---
MORE_DOTS_DIR="$HOME/work/more-dots"
SRC_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST_DIR="$MORE_DOTS_DIR/claude"

# --- Flags ---
DO_COMMIT=true
DO_PUSH=true
COMMIT_MSG=""
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Copies contents of \$SRC_DIR (~/.claude) to \$DEST_DIR (\$MORE_DOTS_DIR/claude),
excludes OAuth credentials/session state/caches, redacts any inline secrets,
then optionally git add / commit / push in more-dots.

Options:
  --no-commit          Copy only, skip git add/commit/push
  --no-push            Commit but do not push
  --dry-run            Show what would be done, don't copy or commit
  -m, --commit-msg MSG Custom commit message (default: "backup: claude YYYY-MM-DD HH:MM:SS")
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-commit) DO_COMMIT=false; DO_PUSH=false; shift ;;
    --no-push) DO_PUSH=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -m|--commit-msg) COMMIT_MSG="$2"; shift 2 ;;
    --commit-msg=*) COMMIT_MSG="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# --- Checks ---
if [[ ! -d "$SRC_DIR" ]]; then
  echo "error: SRC_DIR not found: $SRC_DIR" >&2
  exit 1
fi

if [[ ! -d "$MORE_DOTS_DIR" ]]; then
  echo "error: MORE_DOTS_DIR not found: $MORE_DOTS_DIR" >&2
  exit 1
fi

EXCLUDES=(
  ".git"
  ".credentials.json"
  "credentials.json"
  "auth.json"
  "mcp-needs-auth-cache.json"
  "history.jsonl"
  ".last-cleanup"
  "backups"
  "cache"
  "projects"
  "session-env"
  "sessions"
  "shell-snapshots"
  "state"
  "plugins"
  "skills/synced"
  "__pycache__"
  "*.pyc"
  ".env"
  ".env.*"
)

RSYNC_ARGS=(-av --delete)
for ex in "${EXCLUDES[@]}"; do
  RSYNC_ARGS+=(--exclude="$ex")
done

if [[ "$DRY_RUN" == true ]]; then
  echo "[dry-run] SRC:  $SRC_DIR"
  echo "[dry-run] DEST: $DEST_DIR"
  echo "[dry-run] commit: $DO_COMMIT  push: $DO_PUSH"
  if command -v rsync >/dev/null 2>&1; then
    rsync -n "${RSYNC_ARGS[@]}" "$SRC_DIR/" "$DEST_DIR/"
  else
    echo "[dry-run] cp -a \"$SRC_DIR/.\" \"$DEST_DIR/\""
  fi
  if [[ "$DO_COMMIT" == true && -d "$MORE_DOTS_DIR/.git" ]]; then
    echo "[dry-run] would run: git -C \"$MORE_DOTS_DIR\" status --porcelain -- claude"
    git -C "$MORE_DOTS_DIR" status --porcelain -- claude || true
  fi
  exit 0
fi

# --- Sync ---
echo "[claude-backup] $SRC_DIR -> $DEST_DIR"
mkdir -p "$DEST_DIR"

if command -v rsync >/dev/null 2>&1; then
  rsync "${RSYNC_ARGS[@]}" "$SRC_DIR/" "$DEST_DIR/"
else
  cp -a "$SRC_DIR/." "$DEST_DIR/"
  rm -rf "$DEST_DIR/.credentials.json" "$DEST_DIR/credentials.json" "$DEST_DIR/auth.json" \
    "$DEST_DIR/mcp-needs-auth-cache.json" "$DEST_DIR/history.jsonl" "$DEST_DIR/.last-cleanup" \
    "$DEST_DIR/backups" "$DEST_DIR/cache" "$DEST_DIR/projects" "$DEST_DIR/session-env" \
    "$DEST_DIR/sessions" "$DEST_DIR/shell-snapshots" "$DEST_DIR/state" "$DEST_DIR/plugins" \
    "$DEST_DIR/skills/synced" 2>/dev/null || true
fi

chmod 644 "$DEST_DIR/settings.json" 2>/dev/null || true

# --- Sanitize & Verify No Secrets Leaked ---
python3 - "$DEST_DIR" <<'PYEOF'
import json, os, re, sys

dest = sys.argv[1]
secret_val_re = re.compile(
    r"(sk-ant-[a-zA-Z0-9_-]{12,}|sk-[a-zA-Z0-9_-]{16,}|ghp_[a-zA-Z0-9]{20,}|gho_[a-zA-Z0-9]{20,}|github_pat_[a-zA-Z0-9_]{20,}|lin_api_[a-zA-Z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|rt\.[0-9]+\.[A-Za-z0-9_-]{20,}|xox[baprs]-[a-zA-Z0-9-]{10,})"
)
sensitive_key_re = re.compile(r"^(api[_-]?key|access[_-]?token|refresh[_-]?token|id[_-]?token|client[_-]?secret|password|passwd|secret|bearer|private[_-]?key|auth[_-]?token|credentials?|oauth[_-]?token)$", re.I)

def is_safe_placeholder(val):
    if not isinstance(val, str):
        return True
    v = val.strip()
    if not v or v in ("<REDACTED>", "null", "none"):
        return True
    if "{env:" in v or "${" in v or v.startswith("env://") or v.startswith("file://"):
        return True
    if v.endswith("..."):
        return True
    return False

def redact_obj(obj):
    changed = False
    if isinstance(obj, dict):
        for k, v in list(obj.items()):
            if isinstance(v, (dict, list)):
                if redact_obj(v):
                    changed = True
            elif isinstance(v, str):
                if sensitive_key_re.match(k) and not is_safe_placeholder(v):
                    obj[k] = "<REDACTED>"
                    changed = True
                elif k.lower() == "authorization" and not is_safe_placeholder(v):
                    obj[k] = "<REDACTED>"
                    changed = True
                elif secret_val_re.search(v) and not is_safe_placeholder(v):
                    obj[k] = secret_val_re.sub("<REDACTED>", v)
                    changed = True
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            if isinstance(v, (dict, list)):
                if redact_obj(v):
                    changed = True
            elif isinstance(v, str) and secret_val_re.search(v) and not is_safe_placeholder(v):
                obj[i] = secret_val_re.sub("<REDACTED>", v)
                changed = True
    return changed

leaks = []
for dp, dn, fn in os.walk(dest, followlinks=False):
    dn[:] = [d for d in dn if d not in (".git", "node_modules")]
    for f in fn:
        fp = os.path.join(dp, f)
        if os.path.islink(fp):
            continue
        if f.endswith(".json"):
            try:
                with open(fp, "r", encoding="utf-8") as fh:
                    data = json.load(fh)
                if redact_obj(data):
                    with open(fp, "w", encoding="utf-8") as fh:
                        json.dump(data, fh, indent=2)
                        fh.write("\n")
                    print(f"[claude-backup] redacted sensitive fields in {os.path.relpath(fp, dest)}")
            except Exception:
                pass
        try:
            with open(fp, "r", encoding="utf-8", errors="ignore") as fh:
                content = fh.read()
            m = secret_val_re.search(content)
            if m:
                leaks.append((os.path.relpath(fp, dest), m.group(0)[:10] + "..."))
        except Exception:
            pass

if leaks:
    for rel, snippet in leaks:
        print(f"error: secret pattern detected in {rel} ({snippet})", file=sys.stderr)
    sys.exit(1)
PYEOF

echo "[claude-backup] sync & secret scan done"

# --- Git add / commit / push ---
if [[ "$DO_COMMIT" == false ]]; then
  echo "[claude-backup] --no-commit, stopping after copy"
  exit 0
fi

if [[ ! -d "$MORE_DOTS_DIR/.git" ]]; then
  echo "[claude-backup] no git repo at $MORE_DOTS_DIR, skipping commit"
  exit 0
fi

if [[ -z "$(git -C "$MORE_DOTS_DIR" status --porcelain -- claude)" ]]; then
  echo "[claude-backup] no changes in claude/, nothing to commit"
  exit 0
fi

echo "[claude-backup] changes detected, staging claude/"
git -C "$MORE_DOTS_DIR" add claude

if git -C "$MORE_DOTS_DIR" diff --cached --quiet; then
  echo "[claude-backup] nothing staged after add, skipping commit"
  exit 0
fi

if [[ -z "$COMMIT_MSG" ]]; then
  COMMIT_MSG="backup: claude $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo "[claude-backup] committing: $COMMIT_MSG"
git -C "$MORE_DOTS_DIR" commit -m "$COMMIT_MSG"

if [[ "$DO_PUSH" == true ]]; then
  echo "[claude-backup] pushing..."
  if ! git -C "$MORE_DOTS_DIR" push; then
    echo "[claude-backup] push failed (maybe no remote or offline)" >&2
    exit 1
  fi
  echo "[claude-backup] push done"
else
  echo "[claude-backup] --no-push, skipping push"
fi
