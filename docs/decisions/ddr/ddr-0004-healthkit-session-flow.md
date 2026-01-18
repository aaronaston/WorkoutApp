# DDR-0004: Define HealthKit integration and workout session flow

## Status
Accepted

## Date
2026-01-18

## Context
We need a design for HealthKit integration that preserves privacy, works offline, and supports
watch-enhanced live sessions with heart rate and in-session metrics, while still allowing a
phone-only fallback. Session flow must support timers, pause/resume, and recovery across phone +
watch. Design decisions should flow from integration constraints (permissions, live session
requirements, export strategy) into the session state model and timers.

## Decision
1) HealthKit integration is available in two modes:
   - Watch mode (preferred): the watch app owns the live workout session (HKWorkoutSession +
     HKLiveWorkoutBuilder) and provides live metrics.
   - Phone-only mode (fallback): the phone runs the session without live metrics; HealthKit export
     is post-hoc and best-effort.
2) Permissions: request read access for heart rate and write access for workouts when enabling
   watch mode. The phone UI should surface permission status and recommend watch mode, but allow
   phone-only mode when unavailable.
3) Export strategy:
   - Watch mode: the watch session saves the HealthKit workout on completion using start/end
     timestamps, total duration, and activity type derived from workout metadata.
   - Phone-only mode: the phone writes the workout summary post-hoc with the same metadata but
     without live metrics.
   - If export fails in either mode, mark the session as pending export and retry later.
4) Activity type mapping:
   - If metadata focus/equipment indicate running, rowing, cycling, or swimming, map to that type.
   - If timer mode is interval/EMOM/AMRAP and focus is conditioning, map to high-intensity intervals.
   - Otherwise map to traditional strength training.
   - Default: .other when no signal is available.
5) Watch/phone coordination (watch mode):
   - Phone sends a session start request to the watch via WatchConnectivity (workout id, plan,
     timer config, metadata).
   - Watch responds with session state + live metrics; phone mirrors and renders them.
   - Phone is the coach UI; watch shows live stats + current block/interval summary.
6) Session state model:
   - Lifecycle states: idle -> preparing -> active -> paused -> completed or canceled.
   - SessionTiming tracks startedAt, endedAt, and pausedIntervals to compute activeDurationSeconds.
   - SessionPlan derives blocks and items from WorkoutDefinition (sections, items, timer config).
   - Overall timer is a stopwatch with active duration. Block/element timers are derived from
     TimerConfiguration and current SessionPlan position.
7) Persistence responsibilities:
   - In-progress session state is stored as a lightweight SessionDraft on background/terminate to
     enable recovery; it is overwritten on state transitions.
   - Completed sessions are appended to WorkoutSessionStore with durationSeconds computed from
     active duration (excluding pauses).
   - HealthKit export status is stored with the session for retry scheduling.
8) Fallback behavior:
   - If watch is unavailable or permissions are missing, allow phone-only sessions with a clear
     banner that live metrics are unavailable.
   - Post-hoc HealthKit export from phone is the fallback path when no watch session is running.

## Alternatives
- Option A: Watch-enhanced with phone-only fallback (chosen)
  - Pros: live HR/metrics when available, still usable without watch
  - Cons: two execution paths to keep consistent
- Option B: Watch-required live session
  - Pros: single source of HealthKit truth, simpler state handling
  - Cons: blocks users without a watch or with connectivity issues

## Consequences
- Requires a watch app target and WatchConnectivity protocol.
- Session timing must track pause intervals to compute active duration.
- Execution engine derives timers from workout metadata + timer configuration.
- Adds a lightweight export queue and failure handling for HealthKit writes.
- Adds a phone-only execution path with reduced metrics.

## References
- `readme.md`
- `docs/architecture/README.md`
- wa-4z1
