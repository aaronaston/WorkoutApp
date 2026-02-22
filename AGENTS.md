# Agent Instructions

## Tracking System

This repo now uses GitHub Issues + GitHub Projects for task tracking.
Do not use `bd` / Beads for new work.

Legacy Beads files may still exist for historical context, but they are read-only.

## Quick Reference

- Find ready work: `gh issue list --state open --label "status:ready"`
- View issue details: `gh issue view <number>`
- Start work: assign yourself + set status labels
- Close work: `gh issue close <number> --comment "Completed in <commit-or-pr>"`

Recommended labels:

- Type: `type:feature`, `type:bug`, `type:task`
- Priority: `priority:P0`, `priority:P1`, `priority:P2`, `priority:P3`, `priority:P4`
- Status: `status:ready`, `status:in-progress`, `status:blocked`

## GitHub Workflow Norms

- One issue per branch when practical.
- Branch naming: `<agent>/<issue-or-scope>` (example: `agent-a/123-hybrid-retrieval`).
- Link issue in commits/PRs using `#<issue-number>`.
- Record blockers directly on the issue and apply `status:blocked`.
- Track sequencing with issue links and explicit `Depends on #<issue>` in issue body.

## Multi-Agent Workflow (Git Worktrees)

Goal: isolate agent changes while coordinating integration to `main`.

Default for this repo: work directly on `main` unless the user explicitly asks for a worktree-based flow.
Use the worktree process below when parallel agent isolation is requested.

Rules:

- Do not work in the main worktree except for integration tasks when running in worktree mode.
- Each agent uses its own worktree under `.worktrees/`.
- One integrator lands to `main` at a time (manual serialization).

One-time setup (from repo root):

```bash
git worktree add .worktrees/agent-a
git worktree add .worktrees/agent-b
```

Agent bootstrap (recommended):

```bash
scripts/agent-bootstrap.sh agent-a 123
```

Per-agent daily flow:

```bash
cd .worktrees/agent-a
source .agent-env
gh issue view "$ISSUE_REF"
git status
# work, test, commit
git push -u origin "$(git branch --show-current)"
```

Safety checks:

```bash
git worktree list
git status -sb
```

## Integration to Main (No PR, Same Machine)

Coordination rule: before integrating, confirm no other agent is currently integrating.

From agent worktree:

```bash
git fetch origin
git pull --rebase origin main
# run tests/build locally
git push
```

From main worktree:

```bash
git fetch origin
git checkout main
git pull --rebase origin main
git merge --ff-only agent-a/<issue-or-scope>
git push origin main
```

Then announce integration complete so another agent can proceed.

## Session Completion Checklist

Work is not complete until changes are pushed and remote state is current.

1. Update issue status/notes in GitHub (`status:in-progress` -> remove + close issue when done).
2. Run quality gates for changed code (tests/lint/build).
3. `git status` (verify intended files only).
4. `git add <files>` and commit.
5. `git pull --rebase`.
6. `git push`.
7. `git status -sb` (confirm branch is up to date with `origin`).
8. Leave handoff notes on the issue (what changed, risks, next steps).

Critical rules:

- Never leave completed work unpushed.
- If push fails, resolve and retry until push succeeds.
- If follow-up work remains, open or update a GitHub issue before ending.

## Bootstrap Source of Truth

Put repo-specific process and norms in `AGENTS.md`.
Use Codex Skills only when the same workflow must be reused across multiple repositories.
