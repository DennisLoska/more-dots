---
name: copy-user-commands
description: Use when telling the user to run a shell command, open a URL, or paste a token themselves instead of running it for them.
---

# Copy User Commands

## Overview

Anything the user must run by hand goes straight to their clipboard. No manual copy-paste.

## When to Use

- Shell command the user must run (login flows, installs needing sudo/approval, device steps)
- URL or deep link the user must open (Expo Go URLs, preview links, OAuth pages)
- Token or value the user must paste somewhere

NOT for commands you execute yourself with the shell tool.

## Implementation

Copy the exact text you show, then confirm in one short line. Cross-platform (macOS + Linux):

```bash
clip() { case "$(uname)" in Darwin) pbcopy;; *) wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || xsel --clipboard --input 2>/dev/null || echo "no clipboard tool found" >&2;; esac; }; clip <<'CLIP_EOF'
<exact text shown to user>
CLIP_EOF
```

Toolchain: macOS ships `pbcopy`. Linux needs one of `wl-copy` (Wayland), `xclip` or `xsel`
(X11); if none exists, install one (`apt install xclip`) and retry.

## Rules

- Copy what you show, verbatim. Never a paraphrase.
- One clipboard item per turn: a sequence that runs in order goes as one newline-separated block, otherwise copy only the immediate next step.
- Secrets included only if you already display them to the user.
- Confirm briefly (`Copied, paste and run.`), then stop. No extra questions.

## Common Mistakes

- `echo "<cmd>" | pbcopy` mangles quotes and appends a newline. Use the heredoc form.
- Forgetting the copy when the command is "obvious" or short. Short commands need it most.
- Copying a command you already ran yourself. This skill is user-run commands only.

Keywords: clipboard, pbcopy, copy paste, user-run command, login command, manual step.
