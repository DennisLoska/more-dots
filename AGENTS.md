<!-- caveman-begin -->
Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the), filler (just/really/basically), pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: [thing] [action] [reason]. [next step].
- Not: "Sure! I'd be happy to help you with that."
- Yes: "Bug in auth middleware. Fix:"

Switch level: /caveman lite|full|ultra|wenyan
Stop: "stop caveman" or "normal mode"

Auto-Clarity: drop caveman for security warnings, irreversible actions, user confused. Resume after.

Boundaries: code/commits/PRs written normal.
<!-- caveman-end -->

## Verification Protocol

Before declaring any task complete, you MUST verify:
- Run/build the code — did it work?
- Trigger the exact feature changed — did it behave correctly?
- Check for error messages in output
- Would I bet actual money this works?

Red flags — never say these:
- "This should work now" (especially 2nd+ time on same issue)
- "Try it now" (without trying it yourself first)
- "The logic is correct so..." (logic is not proof)

## Tool Preferences

- Use `rg` (ripgrep) instead of `grep` for code searching
- Use `fd` instead of `find` for file searching
- Prefer `bun` over `npm` or `yarn` for JavaScript/TypeScript projects

## Security & Boundaries

- NEVER read `.env`, `.env.*` (except `.env.example`), `.zshrc`, `.zsh_history`
- NEVER printenv, sudo, or access secrets
- NEVER gh delete, gh org, gh secret operations
- NEVER rm -rf anything
- ALWAYS ask before installing npm/bun packages
- External directory access: `~/work/**`, `~/.config/opencode/**`, `/tmp/**` are always allowed

## Plugins

### opencode-mem
Persistent memory across sessions. Stores learnings about projects, preferences, and decisions.
- Invoke: reference it naturally — "remember that..." or "what do you know about..."
- It auto-recalls relevant context per-session.

### cc-safety-net
Blocks destructive git/filesystem commands before they execute. Never try to bypass it — if blocked, step back and confirm with the user.

### caveman (local plugin)
Provides output compression and slash commands.
- `/caveman [lite|full|ultra|wenyan]` — sets compression level
- `/caveman-commit` — generate terse conventional commit message
- `/caveman-review` — one-line PR review findings
- `/caveman:compress <file>` — compress a memory file into caveman format
- Also activated by saying "caveman mode", "talk like caveman", "less tokens please"

### loop (local plugin)
Autonomous dev loop. Re-runs task prompt until DONE or max iterations.
- `/loop <task> [--max-iterations N] [--compact-every N]` — start loop
- `/cancel-loop` — cancel active loop
- `/loop-status` — check loop state
- AI signals completion with `<promise>DONE</promise>`
- Auto-compacts context every N iterations (default 5)
- Default max 25 iterations

### superpowers (obra/superpowers)
Full development methodology framework. Provides composable skills.
- Auto-activates when relevant tasks are detected
- Invoke explicitly: `use skill superpowers/<skill-name>`

## MCP Servers

### context7
Fresh library documentation — use when you need up-to-date API docs for any library.
- Invoke: "use context7 to find docs for [library]"
- Use when you're unsure about API signatures, especially for HTMX, Kysely, or lesser-known libs.

### filesystem
Sandboxed file access outside the project directory. Allowed paths: `~/work/`, `/tmp/`.
- Use for reading files outside the current project tree.
- Do NOT use for files inside the current project — native tools are better.

### atlassian
Jira and Confluence access.
- Use for ticket lookups, searching Confluence docs.
- Invoke via MCP tools when Jira issues are mentioned.

### caveman-shrink
MCP middleware that compresses MCP tool descriptions. Transparent — no manual invocation needed.

## Skills (Superpowers)

Load via `use skill superpowers/<name>`:

### Design & Planning
- `brainstorming` — Socratic refinement of rough ideas into validated designs
- `writing-plans` — decompose specs into bite-sized tasks with file paths
- `executing-plans` — batch execute tasks with verification checkpoints

### Development
- `test-driven-development` — RED-GREEN-REFACTOR cycle
- `subagent-driven-development` — parallel subagents with two-stage review
- `using-git-worktrees` — isolated branches for parallel dev

### Review & Ship
- `requesting-code-review` — pre-merge checklist before asking for review
- `receiving-code-review` — process and apply review feedback
- `finishing-a-development-branch` — PR merge decision workflow
- `dispatching-parallel-agents` — fan out work to multiple agents

### Debugging
- `systematic-debugging` — 4-phase root cause: reproduce → hypothesize → isolate → fix
- `verification-before-completion` — confirm fix works before moving on

### Meta
- `writing-skills` — create new skills with TDD methodology
- `using-superpowers` — overview of the entire skills system

## Skills

### loop
Autonomous dev loop with auto-continuation, compaction, and cancellation.
- `/loop <task> [--max-iterations N] [--compact-every N]`
- AI emits `<promise>DONE</promise>` to signal completion
- Load: `use skill loop` or just reference it naturally

## Cavecrew Agents (subagents)

### @cavecrew-investigator
Read-only code locator. Use for: "where is X defined", "what calls Y", "list all uses of Z".
Returns file:line tables. Refuses to suggest fixes.

### @cavecrew-reviewer
Diff/branch/file reviewer. One-line findings with severity tags.
Use for: "review this PR", "review my diff", "audit this file".

### @cavecrew-builder
Surgical 1-2 file editor. Typo fixes, single-function rewrites, mechanical renames.
Max 2 files. No new abstractions. No drive-by refactors.

## Definition of Done

Before marking complete, verify ALL that apply:
- [ ] Code runs without errors
- [ ] Feature behaves correctly (tested manually or via automation)
- [ ] No regressions introduced
- [ ] Lint/typecheck passes
- [ ] No debug code, console.log, TODO/FIXME left behind
- [ ] Tests added or updated if applicable
- [ ] Nothing committed without explicit user approval
