# Primary Flow: Workout Tracking + Sync Timeline

## Scope
This timeline focuses on the app's primary execution loop:
`start -> run/pause/resume -> finish -> persist -> optional sync`.

It reflects the current code paths in:
- `ios/WorkoutApp/WorkoutApp/SessionStateStore.swift`
- `ios/WorkoutApp/WorkoutApp/WorkoutSessionStore.swift`
- `ios/WorkoutApp/WorkoutApp/HealthKitSessionMessages.swift`

## Sequence Timeline

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as SessionView/ContentView
    participant State as SessionStateStore
    participant Draft as SessionDraftStore
    participant History as WorkoutSessionStore
    participant HK as HealthKit/Watch Sync (Optional)

    User->>UI: Tap Start
    UI->>State: startSession(workout, at, initialElapsed?, sessionID?)
    State->>Draft: saveDraft(SessionDraft)
    Note over State,Draft: Phase = started, activeSession set

    loop Active workout
        User->>UI: Pause / Resume / Continue
        UI->>State: pauseSession()/resumeSession()
        State->>Draft: saveDraft(SessionDraft)
    end

    alt App backgrounds or terminates during active session
        UI->>State: persistDraftIfNeeded()
        State->>Draft: saveDraft(SessionDraft)
        Note over Draft: Draft supports crash/relaunch recovery
    end

    User->>UI: End Session
    UI->>State: endSession(at, notes?)
    State->>State: Compute elapsed (exclude paused intervals)
    State->>History: upsertSession(WorkoutSession)
    State->>Draft: clearDraft()
    State-->>UI: phase = finished
    UI-->>User: Route to History tab

    opt HealthKit/watch export enabled
        History->>HK: Send completed session summary
        HK-->>History: Export state / metrics update
        Note over HK: Best-effort sync; app data remains local source of truth
    end
```

## Data Handoffs
- `SessionStateStore` owns in-memory active state and lifecycle transitions.
- `SessionDraftStore` persists recoverable in-progress state.
- `WorkoutSessionStore` persists completed or resumed session records (`upsert` preserves single session identity on resume).
- Optional HealthKit/watch integration consumes completed session data and does not replace local session history.

## Failure and Recovery Notes
- If session persistence fails at completion, UI still exits the active session (best effort persistence).
- If draft recovery payload is invalid or stale, the draft is dropped during restore.
- If external sync/export fails, local completion still stands and can be retried later.
