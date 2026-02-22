# C4 Context Diagram: WorkoutApp

## Scope
This context view shows the `WorkoutApp` system boundary, primary actor, and external systems it interacts with.

## System Context

```mermaid
flowchart LR
    User([Person: User])
    App([System: WorkoutApp\niOS app for discovery, session execution, and history])
    IOS[[System: iOS Platform Services\nCalendar, Keychain, Notifications]]
    HK[[System: HealthKit + Watch Connectivity (Optional)]]
    LLM[[System: LLM Provider API (Optional)]]
    Sources[[System: External Workout Sources (Optional)]]

    User --> App
    App --> IOS
    App -. opt-in sync/export .-> HK
    App -. opt-in generation .-> LLM
    App -. optional import .-> Sources
```

## Relationship Notes
- The user interacts directly with `WorkoutApp`; there is no separate account or cloud identity boundary today.
- iOS platform services provide local OS capabilities required for app behavior and secure key storage.
- HealthKit/watch integration is optional and can be disabled without affecting core local functionality.
- LLM and external source integrations are opt-in enhancements, not core dependencies.
