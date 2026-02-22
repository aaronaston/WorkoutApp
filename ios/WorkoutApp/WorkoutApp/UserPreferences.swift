import Foundation
import Security

struct UserPreferences: Codable, Hashable {
    var calendarSyncEnabled: Bool
    var healthKitSyncEnabled: Bool
    var discovery: DiscoveryPreferences
    var llm: LLMPreferences

    static let `default` = UserPreferences(
        calendarSyncEnabled: false,
        healthKitSyncEnabled: true,
        discovery: DiscoveryPreferences(),
        llm: LLMPreferences()
    )

    private enum CodingKeys: String, CodingKey {
        case calendarSyncEnabled
        case healthKitSyncEnabled
        case discovery
        case llm
    }

    init(
        calendarSyncEnabled: Bool,
        healthKitSyncEnabled: Bool,
        discovery: DiscoveryPreferences,
        llm: LLMPreferences = LLMPreferences()
    ) {
        self.calendarSyncEnabled = calendarSyncEnabled
        self.healthKitSyncEnabled = healthKitSyncEnabled
        self.discovery = discovery
        self.llm = llm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendarSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .calendarSyncEnabled) ?? false
        healthKitSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .healthKitSyncEnabled) ?? true
        discovery = try container.decodeIfPresent(DiscoveryPreferences.self, forKey: .discovery) ?? DiscoveryPreferences()
        llm = try container.decodeIfPresent(LLMPreferences.self, forKey: .llm) ?? LLMPreferences()
    }
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
    var recommendationWeights: RecommendationWeights

    init(
        targetDuration: PreferredDuration? = nil,
        location: WorkoutLocationPreference? = nil,
        equipmentTags: [String] = [],
        focusTags: [String] = [],
        includeTemplates: Bool = true,
        includeExternalSources: Bool = false,
        excludedTags: [String] = [],
        minimumRestDaysByCategory: [String: Int] = [:],
        recommendationWeights: RecommendationWeights = RecommendationWeights()
    ) {
        self.targetDuration = targetDuration
        self.location = location
        self.equipmentTags = equipmentTags
        self.focusTags = focusTags
        self.includeTemplates = includeTemplates
        self.includeExternalSources = includeExternalSources
        self.excludedTags = excludedTags
        self.minimumRestDaysByCategory = minimumRestDaysByCategory
        self.recommendationWeights = recommendationWeights
    }

    private enum CodingKeys: String, CodingKey {
        case targetDuration
        case location
        case equipmentTags
        case focusTags
        case includeTemplates
        case includeExternalSources
        case excludedTags
        case minimumRestDaysByCategory
        case recommendationWeights
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetDuration = try container.decodeIfPresent(PreferredDuration.self, forKey: .targetDuration)
        location = try container.decodeIfPresent(WorkoutLocationPreference.self, forKey: .location)
        equipmentTags = try container.decodeIfPresent([String].self, forKey: .equipmentTags) ?? []
        focusTags = try container.decodeIfPresent([String].self, forKey: .focusTags) ?? []
        includeTemplates = try container.decodeIfPresent(Bool.self, forKey: .includeTemplates) ?? true
        includeExternalSources = try container.decodeIfPresent(Bool.self, forKey: .includeExternalSources) ?? false
        excludedTags = try container.decodeIfPresent([String].self, forKey: .excludedTags) ?? []
        minimumRestDaysByCategory = try container.decodeIfPresent([String: Int].self, forKey: .minimumRestDaysByCategory) ?? [:]
        recommendationWeights = try container.decodeIfPresent(RecommendationWeights.self, forKey: .recommendationWeights) ?? RecommendationWeights()
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

enum LLMProvider: String, Codable, Hashable, CaseIterable, Identifiable {
    case openAI = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        }
    }
}

enum LLMPromptDetailLevel: String, Codable, Hashable, CaseIterable, Identifiable {
    case summary
    case raw
    case augmented

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .summary:
            return "Summary"
        case .raw:
            return "Raw"
        case .augmented:
            return "Augmented"
        }
    }
}

struct LLMPreferences: Codable, Hashable {
    var enabled: Bool
    var provider: LLMProvider
    var modelID: String
    var promptDetailLevel: LLMPromptDetailLevel
    var shareCalendarContext: Bool
    var shareHistorySummaries: Bool
    var shareExerciseLogs: Bool
    var shareUserNotes: Bool
    var shareTemplatesAndVariants: Bool

    init(
        enabled: Bool = false,
        provider: LLMProvider = .openAI,
        modelID: String = "gpt-5-mini",
        promptDetailLevel: LLMPromptDetailLevel = .augmented,
        shareCalendarContext: Bool = true,
        shareHistorySummaries: Bool = true,
        shareExerciseLogs: Bool = true,
        shareUserNotes: Bool = true,
        shareTemplatesAndVariants: Bool = true
    ) {
        self.enabled = enabled
        self.provider = provider
        self.modelID = modelID
        self.promptDetailLevel = promptDetailLevel
        self.shareCalendarContext = shareCalendarContext
        self.shareHistorySummaries = shareHistorySummaries
        self.shareExerciseLogs = shareExerciseLogs
        self.shareUserNotes = shareUserNotes
        self.shareTemplatesAndVariants = shareTemplatesAndVariants
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case provider
        case modelID
        case promptDetailLevel
        case shareCalendarContext
        case shareHistorySummaries
        case shareExerciseLogs
        case shareUserNotes
        case shareTemplatesAndVariants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        provider = try container.decodeIfPresent(LLMProvider.self, forKey: .provider) ?? .openAI
        modelID = try container.decodeIfPresent(String.self, forKey: .modelID) ?? "gpt-5-mini"
        promptDetailLevel = try container.decodeIfPresent(LLMPromptDetailLevel.self, forKey: .promptDetailLevel) ?? .augmented
        shareCalendarContext = try container.decodeIfPresent(Bool.self, forKey: .shareCalendarContext) ?? true
        shareHistorySummaries = try container.decodeIfPresent(Bool.self, forKey: .shareHistorySummaries) ?? true
        shareExerciseLogs = try container.decodeIfPresent(Bool.self, forKey: .shareExerciseLogs) ?? true
        shareUserNotes = try container.decodeIfPresent(Bool.self, forKey: .shareUserNotes) ?? true
        shareTemplatesAndVariants = try container.decodeIfPresent(Bool.self, forKey: .shareTemplatesAndVariants) ?? true
    }
}

enum LLMRuntimeState: Equatable {
    case disabled
    case missingAPIKey
    case offline
    case ready
}

protocol APIKeyStoring {
    func save(value: String, service: String, account: String) throws
    func load(service: String, account: String) throws -> String?
    func delete(service: String, account: String) throws
}

enum KeychainStoreError: Error {
    case unexpectedStatus(OSStatus)
}

struct KeychainAPIKeyStore: APIKeyStoring {
    func save(value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var createQuery = baseQuery
            createQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(createQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(addStatus)
            }
            return
        }

        throw KeychainStoreError.unexpectedStatus(updateStatus)
    }

    func load(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainStoreError.unexpectedStatus(status)
    }
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
    @Published private(set) var hasLLMAPIKey: Bool = false

    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let apiKeyStore: APIKeyStoring
    private let apiKeyService: String
    private let apiKeyAccount = "llm_api_key"
    private var isLoaded = false

    init(
        fileURL: URL = UserPreferencesStore.defaultFileURL(),
        apiKeyStore: APIKeyStoring = KeychainAPIKeyStore(),
        apiKeyService: String = Bundle.main.bundleIdentifier ?? "WorkoutApp"
    ) {
        self.fileURL = fileURL
        self.apiKeyStore = apiKeyStore
        self.apiKeyService = apiKeyService

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        self.preferences = Self.loadPreferences(from: fileURL, decoder: decoder)
        self.hasLLMAPIKey = Self.loadLLMAPIKey(
            from: apiKeyStore,
            service: apiKeyService,
            account: apiKeyAccount
        ) != nil
        self.isLoaded = true
    }

    func reload() {
        preferences = Self.loadPreferences(from: fileURL, decoder: decoder)
        hasLLMAPIKey = Self.loadLLMAPIKey(from: apiKeyStore, service: apiKeyService, account: apiKeyAccount) != nil
    }

    func saveLLMAPIKey(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return false
        }

        do {
            try apiKeyStore.save(value: normalized, service: apiKeyService, account: apiKeyAccount)
            hasLLMAPIKey = true
            return true
        } catch {
            return false
        }
    }

    func clearLLMAPIKey() {
        do {
            try apiKeyStore.delete(service: apiKeyService, account: apiKeyAccount)
            hasLLMAPIKey = false
        } catch {
            hasLLMAPIKey = Self.loadLLMAPIKey(
                from: apiKeyStore,
                service: apiKeyService,
                account: apiKeyAccount
            ) != nil
        }
    }

    func llmRuntimeState(isNetworkAvailable: Bool) -> LLMRuntimeState {
        guard preferences.llm.enabled else {
            return .disabled
        }
        guard hasLLMAPIKey else {
            return .missingAPIKey
        }
        guard isNetworkAvailable else {
            return .offline
        }
        return .ready
    }

    func llmAPIKey() -> String? {
        Self.loadLLMAPIKey(from: apiKeyStore, service: apiKeyService, account: apiKeyAccount)
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

    private static func loadLLMAPIKey(from store: APIKeyStoring, service: String, account: String) -> String? {
        do {
            return try store.load(service: service, account: account)
        } catch {
            return nil
        }
    }

    nonisolated private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("WorkoutApp", isDirectory: true)
            .appendingPathComponent("user_preferences.json")
    }
}
