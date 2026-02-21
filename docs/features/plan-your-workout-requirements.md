# Plan Your Workout - Requirements

## Status
- Drafted from stakeholder interview on 2026-02-21.

## Problem
Discovery is currently split between deterministic search and a future LLM generation path. Users need one input that supports both finding existing workouts and creating new ones when needed.

## Goal
Replace the current search-first interaction with a unified discovery experience labeled **Plan your workout** that returns:
- matching existing workouts first
- generated options when user intent or interaction indicates they want something new

## Primary User Experience
1. User enters text in **Plan your workout**.
2. App runs hybrid retrieval (keyword + semantic) for existing workouts.
3. Existing matches render first.
4. Generated workouts render after existing matches and are marked `New`.
5. More generation is triggered when user pushes past the bottom detent.
6. If retrieval confidence is low, generation can start automatically.
7. If intent classification indicates a "create" request (non-searchlike), generation starts immediately.
8. User may continue conversational refinement to tune results (retrieved and generated).

## Functional Requirements

### FR-1 Unified Input and Label
- Replace discover input label/placeholder with **Plan your workout**.
- Keep one query entry point for retrieval and generation.

### FR-2 Retrieval Ranking and Ordering
- Use hybrid retrieval (keyword + semantic).
- Existing workouts must be ranked and listed before generated workouts.
- Retrieval confidence score must be available for generation gating.

### FR-3 Generation Trigger Policy
- For searchlike intent:
  - initial result is retrieval-only
  - generation is triggered when user pushes past bottom detent
  - generation may also auto-trigger when retrieval confidence is low
- For definitely generative intent:
  - generation starts immediately
  - additional generation occurs on bottom-detent push

### FR-4 Generated Result Behavior
- Generate up to 5 options per request (target: one screen).
- Options should vary while preserving the query theme.
- Generated items must be clearly marked `New`.

### FR-5 Save and Lifecycle
- Generated workouts are ephemeral by default.
- User can save/star a generated or adjusted workout.
- User may run without saving.

### FR-6 Post-Selection Refinement
- User can select any workout and iteratively refine via follow-up prompts before starting.
- Refinement must preserve a clear provenance chain (base workout + prompt revisions).

### FR-7 Context for Augmented Prompting
The generation path should use augmented context from:
- user preferences
- recent history summary
- session log summary
- note summary
- relevant templates/variants

### FR-8 Offline/Unavailable LLM Behavior
- If LLM is unavailable, provide retrieval-only behavior.
- No blocking error state is required for v1.

### FR-9 Explainability
- Generated workouts must include explanation of fit to request/history/performance context.

## Future Requirement (Separate Feature Track)
### FR-10 Intensity Policy
- Capture post-workout user-reported actual intensity.
- Add preference-driven intensity policy to influence next workout planning and recovery balancing.
- This is in scope for planning but not required for first implementation of Plan your workout.

## Non-Goals for Initial Delivery
- Fully autonomous chat agent behavior across app tabs.
- Automatic saving of all generated workouts.
- Multi-provider orchestration beyond current configured LLM provider.

## Acceptance Criteria (Initial Release)
- Entering "quick upper body workout" shows existing matches first.
- Generated options appear after existing matches and include `New` marker.
- Pushing past list bottom requests additional generated options.
- In retrieval-only situations (LLM unavailable), discovery still returns existing matches.
- User can refine a selected workout with additional prompts before starting.
- User can optionally save/star any generated or refined workout.
