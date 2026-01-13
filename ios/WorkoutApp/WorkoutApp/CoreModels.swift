import Foundation

typealias WorkoutID = String

enum WorkoutSource: String, Codable, Hashable {
    case knowledgeBase
    case template
    case variant
    case external
    case generated
}

struct WorkoutReference: Codable, Hashable {
    let id: WorkoutID
    let source: WorkoutSource
    var title: String
    var versionHash: String?
}

struct WorkoutMetadata: Codable, Hashable {
    var durationMinutes: Int?
    var focusTags: [String]
    var equipmentTags: [String]
    var locationTag: String?
    var otherTags: [String]
}

struct WorkoutContent: Codable, Hashable {
    var sourceMarkdown: String
    var parsedSections: [WorkoutSection]?
    var notes: String?
}

struct WorkoutSection: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String?
    var items: [WorkoutItem]

    init(id: UUID = UUID(), title: String, detail: String? = nil, items: [WorkoutItem]) {
        self.id = id
        self.title = title
        self.detail = detail
        self.items = items
    }
}

struct WorkoutItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var prescription: String?
    var notes: String?

    init(id: UUID = UUID(), name: String, prescription: String? = nil, notes: String? = nil) {
        self.id = id
        self.name = name
        self.prescription = prescription
        self.notes = notes
    }
}

struct TimerConfiguration: Codable, Hashable {
    var mode: TimerMode
    var workSeconds: Int?
    var restSeconds: Int?
    var rounds: Int?
    var totalSeconds: Int?
}

enum TimerMode: String, Codable, Hashable {
    case emom
    case interval
    case amrap
    case countdown
    case stopwatch
}

struct WorkoutDefinition: Identifiable, Codable, Hashable {
    let id: WorkoutID
    var source: WorkoutSource
    var sourceID: String?
    var sourceURL: URL?
    var title: String
    var summary: String?
    var metadata: WorkoutMetadata
    var content: WorkoutContent
    var timerConfiguration: TimerConfiguration?
    var versionHash: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct WorkoutTemplate: Identifiable, Codable, Hashable {
    let id: WorkoutID
    var baseWorkoutID: WorkoutID?
    var baseVersionHash: String?
    var title: String
    var summary: String?
    var metadata: WorkoutMetadata
    var content: WorkoutContent
    var timerConfiguration: TimerConfiguration?
    var createdAt: Date
    var updatedAt: Date
}

struct WorkoutVariant: Identifiable, Codable, Hashable {
    let id: WorkoutID
    var baseWorkoutID: WorkoutID
    var baseVersionHash: String?
    var overrides: WorkoutVariantOverrides
    var createdAt: Date
    var updatedAt: Date
}

struct WorkoutVariantOverrides: Codable, Hashable {
    var title: String?
    var summary: String?
    var metadata: WorkoutMetadata?
    var content: WorkoutContent?
    var timerConfiguration: TimerConfiguration?
    var substitutions: [ExerciseSubstitution]
    var notes: String?
}

struct ExerciseSubstitution: Identifiable, Codable, Hashable {
    let id: UUID
    var fromExercise: String
    var toExercise: String
    var reason: String?

    init(id: UUID = UUID(), fromExercise: String, toExercise: String, reason: String? = nil) {
        self.id = id
        self.fromExercise = fromExercise
        self.toExercise = toExercise
        self.reason = reason
    }
}

struct WorkoutSession: Identifiable, Codable, Hashable {
    let id: UUID
    var workout: WorkoutReference
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int?
    var timerMode: TimerMode?
    var logEntries: [ExerciseLog]
    var notes: String?
    var perceivedExertion: Int?
}

struct ExerciseLog: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseName: String
    var sets: [ExerciseSet]
    var notes: String?

    init(id: UUID = UUID(), exerciseName: String, sets: [ExerciseSet], notes: String? = nil) {
        self.id = id
        self.exerciseName = exerciseName
        self.sets = sets
        self.notes = notes
    }
}

struct ExerciseSet: Identifiable, Codable, Hashable {
    let id: UUID
    var reps: Int?
    var weight: Double?
    var weightUnit: WeightUnit?
    var durationSeconds: Int?
    var completed: Bool

    init(
        id: UUID = UUID(),
        reps: Int? = nil,
        weight: Double? = nil,
        weightUnit: WeightUnit? = nil,
        durationSeconds: Int? = nil,
        completed: Bool = true
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.weightUnit = weightUnit
        self.durationSeconds = durationSeconds
        self.completed = completed
    }
}

enum WeightUnit: String, Codable, Hashable {
    case pounds
    case kilograms
}

struct WorkoutHistory: Codable, Hashable {
    var sessions: [WorkoutSession]
}

struct HistorySummary: Codable, Hashable {
    var weekStart: Date
    var sessionCount: Int
    var totalMinutes: Int
    var personalRecordCount: Int
}

struct SessionSummary: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var completedAt: Date
    var durationMinutes: Int
    var source: WorkoutSource
}
