import Foundation

enum WorkoutSessionStoreError: Error {
    case duplicateSession
    case missingSession
    case incompleteSession
}

enum WorkoutArtifactStoreError: Error {
    case duplicateArtifact
}

enum WorkoutTemplateStoreError: Error {
    case duplicateTemplate
    case missingTemplate
}

enum WorkoutVariantStoreError: Error {
    case duplicateVariant
    case missingVariant
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

@MainActor
final class WorkoutTemplateStore: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplate] = []

    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileURL: URL = WorkoutTemplateStore.defaultFileURL()) {
        self.fileURL = fileURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        loadTemplates()
    }

    func upsertTemplate(_ template: WorkoutTemplate) throws {
        var normalized = template
        normalized.updatedAt = Date()
        if let existingIndex = templates.firstIndex(where: { $0.id == template.id }) {
            normalized.createdAt = templates[existingIndex].createdAt
            templates.remove(at: existingIndex)
        }
        templates.insert(normalized, at: 0)
        try saveTemplates()
    }

    @discardableResult
    func createTemplateFromWorkout(_ workout: WorkoutDefinition, title: String? = nil) throws -> WorkoutTemplate {
        let now = Date()
        let template = WorkoutTemplate(
            id: UUID().uuidString,
            baseWorkoutID: workout.id,
            baseVersionHash: workout.versionHash,
            title: title ?? "\(workout.title) Template",
            summary: workout.summary,
            metadata: workout.metadata,
            content: workout.content,
            timerConfiguration: workout.timerConfiguration,
            createdAt: now,
            updatedAt: now
        )
        try upsertTemplate(template)
        return template
    }

    @discardableResult
    func createTemplateFromScratch(title: String) throws -> WorkoutTemplate {
        let now = Date()
        let template = WorkoutTemplate(
            id: UUID().uuidString,
            baseWorkoutID: nil,
            baseVersionHash: nil,
            title: title,
            summary: "Custom template",
            metadata: WorkoutMetadata(
                durationMinutes: nil,
                focusTags: [],
                equipmentTags: [],
                locationTag: nil,
                otherTags: ["template"]
            ),
            content: WorkoutContent(sourceMarkdown: "", parsedSections: [], notes: nil),
            timerConfiguration: nil,
            createdAt: now,
            updatedAt: now
        )
        try upsertTemplate(template)
        return template
    }

    @discardableResult
    func duplicateTemplate(_ template: WorkoutTemplate) throws -> WorkoutTemplate {
        let now = Date()
        let duplicate = WorkoutTemplate(
            id: UUID().uuidString,
            baseWorkoutID: template.baseWorkoutID,
            baseVersionHash: template.baseVersionHash,
            title: "\(template.title) Copy",
            summary: template.summary,
            metadata: template.metadata,
            content: template.content,
            timerConfiguration: template.timerConfiguration,
            createdAt: now,
            updatedAt: now
        )
        try upsertTemplate(duplicate)
        return duplicate
    }

    func renameTemplate(id: WorkoutID, title: String) throws {
        guard let template = templates.first(where: { $0.id == id }) else {
            throw WorkoutTemplateStoreError.missingTemplate
        }
        var updated = template
        updated.title = title
        try upsertTemplate(updated)
    }

    func deleteTemplate(id: WorkoutID) throws {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            throw WorkoutTemplateStoreError.missingTemplate
        }
        templates.remove(at: index)
        try saveTemplates()
    }

    func asWorkouts() -> [WorkoutDefinition] {
        templates.map { template in
            WorkoutDefinition(
                id: template.id,
                source: .template,
                sourceID: template.baseWorkoutID ?? template.id,
                sourceURL: nil,
                title: template.title,
                summary: template.summary,
                metadata: template.metadata,
                content: template.content,
                timerConfiguration: template.timerConfiguration,
                versionHash: template.baseVersionHash,
                createdAt: template.createdAt,
                updatedAt: template.updatedAt
            )
        }
    }

    private func loadTemplates() {
        do {
            let data = try Data(contentsOf: fileURL)
            templates = try decoder.decode([WorkoutTemplate].self, from: data)
        } catch {
            templates = []
        }
    }

    private func saveTemplates() throws {
        let data = try encoder.encode(templates)
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
            .appendingPathComponent("workout_templates.json")
    }
}

@MainActor
final class WorkoutVariantStore: ObservableObject {
    @Published private(set) var variants: [WorkoutVariant] = []

    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileURL: URL = WorkoutVariantStore.defaultFileURL()) {
        self.fileURL = fileURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        loadVariants()
    }

    func upsertVariant(_ variant: WorkoutVariant) throws {
        var normalized = variant
        normalized.updatedAt = Date()
        if let existingIndex = variants.firstIndex(where: { $0.id == variant.id }) {
            normalized.createdAt = variants[existingIndex].createdAt
            variants.remove(at: existingIndex)
        }
        variants.insert(normalized, at: 0)
        try saveVariants()
    }

    @discardableResult
    func createVariant(from workout: WorkoutDefinition, title: String? = nil) throws -> WorkoutVariant {
        let now = Date()
        let variant = WorkoutVariant(
            id: UUID().uuidString,
            baseWorkoutID: workout.id,
            baseVersionHash: workout.versionHash,
            overrides: WorkoutVariantOverrides(
                title: title ?? "\(workout.title) Variant",
                summary: workout.summary,
                metadata: workout.metadata,
                content: workout.content,
                timerConfiguration: workout.timerConfiguration,
                substitutions: [],
                notes: "Derived from \(workout.title)"
            ),
            createdAt: now,
            updatedAt: now
        )
        try upsertVariant(variant)
        return variant
    }

    @discardableResult
    func duplicateVariant(_ variant: WorkoutVariant) throws -> WorkoutVariant {
        let now = Date()
        var overrides = variant.overrides
        if let existingTitle = overrides.title {
            overrides.title = "\(existingTitle) Copy"
        } else {
            overrides.title = "Variant Copy"
        }
        let duplicate = WorkoutVariant(
            id: UUID().uuidString,
            baseWorkoutID: variant.baseWorkoutID,
            baseVersionHash: variant.baseVersionHash,
            overrides: overrides,
            createdAt: now,
            updatedAt: now
        )
        try upsertVariant(duplicate)
        return duplicate
    }

    func renameVariant(id: WorkoutID, title: String) throws {
        guard let variant = variants.first(where: { $0.id == id }) else {
            throw WorkoutVariantStoreError.missingVariant
        }
        var updated = variant
        updated.overrides.title = title
        try upsertVariant(updated)
    }

    func deleteVariant(id: WorkoutID) throws {
        guard let index = variants.firstIndex(where: { $0.id == id }) else {
            throw WorkoutVariantStoreError.missingVariant
        }
        variants.remove(at: index)
        try saveVariants()
    }

    func resolveWorkouts(baseWorkouts: [WorkoutDefinition]) -> [WorkoutDefinition] {
        let byID = Dictionary(uniqueKeysWithValues: baseWorkouts.map { ($0.id, $0) })
        return variants.compactMap { variant in
            guard let base = byID[variant.baseWorkoutID] else {
                return nil
            }
            return apply(variant, to: base)
        }
    }

    private func apply(_ variant: WorkoutVariant, to base: WorkoutDefinition) -> WorkoutDefinition {
        WorkoutDefinition(
            id: variant.id,
            source: .variant,
            sourceID: variant.baseWorkoutID,
            sourceURL: nil,
            title: variant.overrides.title ?? base.title,
            summary: variant.overrides.summary ?? base.summary,
            metadata: variant.overrides.metadata ?? base.metadata,
            content: variant.overrides.content ?? base.content,
            timerConfiguration: variant.overrides.timerConfiguration ?? base.timerConfiguration,
            versionHash: variant.baseVersionHash ?? base.versionHash,
            createdAt: variant.createdAt,
            updatedAt: variant.updatedAt
        )
    }

    private func loadVariants() {
        do {
            let data = try Data(contentsOf: fileURL)
            variants = try decoder.decode([WorkoutVariant].self, from: data)
        } catch {
            variants = []
        }
    }

    private func saveVariants() throws {
        let data = try encoder.encode(variants)
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
            .appendingPathComponent("workout_variants.json")
    }
}

@MainActor
final class GeneratedCandidateStore: ObservableObject {
    @Published private(set) var candidates: [GeneratedCandidate] = []

    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileURL: URL = GeneratedCandidateStore.defaultFileURL()) {
        self.fileURL = fileURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        load()
    }

    func saveCandidates(_ values: [GeneratedCandidate], forQuery query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let retained = candidates.filter { $0.originQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != normalizedQuery }
        candidates = values + retained
        persist()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            candidates = try decoder.decode([GeneratedCandidate].self, from: data)
        } catch {
            candidates = []
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(candidates)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Best-effort persistence for provenance inspection.
        }
    }

    nonisolated private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("WorkoutApp", isDirectory: true)
            .appendingPathComponent("generated_candidates.json")
    }
}
