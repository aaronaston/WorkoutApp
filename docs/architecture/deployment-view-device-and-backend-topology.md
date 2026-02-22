# Deployment View: Device-only and Device + Backend Topology

## Scope
This deployment view maps runtime nodes to C4 containers for two operating modes:
- local-first device-only mode
- device plus optional backend/integration mode

## Mode A: Device-only (offline-first baseline)

```mermaid
flowchart LR
    User([User])

    subgraph iPhone[iPhone Node]
        App[Container: WorkoutApp (iOS)]
        AppData[(Container: Local Data\nApplication Support + Keychain)]
        Bundle[(Container: Bundled Workout Markdown)]
    end

    User --> App
    App --> AppData
    App --> Bundle
```

### Characteristics
- No backend dependency required for core discover/session/history behavior.
- All persistence is on-device.
- App remains functional without network access.

## Mode B: Device + Optional Backend/Integrations

```mermaid
flowchart LR
    User([User])

    subgraph iPhone[iPhone Node]
        App[Container: WorkoutApp (iOS)]
        AppData[(Container: Local Data\nApplication Support + Keychain)]
        Bundle[(Container: Bundled Workout Markdown)]
    end

    subgraph Apple[Apple Services]
        HK[[Container: HealthKit + WatchConnectivity]]
    end

    subgraph Internet[External Network]
        LLM[[Container: LLM Provider API]]
        Sources[[Container: External Workout Sources]]
    end

    User --> App
    App --> AppData
    App --> Bundle
    App -. opt-in sync .-> HK
    App -. opt-in generation .-> LLM
    App -. optional import .-> Sources
```

### Characteristics (Mode B)
- Core app still runs locally; backend services enhance but do not own primary workout/session state.
- Integration traffic is opt-in and preference-gated.
- Failure of external nodes degrades features, not core execution.

## Deployment Boundary Notes
- Local data remains system of record for current architecture.
- External services are integration boundaries, not authoritative data stores.
- This topology is compatible with a future backend container without changing the device-only baseline.
