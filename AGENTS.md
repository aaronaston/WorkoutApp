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
- Treat `main` as the sync target for `.beads/issues.jsonl` (no separate sync branch).

**One-time setup (run from repo root):**

```bash
git worktree add .worktrees/agent-a
git worktree add .worktrees/agent-b
```

**One-time merge-slot setup (run once per rig):**

```bash
bd merge-slot create
```

This creates `<prefix>-merge-slot` (label `gt:slot`) used to serialize merges.

**Agent bootstrap (recommended):**

```bash
scripts/agent-bootstrap.sh agent-a bd-1234
```

**Per-agent daily flow:**

```bash
cd .worktrees/agent-a
source .bd-env           # sets BD_ACTOR=agent-a (or export BD_ACTOR=agent-a)
bd ready
bd slot set "$BD_ACTOR" role active   # optional: mark active agent
git checkout -b agent-a/<issue>
# work, commit locally
```

**Safety checks (run anytime if unsure):**

```bash
git worktree list            # verify you're in a non-main worktree
```

**Landing (serialized):**

```bash
bd merge-slot check         # verify slot exists/availability
bd merge-slot acquire --holder "$BD_ACTOR"
git pull --rebase
git push
bd merge-slot release --holder "$BD_ACTOR"
```

### Current status (2026-02-19): merge-slot acquire/release bug
- `bd merge-slot acquire` currently fails in this repo with:
  `failed to update issue: invalid field for update: holder`
- Until fixed, do **not** rely on `bd merge-slot acquire/release`.
- Fallback: serialize merges manually (one integrator at a time) using the local integration steps below.
- Coordination rule: before integrating, confirm no other agent is actively integrating to `main`.

**Local integration to main (no PR, same machine):**

From agent worktree (your feature branch):

```bash
source .bd-env
bd merge-slot check
# merge-slot acquire is currently broken; coordinate manually, one integrator at a time
git pull --rebase origin main
```

From the main worktree (local main branch):

```bash
git fetch origin
git checkout main
git pull --rebase origin main
git merge --ff-only agent-a/<issue>
bd sync
git push origin main
```

Then back in the agent worktree:

```bash
# merge-slot release is currently broken; announce integration complete to other agents
```

**Command context (where to run what):**

Assumptions:
- You have a per-agent worktree (e.g. `.worktrees/agent-a`).
- You ran `source .bd-env` in that worktree.

```text
1) bd merge-slot check / acquire / release
   - CWD: agent worktree (e.g. .worktrees/agent-a)
   - Branch: agent-a/<issue>
   - DB: uses BEADS_DB from .bd-env (shared main repo DB)
   - NOTE: acquire/release currently fail with holder-field error; use manual serialization.

2) git pull --rebase origin main
   - CWD: agent worktree
   - Branch: agent-a/<issue> (rebasing your branch on origin/main)

3) bd sync
   - CWD: main worktree
   - Branch: main
   - Writes: .beads/issues.jsonl to main

4) git push -u origin agent-a/<issue>
   - CWD: agent worktree
   - Branch: agent-a/<issue>

5) Main worktree
   - Use for final integration and bd sync.
```

**Cleanup when done (optional but recommended):**

```bash
git worktree remove .worktrees/agent-a
git branch -d agent-a/<issue>
git worktree prune
```

**Notes on worktree locations:**
- Worktree working directories can live anywhere (this repo uses `.worktrees/`).
- Git’s metadata for worktrees lives under `.git/worktrees/`.
- Updates to `.beads/issues.jsonl` are shared across worktrees and will appear in the main repo’s `.beads/` directory by design.

## Beads Data Model (DB vs JSONL vs Daemon)

**Source of truth:** the SQLite DB at `.beads/beads.db` in the main repo root.  
**Sync artifact:** `.beads/issues.jsonl` (exported from the DB and committed to `main`).  
**Daemon:** a convenience layer that keeps the DB and JSONL fresh; it does not change the data model.

**Recommended multi-agent setup (worktrees):**
- Use a single shared DB (the main repo’s `.beads/beads.db`) from every worktree.
- Set `BD_ACTOR` per agent for audit trail + merge-slot ownership.
- Prefer direct mode in worktrees; run `bd sync` from the main worktree to keep `main` updated.

**Suggested per-worktree `.bd-env`:**

```bash
export BD_ACTOR=agent-a
export BEADS_DB=/Users/aaron/development/WorkoutApp/.beads/beads.db
```

**Why this matters:** if the DB path isn’t pinned, beads may auto-discover a different
database per worktree or attach to a daemon started from the main repo, leading to
surprising state. Pinning `BEADS_DB` keeps all agents in sync.

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
