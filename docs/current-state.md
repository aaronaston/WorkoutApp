# Current Implementation Snapshot (As of 2026-02-23)

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
- Supports unified "Plan your workout" query flow that runs retrieval first and triggers live generation when retrieval confidence is low.
- Debounced plan query execution (~2 seconds) before retrieval/generation trigger.

### Session Execution
- Session lifecycle supported through `SessionStateStore`:
  - start
  - pause/resume
  - end
  - cancel
  - draft persistence and restore across app background/relaunch
- Short-session end guard (under 5 minutes) is implemented as a bottom sheet.
- Ending a session routes users to History.
- Generated workout sessions can be started from discovery and saved into history.

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
- Known bug: "Do Again" for some generated workouts can start an empty session payload (`#44`).

### Templates and Variants
- Templates/variants management entry point exists in discovery ("Manage Templates & Variants").
- Template and variant lifecycle was implemented as first-class app flow (`#36`).

### Settings and LLM Policy Surface
- User preferences persist locally in `UserPreferencesStore` (JSON).
- LLM settings model exists (provider/model/prompt mode/share toggles).
- API key storage uses iOS Keychain.
- Runtime LLM readiness state exists (disabled/missing key/offline/ready).
- Network availability monitor exists to gate LLM availability state.
- Live workout generation uses OpenAI tool/function-calling with bounded retries and deterministic fallback behavior.
- Live generation status and errors are captured in an in-app Debug Logs screen, including "Copy Logs".

## Partially Implemented Areas
- `ExecutionTimer` supports multiple timer modes in model code, but session UI currently displays a single overall elapsed timer and does not expose timer-mode-specific controls.
- HealthKit/watch message models exist, but end-to-end integration flow is not active in the app runtime.
- Live generation reliability/performance still needs improvement for slower provider responses and prompt/tooling quality tuning (`#6`, `#43`, `#44`).

## Operational/Build State
- Simulator policy is arm64-only.
- CLI helper for simulator run/test is `scripts/ios-sim.sh`.
- GitHub Actions workflow for archive was removed; release archive is currently a local scripted flow (`scripts/ci-archive-release.sh`).
