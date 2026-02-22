# Current Implementation Snapshot (As of 2026-02-22)

This document describes what is implemented in the codebase today.
Use this alongside target-state docs:
- `readme.md` (product vision/requirements)
- `docs/features/plan-your-workout-requirements.md`
- `docs/features/plan-your-workout-design.md`
- `docs/architecture/README.md`

## Product Surface
- iOS SwiftUI app with four tabs: Discover, Session, History, Settings.
- Offline-first local operation for core flows.
- No user accounts or cloud sync.

## Implemented Areas

### Discovery
- Loads bundled Markdown workouts from `resources/workouts/*.md`.
- Parses workouts via `KnowledgeBaseLoader` + `WorkoutMarkdownParser`.
- Supports search with keyword + semantic scoring in `WorkoutSearchIndex`.
- Supports recommendation ranking via `WorkoutRecommendationEngine`.
- Supports filter chips (equipment, duration, location).
- Shows recommendation reasons in list/detail views.

### Session Execution
- Session lifecycle supported through `SessionStateStore`:
  - start
  - pause/resume
  - end
  - cancel
  - draft persistence and restore across app background/relaunch
- Short-session end guard (under 5 minutes) is implemented as a bottom sheet.
- Ending a session routes users to History.

### History
- Stores completed sessions in `WorkoutSessionStore` (JSON under Application Support).
- History supports:
  - chronological sort (default)
  - most frequent sort
  - search over prior sessions
  - semantic-assisted matching via local search index
- Session detail supports:
  - Do Again
  - Resume
  - Adjust + Start
- Resume uses session ID upsert semantics (single history record is updated, not duplicated).

### Settings and LLM Policy Surface
- User preferences persist locally in `UserPreferencesStore` (JSON).
- LLM settings model exists (provider/model/prompt mode/share toggles).
- API key storage uses iOS Keychain.
- Runtime LLM readiness state exists (disabled/missing key/offline/ready).
- Network availability monitor exists to gate LLM availability state.

## Partially Implemented Areas
- `ExecutionTimer` supports multiple timer modes in model code, but session UI currently displays a single overall elapsed timer and does not expose timer-mode-specific controls.
- Domain models for templates/variants/external/generated workouts exist, but first-class create/edit/manage flows are not yet implemented in UI/storage.
- HealthKit/watch message models exist, but end-to-end integration flow is not active in the app runtime.

## Operational/Build State
- Simulator policy is arm64-only.
- CLI helper for simulator run/test is `scripts/ios-sim.sh`.
- GitHub Actions workflow for archive was removed; release archive is currently a local scripted flow (`scripts/ci-archive-release.sh`).
