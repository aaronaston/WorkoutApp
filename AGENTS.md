# Agent Instructions

## Issue Tracking

This project uses **bd (beads)** for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**Quick reference:**
- `bd ready` - Find unblocked work
- `bd create "Title" --type task --priority 2` - Create issue
- `bd close <id>` - Complete work
- `bd sync` - Sync with git (run at session end)

For full workflow details: `bd prime`

## Multi-Agent Workflow (Git Worktrees + Merge Slots)

**Goal:** isolate code changes per agent while sharing the same Beads database.

**Rules:**
- Do not work in the main worktree except for integration tasks.
- Each agent uses their own git worktree directory.
- Use `bd merge-slot` to serialize landing to `main`.

**One-time setup (run from repo root):**

```bash
git worktree add .worktrees/agent-a
git worktree add .worktrees/agent-b
```

**Agent bootstrap (recommended):**

```bash
scripts/agent-bootstrap.sh agent-a bd-1234
```

**Per-agent daily flow:**

```bash
cd .worktrees/agent-a
source .bd-env           # sets BD_ACTOR=agent-a (or export BD_ACTOR=agent-a)
bd ready
bd slot claim agent-a   # optional: mark active agent
git checkout -b agent-a/<issue>
# work, commit locally
```

**Landing (serialized):**

```bash
bd merge-slot claim
git pull --rebase
bd sync
git push
bd merge-slot release
```

**Cleanup when done (optional but recommended):**

```bash
git worktree remove .worktrees/agent-a
git branch -d agent-a/<issue>
git worktree prune
```

## Codex Sandbox Note

Beads may fail to start or lock under Codex sandboxing. Launch Codex with:
`codex --ask-for-approval on-request --sandbox danger-full-access`
to ensure bd works as expected.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds. Always run a build after any code change; build failures mean the task is not complete.
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:

   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```

5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
