# C4 Component Diagram: Workout Session + Sync Boundaries

## Scope
This component view zooms into the `WorkoutApp` container and highlights:
- workout session execution
- local persistence boundaries
- optional sync/integration boundaries

## C4 Component View (WorkoutApp Container)

```mermaid
flowchart LR
    User([Person: User])

    subgraph App[Container: WorkoutApp (iOS App)]
        UI[Component: SwiftUI Screens\nDiscover / Session / History / Settings]
        SessionState[Component: SessionStateStore\nSession lifecycle + timing state]
        Timer[Component: ExecutionTimer\nDerived snapshots for interval/stopwatch UI]
        Discovery[Component: Discovery + Search\nWorkoutSearchIndex + RecommendationEngine]
        Loader[Component: KnowledgeBaseLoader\nMarkdown parse + index bootstrap]
        Prefs[Component: UserPreferencesStore\nPrivacy + recommendation preferences]
        SessionRepo[Component: WorkoutSessionStore\nCompleted session persistence]
        DraftRepo[Component: SessionDraftStore\nIn-progress session recovery]
    end

    subgraph DeviceData[Container: On-device Data]
        Bundle[(Bundled workouts/*.md)]
        AppSupport[(Application Support JSON files)]
        Keychain[(iOS Keychain)]
    end

    subgraph Integrations[External Systems (Optional)]
        HealthKit[[HealthKit / WatchConnectivity]]
        LLM[[LLM Provider API]]
    end

    User --> UI
    UI --> SessionState
    UI --> Discovery
    UI --> Prefs

    SessionState --> Timer
    SessionState --> DraftRepo
    SessionState --> SessionRepo

    Discovery --> Loader
    Loader --> Bundle
    SessionRepo --> AppSupport
    DraftRepo --> AppSupport
    Prefs --> AppSupport
    Prefs --> Keychain

    SessionState -. optional export/sync .-> HealthKit
    Discovery -. optional generation .-> LLM
```

## Boundary Notes
- `WorkoutApp` is the primary container; all core execution works offline with local data.
- Sync and generation are optional integrations and are explicit boundaries, not core dependencies.
- Session continuity boundary:
  - `SessionDraftStore` handles recoverable in-progress state.
  - `WorkoutSessionStore` handles completed history records.
- Sensitive credentials (for optional LLM use) are isolated in Keychain via `UserPreferencesStore`.
