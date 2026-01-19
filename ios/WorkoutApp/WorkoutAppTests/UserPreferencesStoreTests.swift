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
