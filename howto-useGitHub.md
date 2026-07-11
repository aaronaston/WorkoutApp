# How to Use GitHub for Project Work

This document describes a practical GitHub workflow for managing work with GitHub Issues, labels, branches, and optional Git worktrees. It is written to be reusable across projects.

## Overview

Use GitHub Issues as the source of truth for planned and active work.
Use labels to track issue type, release target, and workflow state.
Use GitHub Projects to organize issues at the planning level if your team uses them.

Avoid maintaining a second active task tracker unless the project explicitly requires one.

## Core Principles

- Keep one primary ticket for each unit of work when practical.
- Update issue status before and after implementation so current work is visible.
- Record blockers on the issue instead of only in chat.
- Push finished work before ending a session.
- Leave handoff notes on the issue so the next person has context.

## Recommended Labels

Use a consistent label taxonomy. A simple structure:

### Type

- `type:feature`
- `type:bug`
- `type:task`

### Release

- `release:v1`
- `release:vNext`

Adjust release names to match your roadmap.

### Status

- `status:ready`
- `status:in-progress`
- `status:in-review`
- `status:blocked`

## Ticket Lifecycle

Use this status flow:

1. `status:ready`
2. `status:in-progress`
3. `status:in-review`
4. closed

Expected behavior at each step:

- `status:ready`: work is defined and available to start
- `status:in-progress`: someone is actively implementing it
- `status:in-review`: implementation and tests are complete, waiting for validation or merge
- `status:blocked`: work cannot proceed until a dependency or decision is resolved

Before starting implementation:

- assign the issue
- remove `status:ready` if present
- add `status:in-progress`

After implementation and tests are complete:

- remove `status:in-progress`
- add `status:in-review`

When accepted or merged:

- close the issue
- remove stale workflow labels if your team keeps issue labels clean after completion

## Useful GitHub CLI Commands

Find ready work:

```bash
gh issue list --state open --label "status:ready"
```

View issue details:

```bash
gh issue view <number>
```

Close an issue with a completion note:

```bash
gh issue close <number> --comment "Completed in <commit-or-pr>"
```

If an issue comment or close comment may contain backticks or special characters, avoid inline shell quoting. Use `--body-file -` with a single-quoted heredoc:

```bash
gh issue comment <number> --body-file - <<'EOF'
Summary of what changed

- key change
- risk or follow-up
EOF
```

## Branching Conventions

Recommended defaults:

- one issue per branch when practical
- branch names should include the issue number or work scope
- reference the issue in commits and pull requests using `#<issue-number>`

Example branch naming:

```text
agent-a/123-hybrid-retrieval
dev/456-login-fix
```

Use a naming prefix that fits your team, but keep the issue number in the branch name whenever possible.

## Managing Dependencies and Blockers

If one issue depends on another:

- note the dependency in the issue body using `Depends on #<issue>`
- keep sequencing visible in GitHub rather than only in local notes

If work is blocked:

- comment on the issue with the blocker
- add `status:blocked`
- remove `status:blocked` when work can resume

## Session Completion Checklist

Work should not be considered complete until GitHub and git state both reflect reality.

1. Update the issue status and notes in GitHub.
2. Run the relevant quality checks for the code you changed.
3. Run `git status` and confirm only intended files changed.
4. Stage and commit the work.
5. Run `git pull --rebase`.
6. Push the branch.
7. Run `git status -sb` and confirm the branch is up to date with remote.
8. Leave handoff notes on the issue with what changed, risks, and next steps.

Critical rules:

- Never leave completed work unpushed.
- If push fails, resolve it and retry before ending the session.
- If follow-up work remains, open or update a GitHub issue for it.

## Optional Multi-Agent Workflow with Git Worktrees

Use this only when multiple developers or coding agents need isolated working directories on the same machine.

### Rules

- each agent gets its own worktree
- avoid using the main worktree for feature implementation when worktree mode is active
- only one person should integrate to `main` at a time

### Setup

From the repository root:

```bash
git worktree add .worktrees/agent-a
git worktree add .worktrees/agent-b
```

### Per-Agent Flow

```bash
cd .worktrees/agent-a
gh issue view <number>
git status
# work, test, commit
git push -u origin "$(git branch --show-current)"
```

### Safety Checks

```bash
git worktree list
git status -sb
```

### Integration Back to Main

Before integrating, confirm no one else is currently merging to `main`.

From the agent worktree:

```bash
git fetch origin
git pull --rebase origin main
# run tests/build locally
git push
```

From the main worktree:

```bash
git fetch origin
git checkout main
git pull --rebase origin main
git merge --ff-only agent-a/<issue-or-scope>
git push origin main
```

Then communicate that integration is complete so the next person can proceed.

## Recommended Project Setup

For reuse across repositories:

- keep project-specific workflow rules in `AGENTS.md` or equivalent repo instructions
- keep reusable workflow guidance in a shared doc like this one
- standardize labels early so status reporting stays clean

## Quick Start Summary

If you want the shortest version of the process:

1. Pick a `status:ready` issue.
2. Assign it and move it to `status:in-progress`.
3. Create a branch tied to that issue.
4. Implement, test, commit, and push.
5. Move the issue to `status:in-review`.
6. Close it after acceptance or merge.
