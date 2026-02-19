# Architecture and Design

This document uses TOGAF domains as the organizing structure and C4-style decomposition for system detail.

## Business Architecture

### System Context
- **Primary actor:** end user (single user on device).
- **Supporting actors:** iOS (Calendar, HealthKit, Keychain), external content providers, optional LLM provider.
- **Business goals:** recommend appropriate workouts, support execution with timers, log results, and improve future recommendations.

### Capabilities
- Workout discovery (recommendations, search/browse, free-form request)
- Workout execution (timers, prompts, session recovery)
- Workout logging (sets/reps/weight, notes, duration)
- Knowledge base management (bundled, immutable workouts)
- Template and variant management (user-owned edits derived from base workouts)
- Optional integrations (Calendar, HealthKit, LLM)

### Value Streams (high level)
1) Discover workout -> 2) Select -> 3) Execute -> 4) Log -> 5) Review -> 6) Improve recommendations

### Business Constraints
- iOS-only, offline-first.
- No accounts or cloud sync.
- Single user per device.
- Knowledge base is immutable at runtime.
- External network access is optional and opt-in.

## Application Architecture

### Container View
- **iOS App UI:** discovery, workout detail, execution, logging, history, settings.
- **Local Data Store:** user templates, variants, sessions, preferences, recommendation inputs.
- **Bundled Knowledge Base:** `resources/workouts/*.md` files.
- **Integration Adapters:** Calendar, HealthKit, network fetchers, LLM client.

### Component View (inside the app)
- **Discovery & Recommendations:** ranking engine, explainable reasons, preference weighting.
- **Search & Browse:** filters, tags, and direct selection; search results are ordered alphabetically by workout title.
- **Knowledge Base Loader:** Markdown reader, metadata extractor, indexer.
- **Template/Variant Manager:** copy/derive, edit, provenance tracking.
- **Execution Engine:** timer modes (EMOM/interval/AMRAP/stopwatch/countdown), cues, session recovery.
- **Logging & History:** session persistence, metrics rollups, progress views.
- **External Source Importer:** fetch, parse, cache, provenance.
- **LLM Orchestrator (optional):** prompt shaping, privacy gating, response normalization.

### Discovery-LLM Interaction Contract
- Rules-based recommendation ranking is the primary path and always computed locally.
- LLM orchestration is optional and only used for free-form generation/regeneration requests.
- Generated workouts are treated as explicit candidates (`WorkoutSource.generated`), not hidden
  score adjustments on rules-ranked workouts.
- LLM prompt assembly is policy-gated by user settings (enabled state, credentials, and per-category
  sharing toggles).
- LLM prompt assembly supports `summary`, `raw`, and `augmented` modes; `augmented` keeps user
  intent while enriching prompt context from preferences/history/current condition.
- Discovery UI must label candidate origin (rules vs generated) and explanation source.

### Execution Engine Notes
- `ExecutionTimer` derives `ExecutionTimerSnapshot` values from a `TimerConfiguration` using timestamps for
  start/pause/resume/stop, so UI can refresh using `snapshot(at:)` and recover after backgrounding.
- The session UI should treat snapshot output as the source of truth for phase/round/remaining seconds.

### Presentation Layer (SwiftUI mock screens)
- **Discovery:** search, "Today" highlight, recommended list, filter chips.
- **Workout Detail:** metadata chips, recommendation reason, block preview, start action.
- **Session:** timer card, current block list, log entries.
- **History:** weekly summary stats and recent sessions list.
- **Settings:** preference toggles and drill-in preferences.

### Code View (module-level sketch)
- `Discovery` (recommendations, filters, explanations)
- `Workouts` (models, knowledge base loader, templates/variants)
- `Execution` (timers, state machine, cues)
- `History` (sessions, metrics, history views)
- `Integrations` (Calendar, HealthKit, external sources, LLM)
- `Storage` (persistence, migrations, cache)

## Information Architecture

### Information Context
- Core information is stored locally and tied to a single user on-device.
- Data provenance distinguishes knowledge base, user templates, and derived variants.

### View Model Data Shapes (derived from UI mockups)
- **DiscoveryViewModel**
  - `title`, `subtitle`
  - `searchPlaceholder`, `searchQuery`
  - `todayHighlight: WorkoutHighlight`
  - `recommended: [WorkoutSummary]`
  - `filters: [FilterChip]`
- **WorkoutDetailViewModel**
  - `workout: WorkoutSummary`
  - `tags: [String]` (duration, focus, equipment)
  - `recommendationReason: RecommendationReason`
  - `previewBlocks: [WorkoutBlockPreview]`
  - `primaryActionTitle` (start session)
- **SessionViewModel**
  - `sessionTitle`, `workoutTitle`
  - `timer: TimerState` (mode, remaining, round, phase)
  - `currentBlocks: [WorkoutBlockSummary]`
  - `logEntries: [LogEntrySummary]`
- **HistoryViewModel**
  - `weeklySummary: HistorySummary`
  - `recentSessions: [SessionSummary]`
- **SettingsViewModel**
  - `calendarSyncEnabled`, `healthSyncEnabled`
  - `discoveryPreferences: [PreferenceLink]`
  - `accountActions: [ActionLink]`

### Conceptual Data Model (high level)
- **WorkoutDefinition**
  - Source: knowledge base | user template | external
  - Content: raw Markdown + structured metadata
  - Tags: category, duration, equipment, location
- **WorkoutVariant**
  - Base workout reference + overrides
  - Provenance (base id + version/hash)
- **WorkoutSession**
  - Timestamp, duration, workout reference
  - Per-exercise logs (sets, reps, weight)
  - Notes and perceived effort
- **UserPreferences**
  - Discovery weights and constraints
  - Equipment availability, location, duration targets
  - Privacy toggles for sharing
- **RecommendationReason**
  - Human-readable explanation for ranking
- **ExternalWorkoutImport**
  - Source URL, fetch date, raw content, parse status

### Information Flows
- Knowledge base files -> loader/indexer -> discovery/search.
- Session logs -> history -> recommendation engine inputs.
- Preferences -> discovery ranking and filtering.
- Optional external sources/LLM -> discovery -> template/variant creation.
- Recommendation reasons come from deterministic ranking for rules candidates and from prompt-fit
  rationale for generated candidates.

### Storage Boundaries
- **Persisted:** workout definitions (base + templates/variants), sessions, preferences, recommendation inputs, external imports.
- **Computed:** recommendation ranking, reasons, filter chips, weekly summaries.
- **Ephemeral UI state:** search query, selected filters, active timer state, in-progress logs.

## Technology Architecture

### Technology Context
- On-device iOS stack with optional network integrations.
- Privacy-sensitive APIs gated by user permissions.

### Platforms & Runtime
- iOS (Swift/SwiftUI expected).
- Local persistence (e.g., Core Data or SQLite).
- File-based bundle resources for workouts.

### Infrastructure/Services
- **Local storage:** database + file cache.
- **System services:** Calendar, HealthKit, Keychain.
- **Networking:** HTTPS for external workout sources and optional LLM.

### Security & Privacy
- Keychain for API keys.
- Explicit opt-in for Calendar/HealthKit/LLM sharing.
- Local-only storage by default; no cloud sync.

### Availability & Resilience
- Offline-first for discovery, templates, and history.
- Graceful degradation when network/LLM unavailable.

## Open Decisions
- Final persistence technology choice and schema design.
- LLM provider defaults beyond initial OpenAI support.
- Parsing fidelity targets for Markdown workouts.
