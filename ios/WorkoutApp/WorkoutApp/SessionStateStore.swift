import Foundation

enum SessionPhase: String, Codable, Hashable {
    case idle
    case started
    case finished
}

struct SessionDraft: Codable, Hashable {
    let id: UUID
    var workout: WorkoutDefinition
    var startedAt: Date
    var endedAt: Date?
    var notes: String?
    var phase: SessionPhase
    var savedAt: Date
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
    private let draftStore: SessionDraftStore

    init(sessionStore: WorkoutSessionStore, draftStore: SessionDraftStore = SessionDraftStore()) {
        self.sessionStore = sessionStore
        self.draftStore = draftStore
        restoreDraftIfAvailable()
    }

    func startSession(workout: WorkoutDefinition, at date: Date = Date()) {
        guard phase != .started else { return }
        activeSession = ActiveSession(id: UUID(), workout: workout, startedAt: date)
        phase = .started
        persistDraftIfNeeded()
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
        draftStore.clearDraft()
    }

    func resetIfFinished() {
        guard phase == .finished else { return }
        phase = .idle
    }

    func cancelSession() {
        guard phase == .started else { return }
        activeSession = nil
        phase = .idle
        draftStore.clearDraft()
    }

    func persistDraftIfNeeded() {
        guard phase == .started, let session = activeSession else {
            return
        }
        let draft = SessionDraft(
            id: session.id,
            workout: session.workout,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            notes: session.notes,
            phase: phase,
            savedAt: Date()
        )
        draftStore.saveDraft(draft)
    }

    private func restoreDraftIfAvailable() {
        guard phase == .idle else { return }
        guard let draft = draftStore.loadDraft() else { return }
        guard draft.phase == .started else {
            draftStore.clearDraft()
            return
        }
        activeSession = ActiveSession(
            id: draft.id,
            workout: draft.workout,
            startedAt: draft.startedAt,
            endedAt: draft.endedAt,
            notes: draft.notes
        )
        phase = .started
    }
}

final class SessionDraftStore {
    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileURL: URL = SessionDraftStore.defaultFileURL()) {
        self.fileURL = fileURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func loadDraft() -> SessionDraft? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(SessionDraft.self, from: data)
        } catch {
            return nil
        }
    }

    func saveDraft(_ draft: SessionDraft) {
        do {
            let data = try encoder.encode(draft)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Best-effort persistence; keep UI responsive if disk write fails.
        }
    }

    func clearDraft() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    nonisolated private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("WorkoutApp", isDirectory: true)
            .appendingPathComponent("session_draft.json")
    }
}
