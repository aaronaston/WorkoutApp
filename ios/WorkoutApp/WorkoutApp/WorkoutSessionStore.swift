import Foundation

enum WorkoutSessionStoreError: Error {
    case duplicateSession
    case missingSession
    case incompleteSession
}

enum WorkoutArtifactStoreError: Error {
    case duplicateArtifact
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

@MainActor
final class WorkoutArtifactStore: ObservableObject {
    @Published private(set) var artifacts: [WorkoutArtifact] = []

    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileURL: URL = WorkoutArtifactStore.defaultFileURL()) {
        self.fileURL = fileURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        loadArtifacts()
    }

    func reload() throws {
        try loadArtifactsFromDisk()
    }

    func appendArtifact(_ artifact: WorkoutArtifact) throws {
        guard !artifacts.contains(where: { $0.id == artifact.id }) else {
            throw WorkoutArtifactStoreError.duplicateArtifact
        }
        artifacts.insert(artifact, at: 0)
        try saveArtifactsToDisk()
    }

    func upsertArtifact(_ artifact: WorkoutArtifact) throws {
        var normalized = artifact
        normalized.updatedAt = Date()

        if let existingIndex = artifacts.firstIndex(where: { $0.id == artifact.id }) {
            let createdAt = artifacts[existingIndex].createdAt
            artifacts.remove(at: existingIndex)
            normalized.createdAt = createdAt
        }
        artifacts.insert(normalized, at: 0)
        try saveArtifactsToDisk()
    }

    func artifact(id: WorkoutArtifactID) -> WorkoutArtifact? {
        artifacts.first(where: { $0.id == id })
    }

    func provenanceChain(for artifactID: WorkoutArtifactID) -> [WorkoutArtifact] {
        let byID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        var chain: [WorkoutArtifact] = []
        var visited: Set<WorkoutArtifactID> = []
        var currentID: WorkoutArtifactID? = artifactID

        while let id = currentID, !id.isEmpty {
            guard !visited.contains(id), let artifact = byID[id] else {
                break
            }
            chain.append(artifact)
            visited.insert(id)
            currentID = artifact.provenance.parentArtifactID
        }

        return chain
    }

    private func loadArtifacts() {
        do {
            try loadArtifactsFromDisk()
        } catch {
            artifacts = []
        }
    }

    private func loadArtifactsFromDisk() throws {
        let data = try Data(contentsOf: fileURL)
        artifacts = try decoder.decode([WorkoutArtifact].self, from: data)
    }

    private func saveArtifactsToDisk() throws {
        let data = try encoder.encode(artifacts)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    nonisolated private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("WorkoutApp", isDirectory: true)
            .appendingPathComponent("workout_artifacts.json")
    }
}
