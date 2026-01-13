# DDR-0003: Establish core workout and session data models

## Status
Accepted

## Date
2026-01-12

## Context
The app needs stable domain models for workout definitions, user templates/variants, and session
history. These models must capture provenance (what a workout was derived from), minimal metadata
used for discovery and filtering, and logging details from workout sessions.

## Decision
Define Swift codable models for WorkoutDefinition, WorkoutTemplate, WorkoutVariant, WorkoutSession,
and WorkoutHistory. Workout definitions track source identifiers, optional source URLs, and content
version hashes for provenance. Templates and variants store base workout identifiers and version
hashes to preserve derivation lineage. Metadata includes duration, focus, equipment, and location
labels, while sessions record timestamps, timer modes, and exercise logs.

## Alternatives
- Option A: Persist only raw Markdown and parse on demand
  - Pros: simpler storage schema
  - Cons: slower discovery, no stable metadata for filtering or recommendations
- Option B: Collapse templates/variants into a single editable workout type
  - Pros: fewer model types
  - Cons: loses provenance clarity and makes merging updates harder

## Consequences
- Discovery uses metadata fields without re-parsing Markdown on every query.
- Provenance fields enable tracking of derived templates/variants and session references.
- Storage migrations are required when version hash or provenance fields change shape.

## References
- `ios/WorkoutApp/WorkoutApp/CoreModels.swift`
- wa-gny
