# DDR-0001: Align view models and storage boundaries with SwiftUI mock screens

## Status
Accepted

## Date
2026-01-11

## Context
SwiftUI mock screens now define the discovery, workout detail, session, history, and settings layouts.
We need to translate those UI expectations into concrete view model data shapes and storage boundaries so
core model, data/storage, and logic implementation order is clear.

## Decision
Define view model data shapes that mirror the mock screens and map them to persisted domain models through
explicit adapters. Keep transient UI state (search queries, selected filters, timers in progress) out of
persistent storage unless it is required for recovery.

## Alternatives
- Option A: Model-first schema, then retrofit UI
  - Pros: storage design is centralized and normalized early
  - Cons: higher risk of mismatch with implemented UI flows and missing UI-facing data
- Option B: Bind SwiftUI views directly to persistence models
  - Pros: fewer adapter layers
  - Cons: mixes UI state with persistence, harder to evolve storage

## Consequences
- Requires a view model mapping layer between storage/domain models and SwiftUI screens.
- Implementation can proceed screen-by-screen with clear data requirements.
- Persistence work focuses on stable entities (workouts, sessions, preferences) while UI state stays ephemeral.

## References
- `ios/WorkoutApp/WorkoutApp/ContentView.swift`
- wa-ez5
