---
name: linear-issues
description: Use when user mentions Linear, LOT-, LIN-, issue, ticket, backlog, triage, or wants to create, read, update, move, comment, or search Linear issues via opencode.
---

# Linear Issues

CRUD Linear issues via Linear MCP tools. Never hardcode IDs. Discover everything at runtime.

## When to Use

- Create, read, update, or comment on a Linear issue.
- Move issue state (Backlog, Todo, In Progress, In Review, Done).
- Find issue by title, team, project, or status.
- User says "ticket", "issue", "LOT-", "in linear".

## NOT Use

- Git-only work with no ticket reference (use git directly).
- Jira, GitHub Issues (different tools).
- Project or document edits unless tied to an issue flow.

## Discovery First (No Hardcoded IDs)

IDs differ per workspace. Never invent `LOT-123`, team UUIDs, project IDs, or status names.

1. `linear_list_teams` (limit 50) -> pick team.
2. `linear_list_issue_statuses` with team name -> exact state names.
3. `linear_list_projects` or `linear_get_project` when project scope needed.
4. `linear_list_issues` with `query`, `team`, `project`, or `state` filters to find target. `P-` prefixed identifiers are projects, not issues.

## Operation Map

| Intent | Tool | Key args |
|---|---|---|
| Search/list | `linear_list_issues` | `query`, `team`, `project`, `state`, `assignee`, `limit` |
| Read full | `linear_get_issue` | `id` (e.g. LOT-5), `includeRelations: true` for links |
| Create | `linear_save_issue` | `team` (required), `title` (required), `description`, `project`, `priority`, `assignee` |
| Update fields/state | `linear_save_issue` | `id` + only changed fields (`description`, `state`, `priority`, `assignee`, `project`) |
| Read comments | `linear_list_comments` | `issueId` |
| Add comment | `linear_save_comment` | `issueId` + `body` (markdown, literal newlines) |
| Status detail | `linear_get_issue_status` | `name` + `team` when exact match needed |

Create requires `team`. Update requires `id`. Never pass `id` on create. Never pass `team` as issue ID.

## Create Flow

1. Discover team (step above). Confirm title + team with user if ambiguous.
2. Call `linear_save_issue` without `id`.
3. Capture returned `id` (e.g. `LOT-7`), `url`, `gitBranchName`.
4. Report all three. Branch name suggestion is `<lowercase-id>-<slug>` (e.g. `lot-7-fix-login`); actual branch creation follows repo convention, never invent the ID before creation returns.

## Update Flow

1. Resolve `id` via search first when user gives title only.
2. For description rewrites, send full markdown body. For state moves, send `state` with exact status name.
3. Verify response shows expected `status` and `updatedAt`.

## Comments

- `body` is markdown with literal newlines, no escape sequences.
- Mention via `@displayName`.
- Never put secrets in comments.

## Common Mistakes

- Hardcoding `LOT-3` or a UUID from another workspace -> always search first.
- Using `P-ENG-123` as `issueId` -> `P-` prefix means project.
- Sending `description` with `\n` literals -> use real newlines.
- Guessing status `"InProgress"` -> read `linear_list_issue_statuses` first, use exact `"In Progress"`.
- Creating branch before issue exists -> create issue, use returned ID.

Keywords: Linear, LOT-, ticket, backlog, triage, issue CRUD, linear_save_issue, linear_list_issues, linear_get_issue, linear_save_comment.
