# Execution Plan

Date: 2026-02-26

Execution planning is now tracked in GitHub Issues to avoid drift.

## Source of Truth
- Milestone: `First releasable`
- Labels: `release:v1`, `release:vNext`, `status:*`, `type:*`
- Dependencies: `Depends on #<issue>` in issue bodies
- Release gate: issue `#51`

## How to Work the Plan
1. Filter open issues by milestone `First releasable` and label `release:v1`.
2. Prioritize issues with no unmet `Depends on` blockers.
3. Move issue status through `status:ready` -> `status:in-progress` -> `status:in-review` -> close.
4. Keep deferrals in `release:vNext`.

## Notes
- Architecture and product intent remain documented in `docs/`.
- Ticket sequencing and execution state are managed in GitHub.
