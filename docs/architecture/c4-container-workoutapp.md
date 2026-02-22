# C4 Container Diagram: WorkoutApp

## Scope
This container view decomposes the `WorkoutApp` system into runtime containers and external dependencies.

## Container Diagram

```mermaid
flowchart LR
    User([Person: User])

    subgraph System[System: WorkoutApp]
        UI[Container: iOS App UI\nSwiftUI screens + view models]
        Domain[Container: App Domain Services\nSession state, discovery, recommendation, parsing]
        Store[Container: Local Persistence\nJSON stores in Application Support]
        KB[Container: Bundled Knowledge Base\nMarkdown workouts in app resources]
        Secrets[Container: Secure Secrets\nAPI keys in iOS Keychain]
    end

    HK[[External: HealthKit/Watch Connectivity (Optional)]]
    LLM[[External: LLM Provider API (Optional)]]
    Sources[[External: External Workout Sources (Optional)]]

    User --> UI
    UI --> Domain
    Domain --> Store
    Domain --> KB
    Domain --> Secrets
    Domain -. opt-in export/sync .-> HK
    Domain -. opt-in generation .-> LLM
    Domain -. optional import .-> Sources
```

## Container Responsibilities
- `iOS App UI`: discovery, workout details, session control, history review, settings.
- `App Domain Services`: business logic for recommendations, timer/session orchestration, workout parsing/search.
- `Local Persistence`: durable storage for sessions, draft session recovery, and user preferences.
- `Bundled Knowledge Base`: immutable starter workout content delivered with the app.
- `Secure Secrets`: credentials for optional external providers.
