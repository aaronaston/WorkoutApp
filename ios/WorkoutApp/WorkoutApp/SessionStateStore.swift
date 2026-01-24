import Foundation

enum SessionPhase: String, Codable, Hashable {
    case idle
    case started
    case finished
}

struct ActiveSession: Hashable {
    let id: UUID
    let workout: WorkoutDefinition
    let startedAt: Date
    var endedAt: Date?
    var notes: String?
}

@MainActor
final class SessionStateStore: ObservableObject {
    @Published private(set) var phase: SessionPhase = .idle
    @Published private(set) var activeSession: ActiveSession?

    private let sessionStore: WorkoutSessionStore

    init(sessionStore: WorkoutSessionStore) {
        self.sessionStore = sessionStore
    }

    func startSession(workout: WorkoutDefinition, at date: Date = Date()) {
        guard phase != .started else { return }
        activeSession = ActiveSession(id: UUID(), workout: workout, startedAt: date)
        phase = .started
    }

    func endSession(at date: Date = Date(), notes: String? = nil) {
        guard var session = activeSession else { return }
        session.endedAt = date
        session.notes = notes

        let workout = session.workout
        let workoutReference = WorkoutReference(
            id: workout.id,
            source: workout.source,
            title: workout.title,
            versionHash: workout.versionHash
        )

        let durationSeconds = max(0, Int(date.timeIntervalSince(session.startedAt)))

        let completed = WorkoutSession(
            id: session.id,
            workout: workoutReference,
            startedAt: session.startedAt,
            endedAt: date,
            durationSeconds: durationSeconds,
            timerMode: .stopwatch,
            logEntries: [],
            notes: notes,
            perceivedExertion: nil
        )

        do {
            try sessionStore.appendSession(completed)
        } catch {
            // Best-effort persistence; session UI should still finish.
        }

        activeSession = nil
        phase = .finished
    }

    func resetIfFinished() {
        guard phase == .finished else { return }
        phase = .idle
    }
}
