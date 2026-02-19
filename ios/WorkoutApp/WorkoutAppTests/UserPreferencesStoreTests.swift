import XCTest
@testable import WorkoutApp

final class UserPreferencesStoreTests: XCTestCase {
    @MainActor
    func testReturnsDefaultWhenFileMissing() throws {
        let directoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("user_preferences.json")

        let store = UserPreferencesStore(fileURL: fileURL)

        XCTAssertEqual(store.preferences, .default)
    }

    @MainActor
    func testReturnsDefaultWhenFileCorrupted() throws {
        let directoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("user_preferences.json")
        try Data("not-json".utf8).write(to: fileURL)

        let store = UserPreferencesStore(fileURL: fileURL)

        XCTAssertEqual(store.preferences, .default)
    }

    @MainActor
    func testSavingPreferencesRoundTrips() throws {
        let directoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("user_preferences.json")

        let store = UserPreferencesStore(fileURL: fileURL)
        let updated = UserPreferences(
            calendarSyncEnabled: true,
            healthKitSyncEnabled: false,
            discovery: DiscoveryPreferences(
                targetDuration: .long,
                location: .gym,
                equipmentTags: ["barbell", "bench"],
                focusTags: ["strength"],
                includeTemplates: false,
                includeExternalSources: true,
                excludedTags: ["rehab"],
                minimumRestDaysByCategory: ["lower": 2]
            ),
            llm: LLMPreferences(
                enabled: true,
                provider: .openAI,
                modelID: "gpt-5",
                promptDetailLevel: .raw,
                shareCalendarContext: false,
                shareHistorySummaries: true,
                shareExerciseLogs: true,
                shareUserNotes: false,
                shareTemplatesAndVariants: true
            )
        )
        store.preferences = updated

        let reloadedStore = UserPreferencesStore(fileURL: fileURL)

        XCTAssertEqual(reloadedStore.preferences, updated)
    }

    @MainActor
    func testTogglesPersistAcrossStoreInit() throws {
        let directoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("user_preferences.json")

        let store = UserPreferencesStore(fileURL: fileURL)
        var updated = store.preferences
        updated.calendarSyncEnabled.toggle()
        updated.healthKitSyncEnabled.toggle()
        store.preferences = updated

        let reloadedStore = UserPreferencesStore(fileURL: fileURL)

        XCTAssertEqual(reloadedStore.preferences.calendarSyncEnabled, updated.calendarSyncEnabled)
        XCTAssertEqual(reloadedStore.preferences.healthKitSyncEnabled, updated.healthKitSyncEnabled)
    }

    @MainActor
    func testReloadOverwritesInMemoryPreferences() throws {
        let directoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("user_preferences.json")

        let store = UserPreferencesStore(fileURL: fileURL)
        var initial = store.preferences
        initial.calendarSyncEnabled = true
        store.preferences = initial

        let diskPreferences = UserPreferences(
            calendarSyncEnabled: false,
            healthKitSyncEnabled: false,
            discovery: DiscoveryPreferences(targetDuration: .short)
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(diskPreferences)
        try data.write(to: fileURL, options: [.atomic])

        store.reload()

        XCTAssertEqual(store.preferences, diskPreferences)
    }

    @MainActor
    func testWriteFailureDoesNotCrash() throws {
        let directoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = UserPreferencesStore(fileURL: directoryURL)
        var updated = store.preferences
        updated.calendarSyncEnabled = true
        store.preferences = updated

        XCTAssertTrue(FileManager.default.fileExists(atPath: directoryURL.path))
        XCTAssertTrue(store.preferences.calendarSyncEnabled)
    }

    @MainActor
    func testLegacyPreferencesDecodeFallsBackForMissingLLM() throws {
        let directoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("user_preferences.json")

        let legacy = LegacyUserPreferences(
            calendarSyncEnabled: true,
            healthKitSyncEnabled: false,
            discovery: DiscoveryPreferences(targetDuration: .medium)
        )
        let data = try JSONEncoder().encode(legacy)
        try data.write(to: fileURL, options: [.atomic])

        let store = UserPreferencesStore(fileURL: fileURL)

        XCTAssertTrue(store.preferences.calendarSyncEnabled)
        XCTAssertFalse(store.preferences.healthKitSyncEnabled)
        XCTAssertEqual(store.preferences.discovery.targetDuration, .medium)
        XCTAssertEqual(store.preferences.llm, LLMPreferences())
    }

    @MainActor
    func testAPIKeySaveAndClearUpdatesRuntimeState() throws {
        let directoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("user_preferences.json")
        let keychain = InMemoryAPIKeyStore()

        let store = UserPreferencesStore(
            fileURL: fileURL,
            apiKeyStore: keychain,
            apiKeyService: "WorkoutAppTests"
        )
        var preferences = store.preferences
        preferences.llm.enabled = true
        store.preferences = preferences

        XCTAssertEqual(store.llmRuntimeState(isNetworkAvailable: true), .missingAPIKey)
        XCTAssertTrue(store.saveLLMAPIKey("test-key"))
        XCTAssertTrue(store.hasLLMAPIKey)
        XCTAssertEqual(store.llmRuntimeState(isNetworkAvailable: true), .ready)
        XCTAssertEqual(store.llmRuntimeState(isNetworkAvailable: false), .offline)

        store.clearLLMAPIKey()
        XCTAssertFalse(store.hasLLMAPIKey)
        XCTAssertEqual(store.llmRuntimeState(isNetworkAvailable: true), .missingAPIKey)
    }

    private func makeTempDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        return directoryURL
    }
}

private struct LegacyUserPreferences: Codable {
    var calendarSyncEnabled: Bool
    var healthKitSyncEnabled: Bool
    var discovery: DiscoveryPreferences
}

private final class InMemoryAPIKeyStore: APIKeyStoring {
    private var values: [String: String] = [:]

    func save(value: String, service: String, account: String) throws {
        values[key(service: service, account: account)] = value
    }

    func load(service: String, account: String) throws -> String? {
        values[key(service: service, account: account)]
    }

    func delete(service: String, account: String) throws {
        values.removeValue(forKey: key(service: service, account: account))
    }

    private func key(service: String, account: String) -> String {
        "\(service):\(account)"
    }
}
