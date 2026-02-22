#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/agent-bootstrap.sh <agent-name> [issue-id]

Creates a per-agent git worktree and a branch named <agent-name>/<issue-id>.
If issue-id is omitted, branch defaults to <agent-name>/wip.

Examples:
  scripts/agent-bootstrap.sh agent-a 123
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
normalized_issue=$(echo "$issue_id" | sed -E 's/^#//' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')
if [[ -z "$normalized_issue" ]]; then
  normalized_issue="wip"
fi
branch_name="$agent_name/$normalized_issue"

if [[ -d "$worktree_dir" ]]; then
  echo "Worktree already exists: $worktree_dir"
else
  git worktree add -b "$branch_name" "$worktree_dir"
  echo "Created worktree: $worktree_dir"
fi

# Store per-agent defaults for consistent shell context.
cat <<EOF > "$worktree_dir/.agent-env"
export AGENT_NAME="$agent_name"
export ISSUE_REF="$normalized_issue"
export REPO_ROOT="$repo_root"
EOF

echo "Next steps:"
cat <<EOF
  cd "$worktree_dir"
  source .agent-env
  gh issue view "$normalized_issue"   # if this is a GitHub issue number
  git status -sb
  # work + commit
EOF
