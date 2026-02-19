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
   - `augmented`: keep the user's original intent, then add structured context derived from
     preferences/history/current condition and deterministic clarifications (e.g., typo correction and
     ambiguity expansion) before generation.

Default prompt detail level:
- `augmented`

Runtime policy rules:
- If LLM is disabled, missing credentials, or network is unavailable, block LLM generation and
  show configuration/fallback guidance while preserving rules-based discovery.
- Prompt assembly must be allow-list based from enabled categories only.
- Discovery explanation UI must indicate whether context was summarized, raw, or augmented when showing
  generated workout rationale.
- Do not require an additional "confirm data sharing" interstitial before generation.
- Apply best-effort deterministic identifier scrubbing before prompt send for obvious direct
  identifiers (emails, phone numbers, long numeric IDs, likely addresses, person-name headers),
  while acknowledging this is not guaranteed PII removal.
- `shareTemplatesAndVariants` controls whether the app includes the user's local templates/variants
  as prompt context for LLM generation; it does not mean sharing workouts with other users.
- Template/variant context should be retrieved conditionally for relevance, not eagerly attached to
  every prompt.

Bounded orchestration flow:
1) Build augmented prompt from user intent + allowed context.
2) LLM `generate_workout` function call returns structured workout plan candidate.
3) Deterministic retrieval (`retrieve_context`) finds relevant templates/rules/preferences using:
   - metadata/rule prefilter (equipment, duration, location, injury flags, etc.)
   - similarity scoring (vector/semantic) on prefiltered candidates.
4) LLM `refine_workout` function call receives candidate + retrieved context only.
5) Deterministic validation (`validate_workout`) enforces hard constraints; one repair attempt max.
6) Final output includes machine-readable provenance for explanation UI.

Function-calling contract (initial):
- `generate_workout(input) -> WorkoutPlanDraft`
- `retrieve_context(input, candidate) -> RetrievedContext[]`
- `refine_workout(candidate, context) -> WorkoutPlanDraft`
- `validate_workout(candidate, hardRules) -> ValidationResult`

## Alternatives
- Option A: Single "share all" toggle with no category controls
  - Pros: simpler UI and implementation
  - Cons: poor privacy control granularity, harder trust calibration
- Option B: Category toggles + detail level including augmented mode (chosen)
  - Pros: explicit data policy, clearer user control, easy policy testing
  - Cons: larger settings surface and more validation states
- Option C: Single-pass generation with all templates attached
  - Pros: simplest prompt assembly
  - Cons: token-heavy, noisier prompts, weaker relevance control
- Option D: Bounded two-round generation with conditional retrieval (chosen)
  - Pros: higher relevance, lower token waste, deterministic guardrails
  - Cons: more orchestration and test surface

## Consequences
- Extend preferences domain with a dedicated LLM settings structure.
- Add a prompt-context builder that enforces category filtering and detail-level projection.
- Add augmented-context assembly (intent-preserving rewrite + preference/history/condition
  enrichment) as a first-class step before LLM invocation.
- Add UI/logic states for missing API key, disabled LLM, and offline unavailability.
- Recommendation engine remains independent of LLM settings except for deciding whether generated
  candidates are available.
- Default `shareTemplatesAndVariants` to enabled.
- Add retrieval index + hard-rule validator modules for orchestration steps.
- Add loop guardrails (`maxRounds=2`, `maxRepairAttempts=1`) and provenance logging.

## References
- `readme.md`
- `ios/WorkoutApp/WorkoutApp/UserPreferences.swift`
- wa-pac
- wa-3o4
