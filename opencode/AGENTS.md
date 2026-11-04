# Global Agent Instructions

## Writing Style - No Emdash Ever

- HARD BAN: NEVER output the emdash character (Unicode U+2014) in ANY context - chat, code, comments, strings, docs, file edits, commit messages. No exceptions unless user explicitly writes "use emdash" in current request, and even then confirm first.
- ALWAYS use hyphen (-), comma, colon, or period instead.
- BEFORE every write/edit/output: mentally scan for U+2014 and replace. If you typed it, you failed - fix before sending.
- Self-check: if text contains U+2014, rewrite immediately. Treat as lint error, not style preference.

## Verification Protocol

Before declaring any task complete, you MUST verify:
- Run/build the code - did it work?
- Trigger the exact feature changed - did it behave correctly?
- Check for error messages in output
- Would I bet actual money this works?

Hygiene: `bunx tsc`/`lint`/`build` output fine inline (short). Broad test mapping (>1 file) delegate to subagent instead of inline `read` loops.

Red flags - never say these:
- "This should work now" (especially 2nd+ time on same issue)
- "Try it now" (without trying it yourself first)
- "The logic is correct so..." (logic is not proof)

## Tool Preferences & Context Hygiene

- Prefer `rg` over `grep`, `fd` over `find`, `bun` over `npm`/`yarn` - but run `rg`/`fd` inside subagents, not inline in main.
- **Hygiene rule:** Any search touching >1 file or >50 lines must delegate to subagent. Inline `read`/`bash ls` only for single file you will immediately `edit` or trivial existence check.
- `scout` (`subagent` `agent: scout`): read-only locator, compressed `path:line` table, no snippets, no fix suggestions. Use for "where is X defined", "what calls Y", "list all uses of Z", fast maps. ~60% smaller than `explore`.
- `explore` (`subagent` `agent: explore`): thorough reader, `file:line` + code blocks + env values + interaction graphs. Use when need full snippets, dep chains, planning context.
- Main never loops `rg`/`fd`/`read` directly - subagent output compressed keeps main lean for long sessions.

## Process Management - Port-Targeted Restarts Only

When restarting app for debugging/dev, never kill all bun or node processes (`pkill bun`, `killall node`, `pkill -f node`, etc.). Kill only process on specific port (`fuser -k PORT/tcp`, `lsof -ti:PORT | xargs kill`, etc.). Broad kills nuke unrelated services.

## Browser - User URLs vs DevTools

- User asks to open ticket, website, URL for viewing: use `xdg-open "<url>"` (background, disowned). Opens in user's existing default browser with session.
- NEVER use chrome-devtools `new_page`/`navigate_page` just to show user a page. That spawns isolated automation Chromium, no user cookies, hits login walls.
- Reserve chrome-devtools plugin for development only: snapshots, console messages, network requests, screenshots, performance traces, element interaction during debugging.

## Security & Boundaries

- NEVER commit to main or master directly (no `git commit` on main/master, no push to them) unless user explicitly says so in current session. Work always happens on a ticket/feature branch; merging happens via PR.
- NEVER read `.env`, `.env.*` (except `.env.example`), `.zshrc`, `.zsh_history`
- NEVER printenv, sudo, or access secrets
- NEVER gh delete, gh org, gh secret operations
- NEVER rm -rf anything
- NEVER rm with a wildcard (`*`) in `~/content_library` or any media dir (enforced: opencode.json denies `rm *content_library*`, `rm -rf *`, `rm -r *`). Deletions there are exact filenames only after `ls` verification, or via the app's own prune flow. A cleanup helper that computes filenames must still delete by exact path, one by one.
- ALWAYS ask before installing npm/bun packages
- External directory access: `~/work/**`, `~/.config/opencode/**`, `/tmp/**` are always allowed

## Plugins

### opencode-mem
Persistent memory across sessions. Stores learnings about projects, preferences, and decisions.
- Invoke: reference it naturally - "remember that..." or "what do you know about..."
- It auto-recalls relevant context per-session.

## MCP Servers

### context7
Fresh library documentation - use when you need up-to-date API docs for any library.
- Invoke: "use context7 to find docs for [library]"
- Use when you're unsure about API signatures, especially for HTMX, Kysely, or lesser-known libs.

### filesystem
Sandboxed file access outside the project directory. Allowed paths: `~/work/`, `/tmp/`.
- Use for reading files outside the current project tree.
- Do NOT use for files inside the current project - native tools are better.

### linear
Linear issue tracking and project management access.
- Use for ticket lookups, creating/updating issues, reading comments.
- Invoke via MCP tools when Linear issues (`LOT-`, `LIN-`, etc.) are mentioned.

### comfy-mcp
Local/remote ComfyUI workflow execution, model management, and media generation.

### sentry
Sentry error tracking, issue inspection, and documentation search.

## Communication - No Follow-up Offers

- NEVER ask user if they want work explained, visualized, mocked in HTML, or shown in browser. No exceptions.
- Banned phrases: "want me to explain", "want a visual", "want HTML mockup", "shall I show in browser", any variant.
- After task: report result. Stop. No question. No offer.

## GitHub - PR Format

Every PR created via `gh` MUST use a pretty markdown body. Never leave the default one-liner.

Required structure:
- `## Summary` - 1-2 sentences, what and why
- `## Changes` - bullet list, bold file/area names, backtick paths
- `## Test plan` - checklist with `[x]`/`[ ]`, exact commands run plus result

Rules:
- Write in clear normal language.
- No emdash character anywhere (global ban still applies).
- Avoid the word `delete` (any case) inside `gh` commands: the `gh *delete*` permission rule blocks execution. Use remove/trim/drop instead. This applies to the command text, including `--delete-branch` flags and body text passed on the same command line.
- For `gh pr edit` body updates, pass the body inline and keep it free of that word.

## Definition of Done

Before marking complete, verify ALL that apply:
- [ ] Code runs without errors
- [ ] Feature behaves correctly (tested manually or via automation)
- [ ] No regressions introduced
- [ ] Lint/typecheck passes
- [ ] No debug code, console.log, TODO/FIXME left behind
- [ ] Tests added or updated if applicable
- [ ] Nothing committed without explicit user approval
