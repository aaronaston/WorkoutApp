# Gap Analysis: Current State vs Target State (As of 2026-02-22)

Target references:
- `readme.md`
- `docs/features/plan-your-workout-requirements.md`
- `docs/features/plan-your-workout-design.md`
- `docs/architecture/README.md`
- ADR/DDR records in `docs/decisions/`

## 1) Unified "Plan your workout" experience
- Target: one unified input for retrieval + generation with policy-based generation triggers.
- Current: discovery is still search-first with ranked recommendations; no unified plan-orchestrator flow.
- Gap: `DiscoveryOrchestrator`, intent classification, and trigger policy are not implemented.
- Tickets: #34 (primary), #6 (supporting tuning epic)

## 2) LLM generation pipeline
- Target: bounded generation/refinement/validation loop with explicit generated candidates.
- Current: settings and policy toggles exist, but generation path is not wired in UI/services.
- Gap: no production generation service, no refinement thread, no generated candidate lifecycle.
- Tickets: #35

## 3) Templates and variants lifecycle
- Target: copy/edit/derive workflows with provenance-visible customization.
- Current: model types exist (`WorkoutTemplate`, `WorkoutVariant`) but no full template/variant management UX or dedicated stores.
- Gap: template CRUD, variant editing, and provenance-first editor flows are missing.
- Tickets: #36 (lifecycle management), #30 (pre-start edit flow), #33 (artifact/provenance foundation)

## 4) External workout sources
- Target: fetch/cache/import from configurable external sources.
- Current: no importer pipeline or source management UI.
- Gap: network source adapters, import persistence, and provenance management are missing.
- Tickets: #37

## 5) Session timer depth
- Target: EMOM/interval/AMRAP/countdown UX and cues during workout execution.
- Current: overall session stopwatch is primary UI; timer engine exists but is not surfaced as full workout timer controls.
- Gap: timer-mode-specific controls, prompts/cues, and per-block execution UX.
- Tickets: #38

## 6) Logging depth and progress analytics
- Target: robust per-exercise logging, trends, and progress views.
- Current: session history and detail pages exist, but log capture in active sessions is minimal and progress analytics are basic.
- Gap: richer in-session set logging UX and longitudinal progress tooling.
- Tickets: #39

## 7) HealthKit and watch integration
- Target: watch-enhanced session and HealthKit export/retry path.
- Current: preference toggles and message models exist; no end-to-end watch/HealthKit runtime integration.
- Gap: permissions flow, workout export path, and watch coordination runtime.
- Tickets: #11 (epic), #12, #13, #14, #15, #16, #17, #18

## 8) Calendar-aware discovery
- Target: optional calendar context influences recommendations/generation.
- Current: calendar sync toggle exists, but calendar ingestion and scoring inputs are not implemented.
- Gap: calendar data adapter, policy controls in discovery pipeline, explanation coverage.
- Tickets: #1

## 9) Architecture target vs implementation traceability
- Target: architecture docs + decisions should clearly indicate what is implemented.
- Current: this is now improved by adding `docs/current-state.md` and this gap report, but decision files still describe accepted targets more than rollout status.
- Gap: add implementation-status field/process to ADR/DDR lifecycle (recommended follow-up).
- Tickets: #40

## 10) Release automation documentation
- Target: release docs should match actual delivery path.
- Current: local archive script path is accurate; GitHub workflow path was removed.
- Gap: if CI release automation is desired again, a new workflow and docs need to be added together.
- Tickets: #41

## Suggested Next Milestones
1. Land unified discovery orchestration (retrieval + policy-driven generation trigger).
2. Add generated candidate lifecycle (new/refine/save) and provenance chain.
3. Implement template/variant CRUD and editing UX.
4. Deliver timer-mode UI parity with `ExecutionTimer` model capabilities.
5. Implement one integration end-to-end first (Calendar or HealthKit) with deterministic fallback behavior.
