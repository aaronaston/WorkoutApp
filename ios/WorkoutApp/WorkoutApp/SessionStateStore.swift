import Foundation

enum SessionPhase: String, Codable, Hashable {
    case idle
    case started
    case finished
}

struct SessionDraft: Codable, Hashable {
    let id: UUID
    var workout: WorkoutDefinition
    var workoutArtifactID: WorkoutArtifactID
    var startedAt: Date
    var endedAt: Date?
    var pausedAt: Date?
    var accumulatedPauseSeconds: TimeInterval
    var notes: String?
    var phase: SessionPhase
    var savedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case workout
        case workoutArtifactID
        case startedAt
        case endedAt
        case pausedAt
        case accumulatedPauseSeconds
        case notes
        case phase
        case savedAt
    }

    init(
        id: UUID,
        workout: WorkoutDefinition,
        workoutArtifactID: WorkoutArtifactID,
        startedAt: Date,
        endedAt: Date?,
        pausedAt: Date?,
        accumulatedPauseSeconds: TimeInterval,
        notes: String?,
        phase: SessionPhase,
        savedAt: Date
    ) {
        self.id = id
        self.workout = workout
        self.workoutArtifactID = workoutArtifactID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.pausedAt = pausedAt
        self.accumulatedPauseSeconds = accumulatedPauseSeconds
        self.notes = notes
        self.phase = phase
        self.savedAt = savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workout = try container.decode(WorkoutDefinition.self, forKey: .workout)
        workoutArtifactID = try container.decodeIfPresent(WorkoutArtifactID.self, forKey: .workoutArtifactID) ?? workout.id
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        accumulatedPauseSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .accumulatedPauseSeconds) ?? 0
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        phase = try container.decode(SessionPhase.self, forKey: .phase)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
    }
}

struct ActiveSession: Hashable {
    let id: UUID
    let workout: WorkoutDefinition
    let workoutArtifactID: WorkoutArtifactID
    let startedAt: Date
    var endedAt: Date?
    var pausedAt: Date?
    var accumulatedPauseSeconds: TimeInterval
    var notes: String?

    var isPaused: Bool {
        pausedAt != nil
    }

    mutating func pause(at date: Date = Date()) {
        guard pausedAt == nil else { return }
        pausedAt = date
    }

    mutating func resume(at date: Date = Date()) {
        guard let pausedAt else { return }
        accumulatedPauseSeconds += max(0, date.timeIntervalSince(pausedAt))
        self.pausedAt = nil
    }

    func elapsedSeconds(at date: Date = Date()) -> Int {
        let effectiveEnd = endedAt ?? date
        var elapsed = effectiveEnd.timeIntervalSince(startedAt) - accumulatedPauseSeconds
        if let pausedAt {
            elapsed -= max(0, effectiveEnd.timeIntervalSince(pausedAt))
        }
        return max(0, Int(elapsed))
    }
}

@MainActor
final class SessionStateStore: ObservableObject {
    @Published private(set) var phase: SessionPhase = .idle
    @Published private(set) var activeSession: ActiveSession?

    private let sessionStore: WorkoutSessionStore
    private let artifactStore: WorkoutArtifactStore
    private let draftStore: SessionDraftStore

    init(
        sessionStore: WorkoutSessionStore,
        artifactStore: WorkoutArtifactStore? = nil,
        draftStore: SessionDraftStore = SessionDraftStore()
    ) {
        self.sessionStore = sessionStore
        self.artifactStore = artifactStore ?? WorkoutArtifactStore()
        self.draftStore = draftStore
        restoreDraftIfAvailable()
    }

    func startSession(
        workout: WorkoutDefinition,
        at date: Date = Date(),
        initialElapsedSeconds: Int = 0,
        sessionID: UUID? = nil
    ) {
        guard phase != .started else { return }
        let clampedInitialElapsed = max(0, initialElapsedSeconds)
        let adjustedStart = date.addingTimeInterval(-TimeInterval(clampedInitialElapsed))
        let resolvedArtifactID = resolveArtifactID(
            workout: workout,
            startedAt: date,
            sessionID: sessionID
        )
        activeSession = ActiveSession(
            id: sessionID ?? UUID(),
            workout: workout,
            workoutArtifactID: resolvedArtifactID,
            startedAt: adjustedStart,
            endedAt: nil,
            pausedAt: nil,
            accumulatedPauseSeconds: 0,
            notes: nil
        )
        phase = .started
        persistDraftIfNeeded()
    }

    func endSession(at date: Date = Date(), notes: String? = nil) {
        guard var session = activeSession else { return }
        session.resume(at: date)
        session.endedAt = date
        session.notes = notes

        let workout = session.workout
        let workoutReference = WorkoutReference(
            id: workout.id,
            source: workout.source,
            title: workout.title,
            versionHash: workout.versionHash
        )

        let durationSeconds = session.elapsedSeconds(at: date)

        let completed = WorkoutSession(
            id: session.id,
            workout: workoutReference,
            startedAt: session.startedAt,
            endedAt: date,
            durationSeconds: durationSeconds,
            timerMode: .stopwatch,
            logEntries: [],
            notes: notes,
            perceivedExertion: nil,
            workoutArtifactID: session.workoutArtifactID,
            workoutSnapshot: workout
        )

        do {
            try sessionStore.upsertSession(completed)
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

    func pauseSession(at date: Date = Date()) {
        guard var session = activeSession, !session.isPaused else { return }
        session.pause(at: date)
        activeSession = session
        persistDraftIfNeeded()
    }

    func resumeSession(at date: Date = Date()) {
        guard var session = activeSession, session.isPaused else { return }
        session.resume(at: date)
        activeSession = session
        persistDraftIfNeeded()
    }

    func currentElapsedSeconds(at date: Date = Date()) -> Int? {
        guard let session = activeSession else { return nil }
        return session.elapsedSeconds(at: date)
    }

    func persistDraftIfNeeded() {
        guard phase == .started, let session = activeSession else {
            return
        }
        let draft = SessionDraft(
            id: session.id,
            workout: session.workout,
            workoutArtifactID: session.workoutArtifactID,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            pausedAt: session.pausedAt,
            accumulatedPauseSeconds: session.accumulatedPauseSeconds,
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
            workoutArtifactID: draft.workoutArtifactID,
            startedAt: draft.startedAt,
            endedAt: draft.endedAt,
            pausedAt: draft.pausedAt,
            accumulatedPauseSeconds: draft.accumulatedPauseSeconds,
            notes: draft.notes
        )
        phase = .started
    }

    private func resolveArtifactID(
        workout: WorkoutDefinition,
        startedAt: Date,
        sessionID: UUID?
    ) -> WorkoutArtifactID {
        if let sessionID,
           let existing = sessionStore.session(id: sessionID),
           !existing.workoutArtifactID.isEmpty {
            return existing.workoutArtifactID
        }

        let artifact = WorkoutArtifact(
            id: UUID().uuidString,
            workout: workout,
            provenance: WorkoutArtifactProvenance(
                baseWorkoutID: workout.sourceID ?? workout.id,
                sourceSessionID: nil,
                parentArtifactID: nil,
                derivationMode: derivationMode(for: workout.source),
                createdAt: startedAt
            ),
            createdAt: startedAt,
            updatedAt: startedAt
        )

        do {
            try artifactStore.upsertArtifact(artifact)
        } catch {
            // Best-effort persistence; active sessions should still start.
        }

        return artifact.id
    }

    private func derivationMode(for source: WorkoutSource) -> WorkoutDerivationMode {
        switch source {
        case .knowledgeBase:
            return .knowledgeBase
        case .template:
            return .template
        case .variant:
            return .variant
        case .external:
            return .external
        case .generated:
            return .generated
        }
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
