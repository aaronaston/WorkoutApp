import Foundation

enum WorkoutSessionStoreError: Error {
    case duplicateSession
    case missingSession
    case incompleteSession
}

@MainActor
final class WorkoutSessionStore: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []

    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileURL: URL = WorkoutSessionStore.defaultFileURL()) {
        self.fileURL = fileURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        loadSessions()
    }

    func reload() throws {
        try loadSessionsFromDisk()
    }

    func appendSession(_ session: WorkoutSession) throws {
        guard session.endedAt != nil else {
            throw WorkoutSessionStoreError.incompleteSession
        }
        guard !sessions.contains(where: { $0.id == session.id }) else {
            throw WorkoutSessionStoreError.duplicateSession
        }

        let finalized = finalizeSession(session)
        sessions.insert(finalized, at: 0)
        try saveSessionsToDisk()
    }

    func upsertSession(_ session: WorkoutSession) throws {
        guard session.endedAt != nil else {
            throw WorkoutSessionStoreError.incompleteSession
        }

        let finalized = finalizeSession(session)
        if let existingIndex = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions.remove(at: existingIndex)
        }
        sessions.insert(finalized, at: 0)
        try saveSessionsToDisk()
    }

    func updateNotes(for sessionID: UUID, notes: String?) throws {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            throw WorkoutSessionStoreError.missingSession
        }

        var updated = sessions[index]
        updated.notes = notes
        sessions[index] = updated
        try saveSessionsToDisk()
    }

    func session(id: UUID) -> WorkoutSession? {
        sessions.first(where: { $0.id == id })
    }

    private func loadSessions() {
        do {
            try loadSessionsFromDisk()
        } catch {
            sessions = []
        }
    }

    private func loadSessionsFromDisk() throws {
        let data = try Data(contentsOf: fileURL)
        sessions = try decoder.decode([WorkoutSession].self, from: data)
    }

    private func saveSessionsToDisk() throws {
        let data = try encoder.encode(sessions)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    private func finalizeSession(_ session: WorkoutSession) -> WorkoutSession {
        var finalized = session
        if finalized.durationSeconds == nil, let endedAt = session.endedAt {
            finalized.durationSeconds = Int(endedAt.timeIntervalSince(session.startedAt))
        }
        return finalized
    }

    nonisolated private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("WorkoutApp", isDirectory: true)
            .appendingPathComponent("workout_sessions.json")
    }
}
