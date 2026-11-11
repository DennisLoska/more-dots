#!/usr/bin/env bash
set -euo pipefail

# --- Config (edit here) ---
MORE_DOTS_DIR="$HOME/work/more-dots"
SRC_DIR="${OPENCODE_CONFIG:-$HOME/.config/opencode}"
DEST_DIR="$MORE_DOTS_DIR/opencode"

# --- Flags ---
DO_COMMIT=true
DO_PUSH=true
COMMIT_MSG=""
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Copies contents of \$SRC_DIR (~/.config/opencode) to \$DEST_DIR (\$MORE_DOTS_DIR/opencode),
redacts/excludes secrets, then optionally git add / commit / push in more-dots.

Options:
  --no-commit          Copy only, skip git add/commit/push
  --no-push            Commit but do not push
  --dry-run            Show what would be done, don't copy or commit
  -m, --commit-msg MSG Custom commit message (default: "backup: opencode YYYY-MM-DD HH:MM:SS")
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
  "node_modules"
  ".git"
  "service.json"
  "auth.json"
  ".credentials.json"
  "credentials.json"
  "state"
  "*.bak"
  "*.bak-*"
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
    echo "[dry-run] would run: git -C \"$MORE_DOTS_DIR\" status --porcelain -- opencode"
    git -C "$MORE_DOTS_DIR" status --porcelain -- opencode || true
  fi
  exit 0
fi

# --- Sync ---
echo "[opencode-backup] $SRC_DIR -> $DEST_DIR"
mkdir -p "$DEST_DIR"

if command -v rsync >/dev/null 2>&1; then
  rsync "${RSYNC_ARGS[@]}" "$SRC_DIR/" "$DEST_DIR/"
else
  cp -a "$SRC_DIR/." "$DEST_DIR/"
  rm -rf "$DEST_DIR/node_modules" "$DEST_DIR/state" "$DEST_DIR/service.json" "$DEST_DIR/auth.json" "$DEST_DIR/.credentials.json" 2>/dev/null || true
  rm -f "$DEST_DIR"/*.bak "$DEST_DIR"/*.bak-* 2>/dev/null || true
fi

# --- Sanitize & Verify No Secrets Leaked ---
python3 - "$DEST_DIR" <<'PYEOF'
import json, os, re, sys

dest = sys.argv[1]
secret_val_re = re.compile(
    r"(sk-ant-[a-zA-Z0-9_-]{12,}|sk-[a-zA-Z0-9_-]{16,}|ghp_[a-zA-Z0-9]{20,}|gho_[a-zA-Z0-9]{20,}|github_pat_[a-zA-Z0-9_]{20,}|lin_api_[a-zA-Z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|rt\.[0-9]+\.[A-Za-z0-9_-]{20,}|xox[baprs]-[a-zA-Z0-9-]{10,})"
)
sensitive_key_re = re.compile(r"^(api[_-]?key|access[_-]?token|refresh[_-]?token|id[_-]?token|client[_-]?secret|password|passwd|secret|bearer|private[_-]?key|auth[_-]?token|credentials?)$", re.I)

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
                    print(f"[opencode-backup] redacted sensitive fields in {os.path.relpath(fp, dest)}")
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

echo "[opencode-backup] sync & secret scan done"

# --- Git add / commit / push ---
if [[ "$DO_COMMIT" == false ]]; then
  echo "[opencode-backup] --no-commit, stopping after copy"
  exit 0
fi

if [[ ! -d "$MORE_DOTS_DIR/.git" ]]; then
  echo "[opencode-backup] no git repo at $MORE_DOTS_DIR, skipping commit"
  exit 0
fi

if [[ -z "$(git -C "$MORE_DOTS_DIR" status --porcelain -- opencode)" ]]; then
  echo "[opencode-backup] no changes in opencode/, nothing to commit"
  exit 0
fi

echo "[opencode-backup] changes detected, staging opencode/"
git -C "$MORE_DOTS_DIR" add opencode

if git -C "$MORE_DOTS_DIR" diff --cached --quiet; then
  echo "[opencode-backup] nothing staged after add, skipping commit"
  exit 0
fi

if [[ -z "$COMMIT_MSG" ]]; then
  COMMIT_MSG="backup: opencode $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo "[opencode-backup] committing: $COMMIT_MSG"
git -C "$MORE_DOTS_DIR" commit -m "$COMMIT_MSG"

if [[ "$DO_PUSH" == true ]]; then
  echo "[opencode-backup] pushing..."
  if ! git -C "$MORE_DOTS_DIR" push; then
    echo "[opencode-backup] push failed (maybe no remote or offline)" >&2
    exit 1
  fi
  echo "[opencode-backup] push done"
else
  echo "[opencode-backup] --no-push, skipping push"
fi
