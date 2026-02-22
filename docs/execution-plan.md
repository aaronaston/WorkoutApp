# Execution Plan

Date: 2026-02-22

This is the working path to close the documented current-vs-target gaps in `docs/gap-analysis-current-vs-target.md`.

## Phase 1: Foundations
1. `#21` Add user preferences model and storage (if any migration gaps remain).
2. `#33` Persisted workout artifacts + provenance model + session snapshots.
3. `#40` Decision implementation-status governance.

Exit criteria:
- Persistence contracts are stable and documented.
- Decision docs have clear implementation tracking.

## Phase 2: Editable Workout Lifecycle
1. `#30` Pre-start workout editing flow.
2. `#36` Template and variant management lifecycle.

Dependencies:
- `#33` is foundational for provenance/artifact behavior.

Exit criteria:
- Users can edit/save/manage workout artifacts end-to-end.

## Phase 3: Discovery Orchestration
1. `#34` Unified Plan-your-workout orchestration.
2. `#35` LLM generated-candidate pipeline with refinement/validation.
3. `#6` Discovery/search tuning.

Exit criteria:
- Unified input flow.
- Retrieval-first ordering with policy-driven generation.
- Explainable generated candidates.

## Phase 4: Execution and History Depth
1. `#38` Timer-mode UX parity with `ExecutionTimer`.
2. `#39` In-session logging and progress analytics.

Exit criteria:
- Timer modes are fully usable in session UX.
- History reflects meaningful progression from structured logs.

## Phase 5: Integrations
1. `#1` Calendar integration for discovery context.
2. `#37` External workout source import pipeline.
3. `#11` HealthKit/watch epic with child tasks `#12`-`#18`.

Exit criteria:
- Integrations are opt-in and resilient.
- Core behavior remains strong with graceful fallback when unavailable.

## Phase 6: Optional Release Automation
1. `#41` Reintroduce optional CI release archive workflow.

Exit criteria:
- CI archive path works and release docs match actual operations.

## Suggested Immediate Next Tickets
1. `#33`
2. `#30`
3. `#34`
