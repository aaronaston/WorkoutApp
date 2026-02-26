# Plan Your Workout - Design

## Status
- Draft technical design aligned to requirements in `docs/features/plan-your-workout-requirements.md`.

## Objectives
- Unify retrieval and generation under one discovery input.
- Preserve deterministic retrieval priority.
- Introduce controlled generation triggers (intent/low-confidence/detent).
- Support conversational refinement and optional persistence.
- Make all LLM interactions stream-first with interrupt/cancel support.

## Feature Decomposition

### Feature A - Unified Discovery Surface
- Rename discovery input to **Plan your workout**.
- Introduce `DiscoveryMode` UI state:
  - `retrievalOnly`
  - `retrievalPlusGeneration`
  - `generationFirst`
- Add list sectioning model:
  - `matchedWorkouts: [RankedWorkout]`
  - `generatedWorkouts: [GeneratedCandidate]`

### Feature B - Hybrid Retrieval + Confidence
- Add retrieval adapter combining:
  - lexical search (`WorkoutSearchIndex`)
  - semantic similarity (existing embedder path)
- Compute normalized confidence score for top-N matches.
- Expose `retrievalConfidence` for generation policy.

### Feature C - Intent and Generation Policy
- Add lightweight intent classifier (`searchlike` vs `generative`).
- Policy engine decides generation timing:
  - searchlike: generate on bottom-detent, and optionally when confidence below threshold
  - generative: generate immediately + on bottom-detent

### Feature D - Generation and RAG Context Assembly
- Add `DiscoveryGenerationService` with pipeline:
  1. Gather query
  2. Build context packets (preferences/history/logs/notes/templates)
  3. Generate up to 5 candidates
  4. Return candidates with explanation metadata
- Context summaries can be built with LLM summarization calls before generation.
- Cache context summary artifacts for a short TTL to avoid repeated preprocessing calls.
- Generation responses stream partial output to the UI as tokens/chunks arrive.
- Initial generation and detent-triggered additional generation both use the same stream-first contract.

### Feature E - Refinement Loop and Persistence
- Selecting any workout opens refinement panel/thread.
- Each follow-up prompt produces revised candidate tied to parent workout/candidate.
- Refinement responses stream incrementally and can be interrupted/cancelled by the user.
- Model provenance:
  - `baseWorkoutID`
  - `revisionPrompt`
  - `revisionIndex`
- Save behavior:
  - unsaved candidates remain ephemeral
  - user can star/save any generated or revised candidate

### Feature F - Fallback and Degradation
- If LLM unavailable, disable generation path and keep retrieval results only.
- Keep UI responsive; avoid hard-error blocking in v1.

### Feature G - Intensity Policy Track (Follow-on)
- Extend session completion with user-reported actual intensity.
- Extend preferences with target weekly intensity policy.
- Feed intensity balance signal into recommendation and generation context.

## UX Behavior
- Existing matches are always rendered first.
- Generated results are rendered below, labeled `New`.
- Bottom detent behavior:
  - pull/push beyond list bottom triggers `loadMoreGenerated()`.
- For generative intent queries, generation begins with initial request.
- Refinement view supports iterative prompt adjustments before session start.

## Data Model Additions
- `GeneratedCandidate`
  - `id`, `title`, `summary`, `content`, `explanation`, `createdAt`
  - `originQuery`, `baseWorkoutID?`, `isSaved`
- `DiscoveryQuerySession`
  - tracks query, intent classification, confidence, generation batches
- `RefinedWorkoutRevision`
  - links revision chain for conversation-based tuning

## Service Interfaces (Proposed)
- `DiscoveryOrchestrator.plan(query: String) async -> DiscoveryResult`
- `HybridRetrievalService.search(query: String) async -> RetrievalResult`
- `IntentClassifier.classify(query: String) async -> DiscoveryIntent`
- `GenerationPolicy.shouldGenerate(...) -> GenerationDecision`
- `GenerationService.generate(...) async -> [GeneratedCandidate]`

Streaming contract (applies to all user-facing LLM operations):
- `GenerationService.streamGenerate(...) async -> AsyncThrowingStream<GenerationChunk, Error>`
- `GenerationService.cancelGeneration(requestID: String)`

## Rollout Plan
1. Build unified UI + retrieval confidence plumbing.
2. Add generation policy and bottom-detent trigger.
3. Add generation service with augmented context.
4. Add refinement conversation and save workflow.
5. Add follow-on intensity policy feature.

## Risks and Mitigations
- Cost/latency from multiple context-prep LLM calls:
  - use short-lived cache and parallel calls
- User confusion between found vs generated:
  - explicit section ordering and `New` badge
- Drift in generated workout quality:
  - add deterministic validation pass before display/start

## Test Strategy
- Unit tests:
  - policy decisions (intent/confidence/detent)
  - confidence threshold behavior
  - ordering guarantees (retrieved before generated)
- Integration tests:
  - retrieval-only mode when LLM unavailable
  - detent-triggered generation batch append
  - initial generation streams incrementally and supports cancel
  - refinement streams incrementally and supports cancel
  - revision chain and optional save
- UI tests:
  - "Plan your workout" label/placeholder and section rendering
