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

struct RecommendationWeights: Codable, Hashable {
    var focusPreferenceBoost: Double
    var durationMatchBoost: Double
    var equipmentMatchBoost: Double
    var locationMatchBoost: Double
    var noveltyBoost: Double
    var repeatPenalty: Double

    init(
        focusPreferenceBoost: Double = 1.2,
        durationMatchBoost: Double = 0.8,
        equipmentMatchBoost: Double = 0.5,
        locationMatchBoost: Double = 0.4,
        noveltyBoost: Double = 0.7,
        repeatPenalty: Double = 1.0
    ) {
        self.focusPreferenceBoost = focusPreferenceBoost
        self.durationMatchBoost = durationMatchBoost
        self.equipmentMatchBoost = equipmentMatchBoost
        self.locationMatchBoost = locationMatchBoost
        self.noveltyBoost = noveltyBoost
        self.repeatPenalty = repeatPenalty
    }
}

struct RecommendationReason: Hashable {
    var text: String
    var contribution: Double
}

struct RankedWorkout: Identifiable, Hashable {
    var workout: WorkoutDefinition
    var score: Double
    var reasons: [RecommendationReason]

    var id: WorkoutID { workout.id }

    var primaryReason: String {
        reasons.sorted { abs($0.contribution) > abs($1.contribution) }.first?.text ?? "General fit for your profile"
    }
}

struct WorkoutRecommendationEngine {
    func rank(
        workouts: [WorkoutDefinition],
        history: [WorkoutSession],
        preferences: DiscoveryPreferences,
        now: Date = Date(),
        limit: Int = 25
    ) -> [RankedWorkout] {
        let sortedHistory = history.sorted { sessionDate(for: $0) > sessionDate(for: $1) }
        let workoutByID = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })

        let scored = workouts.compactMap { workout in
            score(
                workout: workout,
                history: sortedHistory,
                workoutByID: workoutByID,
                preferences: preferences,
                now: now
            )
        }

        return scored
            .sorted {
                if $0.score == $1.score {
                    return $0.workout.title.localizedCaseInsensitiveCompare($1.workout.title) == .orderedAscending
                }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    private func score(
        workout: WorkoutDefinition,
        history: [WorkoutSession],
        workoutByID: [WorkoutID: WorkoutDefinition],
        preferences: DiscoveryPreferences,
        now: Date
    ) -> RankedWorkout? {
        guard isSourceAllowed(workout.source, preferences: preferences) else {
            return nil
        }

        let tags = allTags(for: workout)
        let excluded = Set(preferences.excludedTags.map(normalizeTag)).filter { !$0.isEmpty }
        if !excluded.isEmpty, !tags.intersection(excluded).isEmpty {
            return nil
        }

        let workoutFocus = focusTags(for: workout)
        for (category, minimumRestDays) in preferences.minimumRestDaysByCategory {
            let normalizedCategory = normalizeTag(category)
            guard minimumRestDays > 0, workoutFocus.contains(normalizedCategory) else {
                continue
            }
            if let lastDate = mostRecentSessionDate(
                matchingCategory: normalizedCategory,
                history: history,
                workoutByID: workoutByID
            ) {
                let days = daysSince(lastDate, now: now)
                if days < minimumRestDays {
                    return nil
                }
            }
        }

        var score = 1.0
        var reasons: [RecommendationReason] = []
        let weights = preferences.recommendationWeights

        let preferredFocus = Set(preferences.focusTags.map(normalizeTag)).filter { !$0.isEmpty }
        if !preferredFocus.isEmpty {
            let matches = workoutFocus.intersection(preferredFocus).count
            if matches > 0 {
                let contribution = Double(matches) / Double(preferredFocus.count) * weights.focusPreferenceBoost
                score += contribution
                reasons.append(RecommendationReason(text: "Matches your focus preferences", contribution: contribution))
            }
        }

        let preferredEquipment = Set(preferences.equipmentTags.map(normalizeTag)).filter { !$0.isEmpty }
        if !preferredEquipment.isEmpty {
            let workoutEquipment = equipmentTags(for: workout)
            let matches = workoutEquipment.intersection(preferredEquipment).count
            if matches > 0 {
                let contribution = Double(matches) / Double(preferredEquipment.count) * weights.equipmentMatchBoost
                score += contribution
                reasons.append(RecommendationReason(text: "Uses preferred equipment", contribution: contribution))
            }
        }

        if let preferredLocation = preferences.location {
            let target = normalizeTag(preferredLocation.rawValue)
            if let workoutLocation = locationTag(for: workout) {
                if workoutLocation == target {
                    score += weights.locationMatchBoost
                    reasons.append(RecommendationReason(text: "Matches your preferred location", contribution: weights.locationMatchBoost))
                } else {
                    let penalty = weights.locationMatchBoost * 0.5
                    score -= penalty
                    reasons.append(RecommendationReason(text: "Different location than preferred", contribution: -penalty))
                }
            }
        }

        if let preferredDuration = preferences.targetDuration, let workoutDuration = durationPreference(for: workout) {
            let contribution: Double
            if workoutDuration == preferredDuration {
                contribution = weights.durationMatchBoost
                reasons.append(RecommendationReason(text: "Fits your target duration", contribution: contribution))
            } else if areAdjacent(preferredDuration, workoutDuration) {
                contribution = weights.durationMatchBoost * 0.35
                reasons.append(RecommendationReason(text: "Close to your target duration", contribution: contribution))
            } else {
                contribution = -weights.durationMatchBoost * 0.45
                reasons.append(RecommendationReason(text: "Outside your target duration", contribution: contribution))
            }
            score += contribution
        }

        if let lastSameWorkoutDate = history.first(where: { $0.workout.id == workout.id }).map(sessionDate(for:)) {
            let days = max(0, daysSince(lastSameWorkoutDate, now: now))
            let dampening = max(0.15, 1.0 - (Double(days) / 7.0))
            let penalty = weights.repeatPenalty * dampening
            score -= penalty
            reasons.append(RecommendationReason(text: "Avoids repeating recent sessions", contribution: -penalty))
        }

        let recentFocus = recentFocusTags(history: history, workoutByID: workoutByID, limit: 5)
        if !workoutFocus.isEmpty, workoutFocus.intersection(recentFocus).isEmpty {
            score += weights.noveltyBoost
            reasons.append(RecommendationReason(text: "Balances recent training focus", contribution: weights.noveltyBoost))
        }

        return RankedWorkout(workout: workout, score: score, reasons: reasons)
    }

    private func isSourceAllowed(_ source: WorkoutSource, preferences: DiscoveryPreferences) -> Bool {
        if source == .template && !preferences.includeTemplates {
            return false
        }
        if source == .external && !preferences.includeExternalSources {
            return false
        }
        return true
    }

    private func recentFocusTags(
        history: [WorkoutSession],
        workoutByID: [WorkoutID: WorkoutDefinition],
        limit: Int
    ) -> Set<String> {
        Set(history.prefix(limit).flatMap { session in
            if let workout = workoutByID[session.workout.id] {
                return Array(focusTags(for: workout))
            }
            return inferFocusTags(from: session.workout.title)
        })
    }

    private func mostRecentSessionDate(
        matchingCategory category: String,
        history: [WorkoutSession],
        workoutByID: [WorkoutID: WorkoutDefinition]
    ) -> Date? {
        history.first { session in
            if let workout = workoutByID[session.workout.id] {
                return focusTags(for: workout).contains(category)
            }
            return inferFocusTags(from: session.workout.title).contains(category)
        }
        .map(sessionDate(for:))
    }

    private func allTags(for workout: WorkoutDefinition) -> Set<String> {
        Set(
            workout.metadata.focusTags.map(normalizeTag) +
            workout.metadata.equipmentTags.map(normalizeTag) +
            workout.metadata.otherTags.map(normalizeTag) +
            inferFocusTags(from: workout.title)
        )
    }

    private func focusTags(for workout: WorkoutDefinition) -> Set<String> {
        let explicit = workout.metadata.focusTags.map(normalizeTag).filter { !$0.isEmpty }
        if !explicit.isEmpty {
            return Set(explicit)
        }
        return Set(inferFocusTags(from: workout.title))
    }

    private func equipmentTags(for workout: WorkoutDefinition) -> Set<String> {
        let explicit = workout.metadata.equipmentTags.map(normalizeTag).filter { !$0.isEmpty }
        if !explicit.isEmpty {
            return Set(explicit)
        }

        let haystack = (workout.title + " " + workout.content.sourceMarkdown).lowercased()
        var tags: [String] = []
        if haystack.contains("bodyweight") {
            tags.append("bodyweight")
        }
        if haystack.contains("dumbbell") {
            tags.append("dumbbell")
        }
        if haystack.contains("barbell") {
            tags.append("barbell")
        }
        if haystack.contains("band") {
            tags.append("band")
        }
        if haystack.contains("kettlebell") {
            tags.append("kettlebell")
        }
        return Set(tags)
    }

    private func locationTag(for workout: WorkoutDefinition) -> String? {
        if let location = workout.metadata.locationTag, !location.isEmpty {
            return normalizeTag(location)
        }
        let title = workout.title.lowercased()
        if title.contains("home") {
            return "home"
        }
        if title.contains("away") {
            return "away"
        }
        if title.contains("gym") {
            return "gym"
        }
        return nil
    }

    private func durationPreference(for workout: WorkoutDefinition) -> PreferredDuration? {
        if let minutes = workout.metadata.durationMinutes {
            return durationBucket(for: minutes)
        }

        let markdown = workout.content.sourceMarkdown.lowercased()
        if let minutes = extractDurationMinutes(from: markdown) {
            return durationBucket(for: minutes)
        }
        return nil
    }

    private func durationBucket(for minutes: Int) -> PreferredDuration {
        if minutes <= 20 {
            return .short
        }
        if minutes <= 40 {
            return .medium
        }
        return .long
    }

    private func extractDurationMinutes(from text: String) -> Int? {
        let pattern = "\\b(\\d{1,3})\\s*(?:min|mins|minutes)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let minutesRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(String(text[minutesRange]))
    }

    private func areAdjacent(_ lhs: PreferredDuration, _ rhs: PreferredDuration) -> Bool {
        switch (lhs, rhs) {
        case (.short, .medium), (.medium, .short), (.medium, .long), (.long, .medium):
            return true
        default:
            return false
        }
    }

    private func inferFocusTags(from text: String) -> [String] {
        let value = text.lowercased()
        var tags: [String] = []
        if value.contains("strength") || value.contains("squat") || value.contains("hinge") || value.contains("press") || value.contains("pull") {
            tags.append("strength")
        }
        if value.contains("mobility") || value.contains("stretch") {
            tags.append("mobility")
        }
        if value.contains("recovery") {
            tags.append("recovery")
        }
        if value.contains("bodyweight") {
            tags.append("bodyweight")
        }
        return tags
    }

    private func normalizeTag(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func sessionDate(for session: WorkoutSession) -> Date {
        session.endedAt ?? session.startedAt
    }

    private func daysSince(_ date: Date, now: Date) -> Int {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
