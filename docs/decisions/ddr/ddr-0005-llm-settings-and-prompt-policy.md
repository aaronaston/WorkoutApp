# DDR-0005: Define LLM settings model and prompt-sharing policy

## Status
Accepted

## Date
2026-02-19

## Context
The app requires user-configurable LLM settings (`wa-pac`) while preserving explainable discovery
(`wa-3o4`). We need a concrete settings model that controls prompt scope and graceful degradation
without coupling deterministic ranking to network state.

## Decision
Adopt a settings-driven LLM policy with three layers:

1) Provider configuration and availability:
   - `llmEnabled`: master switch.
   - `provider`: provider identifier (initially OpenAI).
   - `modelID`: selected model string.
   - API key stored in Keychain and referenced by settings state (not persisted in plain prefs).

2) Share policy categories (category-level toggles):
   - `shareCalendarContext`
   - `shareHistorySummaries`
   - `shareExerciseLogs`
   - `shareUserNotes`
   - `shareTemplatesAndVariants`

3) Prompt detail level:
   - `summary`: send normalized/aggregated context.
   - `raw`: send minimally transformed source text for allowed categories.

Runtime policy rules:
- If LLM is disabled, missing credentials, or network is unavailable, block LLM generation and
  show configuration/fallback guidance while preserving rules-based discovery.
- Prompt assembly must be allow-list based from enabled categories only.
- Discovery explanation UI must indicate whether context was summarized or raw when showing
  generated workout rationale.

## Alternatives
- Option A: Single "share all" toggle with no category controls
  - Pros: simpler UI and implementation
  - Cons: poor privacy control granularity, harder trust calibration
- Option B: Category toggles + detail level (chosen)
  - Pros: explicit data policy, clearer user control, easy policy testing
  - Cons: larger settings surface and more validation states

## Consequences
- Extend preferences domain with a dedicated LLM settings structure.
- Add a prompt-context builder that enforces category filtering and detail-level projection.
- Add UI/logic states for missing API key, disabled LLM, and offline unavailability.
- Recommendation engine remains independent of LLM settings except for deciding whether generated
  candidates are available.

## References
- `readme.md`
- `ios/WorkoutApp/WorkoutApp/UserPreferences.swift`
- wa-pac
- wa-3o4
