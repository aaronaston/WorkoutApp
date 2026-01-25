#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/agent-bootstrap.sh <agent-name> [issue-id]

Creates a per-agent git worktree and a branch named <agent-name>/<issue-id>.
If issue-id is omitted, branch defaults to <agent-name>/wip.

Examples:
  scripts/agent-bootstrap.sh agent-a bd-1234
  scripts/agent-bootstrap.sh agent-b
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

agent_name=${1:-}
issue_id=${2:-wip}

if [[ -z "$agent_name" ]]; then
  usage
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
worktree_dir="$repo_root/.worktrees/$agent_name"
branch_name="$agent_name/$issue_id"

if [[ -d "$worktree_dir" ]]; then
  echo "Worktree already exists: $worktree_dir"
else
  git worktree add -b "$branch_name" "$worktree_dir"
  echo "Created worktree: $worktree_dir"
fi

# Set BD_ACTOR based on worktree name for consistent attribution.
cat <<EOF > "$worktree_dir/.bd-env"
export BD_ACTOR="$agent_name"
export BEADS_DB="$repo_root/.beads/beads.db"
EOF

echo "Next steps:"
cat <<EOF
  cd "$worktree_dir"
  source .bd-env           # sets BD_ACTOR=$agent_name (or export BD_ACTOR=$agent_name)
  bd ready
  bd slot set "$agent_name" role active   # optional
  bd merge-slot check            # verify merge-slot exists/availability
  # work + commit
EOF
