import Foundation

struct UserPreferences: Codable, Hashable {
    var calendarSyncEnabled: Bool
    var healthKitSyncEnabled: Bool
    var discovery: DiscoveryPreferences

    static let `default` = UserPreferences(
        calendarSyncEnabled: false,
        healthKitSyncEnabled: true,
        discovery: DiscoveryPreferences()
    )
}

struct DiscoveryPreferences: Codable, Hashable {
    var targetDuration: PreferredDuration?
    var location: WorkoutLocationPreference?
    var equipmentTags: [String]
    var focusTags: [String]
    var includeTemplates: Bool
    var includeExternalSources: Bool
    var excludedTags: [String]
    var minimumRestDaysByCategory: [String: Int]

    init(
        targetDuration: PreferredDuration? = nil,
        location: WorkoutLocationPreference? = nil,
        equipmentTags: [String] = [],
        focusTags: [String] = [],
        includeTemplates: Bool = true,
        includeExternalSources: Bool = false,
        excludedTags: [String] = [],
        minimumRestDaysByCategory: [String: Int] = [:]
    ) {
        self.targetDuration = targetDuration
        self.location = location
        self.equipmentTags = equipmentTags
        self.focusTags = focusTags
        self.includeTemplates = includeTemplates
        self.includeExternalSources = includeExternalSources
        self.excludedTags = excludedTags
        self.minimumRestDaysByCategory = minimumRestDaysByCategory
    }
}

enum PreferredDuration: String, Codable, Hashable, CaseIterable {
    case short
    case medium
    case long
}

enum WorkoutLocationPreference: String, Codable, Hashable, CaseIterable {
    case home
    case gym
    case away
}

@MainActor
final class UserPreferencesStore: ObservableObject {
    @Published var preferences: UserPreferences {
        didSet {
            if isLoaded {
                savePreferences()
            }
        }
    }

    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var isLoaded = false

    init(fileURL: URL = UserPreferencesStore.defaultFileURL()) {
        self.fileURL = fileURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        self.preferences = Self.loadPreferences(from: fileURL, decoder: decoder)
        self.isLoaded = true
    }

    func reload() {
        preferences = Self.loadPreferences(from: fileURL, decoder: decoder)
    }

    private func savePreferences() {
        do {
            let data = try encoder.encode(preferences)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Best-effort persistence; keep UI responsive if disk write fails.
        }
    }

    private static func loadPreferences(from fileURL: URL, decoder: JSONDecoder) -> UserPreferences {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(UserPreferences.self, from: data)
        } catch {
            return .default
        }
    }

    nonisolated private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("WorkoutApp", isDirectory: true)
            .appendingPathComponent("user_preferences.json")
    }
}
