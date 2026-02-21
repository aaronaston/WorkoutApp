import Network
import Markdown
import SwiftUI

enum AppTab: Hashable {
    case discover
    case session
    case history
    case settings
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DiscoveryView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Discover", systemImage: "sparkles")
            }
            .tag(AppTab.discover)

            NavigationStack {
                SessionView()
            }
            .tabItem {
                Label("Session", systemImage: "timer")
            }
            .tag(AppTab.session)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "chart.bar")
            }
            .tag(AppTab.history)

            NavigationStack {
                SettingsMockView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum DurationFilter: String, CaseIterable, Identifiable {
    case short = "<= 20 min"
    case medium = "25-40 min"
    case long = "45+ min"

    var id: String { rawValue }
}

struct DiscoveryView: View {
    @EnvironmentObject private var preferencesStore: UserPreferencesStore
    @EnvironmentObject private var sessionStore: WorkoutSessionStore
    @Binding var selectedTab: AppTab
    @State private var workouts: [WorkoutDefinition] = []
    @State private var loadError: String?
    @State private var hasLoaded = false
    @State private var searchQuery = ""
    @State private var searchResults: [WorkoutSearchResult] = []
    @State private var searchIndex: WorkoutSearchIndex?
    @State private var searchTask: Task<Void, Never>?
    @State private var isLoadingWorkouts = false
    @State private var selectedEquipment: Set<String> = []
    @State private var selectedLocations: Set<String> = []
    @State private var selectedDurations: Set<DurationFilter> = []

    private let equipmentFilterOptions = ["Bodyweight", "Dumbbell", "Barbell", "Band", "Kettlebell"]
    private let locationFilterOptions = ["Home", "Gym", "Away"]
    private let recommendationEngine = WorkoutRecommendationEngine()

    private var recommendationsByWorkoutID: [WorkoutID: RankedWorkout] {
        Dictionary(uniqueKeysWithValues: rankedWorkouts.map { ($0.workout.id, $0) })
    }

    private var rankedWorkouts: [RankedWorkout] {
        recommendationEngine.rank(
            workouts: workouts,
            history: sessionStore.sessions,
            preferences: preferencesStore.preferences.discovery
        )
    }

    private var filteredRecommendations: [RankedWorkout] {
        rankedWorkouts.filter { workoutMatchesFilters($0.workout) }
    }

    private var highlightedWorkout: WorkoutDefinition? {
        filteredRecommendations.first?.workout
    }

    private var hasActiveFilters: Bool {
        !selectedEquipment.isEmpty || !selectedLocations.isEmpty || !selectedDurations.isEmpty
    }

    private var filteredSearchResults: [WorkoutSearchResult] {
        searchResults.filter { workoutMatchesFilters($0.workout) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout Discovery")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text("Find a workout that fits your day.")
                        .foregroundStyle(.secondary)
                }

                SearchField(text: $searchQuery, placeholder: "Search workouts, equipment, or goals")

                if isLoadingWorkouts, !workouts.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading more workouts...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let loadError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unable to load workouts")
                            .font(.headline)
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if workouts.isEmpty {
                    ProgressView("Loading workouts...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Results")
                            .font(.headline)

                        if filteredSearchResults.isEmpty {
                            Text(hasActiveFilters ? "No workouts match that search and filters." : "No workouts match that search.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredSearchResults) { result in
                                NavigationLink {
                                    WorkoutDetailView(
                                        workout: result.workout,
                                        recommendation: recommendationsByWorkoutID[result.workout.id],
                                        selectedTab: $selectedTab
                                    )
                                } label: {
                                    WorkoutRow(workout: result.workout, recommendation: recommendationsByWorkoutID[result.workout.id])
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    if filteredRecommendations.isEmpty {
                        Text(hasActiveFilters ? "No workouts match those filters." : "No workouts available.")
                            .foregroundStyle(.secondary)
                    } else {
                        if let highlightedWorkout {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today")
                                    .font(.headline)

                                NavigationLink {
                                    WorkoutDetailView(
                                        workout: highlightedWorkout,
                                        recommendation: recommendationsByWorkoutID[highlightedWorkout.id],
                                        selectedTab: $selectedTab
                                    )
                                } label: {
                                    HighlightCard(
                                        title: highlightedWorkout.title,
                                        subtitle: sectionSummary(for: highlightedWorkout),
                                        detail: recommendationsByWorkoutID[highlightedWorkout.id]?.primaryReason ?? "Loaded from the knowledge base"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended")
                                .font(.headline)

                            ForEach(filteredRecommendations) { rankedWorkout in
                                NavigationLink {
                                    WorkoutDetailView(
                                        workout: rankedWorkout.workout,
                                        recommendation: rankedWorkout,
                                        selectedTab: $selectedTab
                                    )
                                } label: {
                                    WorkoutRow(workout: rankedWorkout.workout, recommendation: rankedWorkout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Filters")
                            .font(.headline)

                        if hasActiveFilters {
                            Button("Clear") {
                                selectedEquipment.removeAll()
                                selectedLocations.removeAll()
                                selectedDurations.removeAll()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Equipment")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(equipmentFilterOptions, id: \.self) { option in
                                    FilterChip(
                                        title: option,
                                        isSelected: selectedEquipment.contains(option)
                                    ) {
                                        toggleSelection(option, set: $selectedEquipment)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DurationFilter.allCases) { option in
                                    FilterChip(
                                        title: option.rawValue,
                                        isSelected: selectedDurations.contains(option)
                                    ) {
                                        toggleSelection(option, set: $selectedDurations)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(locationFilterOptions, id: \.self) { option in
                                    FilterChip(
                                        title: option,
                                        isSelected: selectedLocations.contains(option)
                                    ) {
                                        toggleSelection(option, set: $selectedLocations)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Discover")
        .task {
            loadWorkoutsIfNeeded()
        }
        .onChange(of: searchQuery) { _, _ in
            scheduleSearch()
        }
    }

    private func sectionSummary(for workout: WorkoutDefinition) -> String {
        let titles = workout.content.parsedSections?.prefix(3).map { $0.title } ?? []
        if titles.isEmpty {
            return "Knowledge base workout"
        }
        return titles.joined(separator: " / ")
    }

    private func loadWorkoutsIfNeeded() {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true
        loadError = nil
        isLoadingWorkouts = true
        workouts = []
        searchIndex = WorkoutSearchIndex(workouts: [])
        Task.detached(priority: .userInitiated) {
            do {
                try await KnowledgeBaseLoader().loadWorkoutsIncrementally(batchSize: 8) { batch in
                    guard !batch.isEmpty else {
                        return
                    }
                    workouts.append(contentsOf: batch)
                }
                let loadedWorkouts = await MainActor.run { workouts }
                let index = await Task.detached(priority: .userInitiated) {
                    WorkoutSearchIndex(workouts: loadedWorkouts)
                }.value
                await MainActor.run {
                    searchIndex = index
                    isLoadingWorkouts = false
                    scheduleSearch()
                }
            } catch {
                await MainActor.run {
                    isLoadingWorkouts = false
                    loadError = error.localizedDescription
                }
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery
        let index = searchIndex
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else {
                return
            }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let index else {
                await MainActor.run {
                    searchResults = []
                }
                return
            }
            let results = await Task.detached(priority: .userInitiated) {
                index.search(query: trimmed, limit: 25)
            }.value
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                searchResults = results
            }
        }
    }

    private func workoutMatchesFilters(_ workout: WorkoutDefinition) -> Bool {
        if !selectedEquipment.isEmpty {
            let equipment = workoutEquipmentTags(for: workout)
            if equipment.intersection(selectedEquipment).isEmpty {
                return false
            }
        }

        if !selectedLocations.isEmpty {
            guard let location = workoutLocationTag(for: workout) else {
                return false
            }
            if !selectedLocations.contains(location) {
                return false
            }
        }

        if !selectedDurations.isEmpty {
            guard let duration = estimatedDurationMinutes(for: workout) else {
                return false
            }
            let bucket = durationBucket(for: duration)
            if !selectedDurations.contains(bucket) {
                return false
            }
        }

        return true
    }

    private func workoutLocationTag(for workout: WorkoutDefinition) -> String? {
        if let tag = workout.metadata.locationTag, !tag.isEmpty {
            return tag
        }
        let title = workout.title.lowercased()
        if title.contains("home") {
            return "Home"
        }
        if title.contains("away") {
            return "Away"
        }
        if title.contains("gym") {
            return "Gym"
        }
        return nil
    }

    private func workoutEquipmentTags(for workout: WorkoutDefinition) -> Set<String> {
        if !workout.metadata.equipmentTags.isEmpty {
            return Set(workout.metadata.equipmentTags)
        }

        let haystack = (workout.title + " " + workout.content.sourceMarkdown).lowercased()
        var tags: [String] = []
        if haystack.contains("bodyweight") {
            tags.append("Bodyweight")
        }
        if haystack.contains("dumbbell") {
            tags.append("Dumbbell")
        }
        if haystack.contains("barbell") {
            tags.append("Barbell")
        }
        if haystack.contains("band") {
            tags.append("Band")
        }
        if haystack.contains("kettlebell") {
            tags.append("Kettlebell")
        }
        return Set(tags)
    }

    private func estimatedDurationMinutes(for workout: WorkoutDefinition) -> Int? {
        if let duration = workout.metadata.durationMinutes {
            return duration
        }

        let markdown = workout.content.sourceMarkdown.lowercased()
        if let minutes = Self.extractDurationMinutes(from: markdown) {
            return minutes
        }

        let itemCount = workout.content.parsedSections?.reduce(0) { $0 + $1.items.count } ?? 0
        guard itemCount > 0 else {
            return nil
        }
        return max(12, min(60, itemCount * 2))
    }

    private func durationBucket(for minutes: Int) -> DurationFilter {
        if minutes <= 20 {
            return .short
        }
        if minutes <= 40 {
            return .medium
        }
        return .long
    }

    private static func extractDurationMinutes(from text: String) -> Int? {
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

    private func toggleSelection<T: Hashable>(_ value: T, set: Binding<Set<T>>) {
        var updated = set.wrappedValue
        if updated.contains(value) {
            updated.remove(value)
        } else {
            updated.insert(value)
        }
        set.wrappedValue = updated
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject private var sessionState: SessionStateStore
    let workout: WorkoutDefinition
    let recommendation: RankedWorkout?
    @Binding var selectedTab: AppTab

    private var sectionCount: Int {
        workout.content.parsedSections?.count ?? 0
    }

    private var sectionTitles: [String] {
        workout.content.parsedSections?.prefix(3).map { $0.title } ?? []
    }

    private var overviewMarkdown: String {
        WorkoutMarkdownParser().strippedMarkdown(from: workout.content.sourceMarkdown)
    }

    private enum OverviewBlock: Identifiable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullet(String)

        var id: String {
            switch self {
            case .heading(let level, let text):
                return "h\(level):\(text)"
            case .paragraph(let text):
                return "p:\(text)"
            case .bullet(let text):
                return "b:\(text)"
            }
        }
    }

    private var overviewBlocks: [OverviewBlock] {
        let document = Document(parsing: overviewMarkdown)
        var blocks: [OverviewBlock] = []

        func listItemText(_ listItem: ListItem) -> String? {
            for child in listItem.children {
                if let paragraph = child as? Paragraph {
                    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? nil : text
                }
            }
            return nil
        }

        for child in document.children {
            if let heading = child as? Heading {
                let text = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(.heading(level: heading.level, text: text))
                }
                continue
            }

            if let paragraph = child as? Paragraph {
                let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(.paragraph(text))
                }
                continue
            }

            if let list = child as? ListItemContainer {
                for listItem in list.listItems {
                    guard let text = listItemText(listItem) else {
                        continue
                    }
                    blocks.append(.bullet(text))
                }
            }
        }

        return blocks
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(sectionTitles.isEmpty ? "Knowledge base workout" : sectionTitles.joined(separator: " / "))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    MockChip(title: "\(sectionCount) sections")
                    MockChip(title: sourceLabel(for: workout.source))
                }

                HighlightCard(
                    title: "Why this workout?",
                    subtitle: recommendation?.primaryReason ?? "Structured from the knowledge base",
                    detail: recommendation?.reasons.prefix(2).map(\.text).joined(separator: " • ") ?? "Sections parsed from the original Markdown"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Overview")
                        .font(.headline)

                    Group {
                        if overviewBlocks.isEmpty {
                            Text(overviewMarkdown)
                                .font(.system(.body, design: .default))
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(overviewBlocks) { block in
                                    switch block {
                                    case .heading(let level, let text):
                                        Text(text)
                                            .font(level == 1 ? .title3.weight(.semibold) : .headline)
                                    case .paragraph(let text):
                                        Text(text)
                                            .font(.system(.body, design: .default))
                                    case .bullet(let text):
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("•")
                                            Text(text)
                                        }
                                        .font(.system(.body, design: .default))
                                    }
                                }
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                Button {
                    sessionState.startSession(workout: workout)
                    selectedTab = .session
                } label: {
                    Text("Start Session")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("Workout")
    }

    private func sourceLabel(for source: WorkoutSource) -> String {
        switch source {
        case .knowledgeBase:
            return "Knowledge base"
        case .template:
            return "Template"
        case .variant:
            return "Variant"
        case .external:
            return "External"
        case .generated:
            return "Generated"
        }
    }
}

struct SessionView: View {
    @EnvironmentObject private var sessionState: SessionStateStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let session = sessionState.activeSession {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Session")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(session.workout.title)
                            .foregroundStyle(.secondary)
                    }

                    TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                        let elapsed = max(0, Int(context.date.timeIntervalSince(session.startedAt)))
                        HighlightCard(
                            title: "Session Timer",
                            subtitle: formattedDuration(elapsed),
                            detail: "Overall workout duration"
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sections")
                            .font(.headline)

                        if let sections = session.workout.content.parsedSections, !sections.isEmpty {
                            ForEach(sections) { section in
                                WorkoutSectionCard(section: section)
                            }
                        } else {
                            Text("No structured sections parsed yet.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        sessionState.endSession()
                    } label: {
                        Text("End Session")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No Active Session")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(sessionState.phase == .finished
                             ? "Session complete. Start a new workout to see it here."
                             : "Start a workout to begin a session.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session")
    }

}

struct HistoryView: View {
    @EnvironmentObject private var sessionStore: WorkoutSessionStore

    private var sessions: [WorkoutSession] {
        sessionStore.sessions.sorted { sessionDate(for: $0) > sessionDate(for: $1) }
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private var thisWeek: [WorkoutSession] {
        sessions.filter { sessionDate(for: $0) >= weekStart }
    }

    private var earlier: [WorkoutSession] {
        sessions.filter { sessionDate(for: $0) < weekStart }
    }

    private var totalMinutesThisWeek: Int {
        thisWeek.reduce(0) { total, session in
            total + max(0, sessionDurationMinutes(session))
        }
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                Section {
                    Text("No sessions logged yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("This Week")) {
                    HStack(spacing: 16) {
                        HistoryStat(title: "\(thisWeek.count)", subtitle: "sessions")
                        HistoryStat(title: "\(totalMinutesThisWeek)", subtitle: "minutes")
                        HistoryStat(title: "—", subtitle: "new PRs")
                    }
                    .padding(.vertical, 8)
                }

                if !thisWeek.isEmpty {
                    Section(header: Text("This Week Sessions")) {
                        ForEach(thisWeek) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                SessionRow(session: session)
                            }
                        }
                    }
                }

                if !earlier.isEmpty {
                    Section(header: Text("Earlier Sessions")) {
                        ForEach(earlier) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                SessionRow(session: session)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private func sessionDate(for session: WorkoutSession) -> Date {
        session.endedAt ?? session.startedAt
    }

    private func sessionDurationMinutes(_ session: WorkoutSession) -> Int {
        if let durationSeconds = session.durationSeconds {
            return Int(round(Double(durationSeconds) / 60.0))
        }
        guard let endedAt = session.endedAt else { return 0 }
        return Int(round(endedAt.timeIntervalSince(session.startedAt) / 60.0))
    }
}

struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.workout.title)
                .fontWeight(.semibold)

            Text(SessionDateFormatter.shared.string(from: session.endedAt ?? session.startedAt))
                .foregroundStyle(.secondary)

            if let duration = sessionDurationText() {
                Text(duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func sessionDurationText() -> String? {
        let seconds: Int
        if let durationSeconds = session.durationSeconds {
            seconds = durationSeconds
        } else if let endedAt = session.endedAt {
            seconds = Int(endedAt.timeIntervalSince(session.startedAt))
        } else {
            return nil
        }
        return "Duration \(formattedDuration(max(0, seconds)))"
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession

    private var completedDate: Date {
        session.endedAt ?? session.startedAt
    }

    private var durationText: String {
        let seconds: Int
        if let durationSeconds = session.durationSeconds {
            seconds = durationSeconds
        } else if let endedAt = session.endedAt {
            seconds = Int(endedAt.timeIntervalSince(session.startedAt))
        } else {
            seconds = 0
        }
        return formattedDuration(max(0, seconds))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.workout.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(SessionDateFormatter.shared.string(from: completedDate))
                        .foregroundStyle(.secondary)
                }

                HighlightCard(
                    title: "Session Duration",
                    subtitle: durationText,
                    detail: "Total time captured"
                )

                if let notes = session.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Exercise Progress")
                        .font(.headline)

                    if session.logEntries.isEmpty {
                        Text("No exercise notes or sets recorded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.logEntries) { entry in
                            ExerciseProgressCard(entry: entry)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session Detail")
    }
}

struct ExerciseProgressCard: View {
    let entry: ExerciseLog

    private var summaryText: String {
        let sets = entry.sets.count
        let totalReps = entry.sets.compactMap { $0.reps }.reduce(0, +)
        let volume = volumeSummary(entry.sets)
        var components: [String] = []
        components.append("\(sets) sets")
        if totalReps > 0 {
            components.append("\(totalReps) reps")
        }
        if let volume {
            components.append(volume)
        }
        return components.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.exerciseName)
                .fontWeight(.semibold)
            Text(summaryText)
                .foregroundStyle(.secondary)
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func volumeSummary(_ sets: [ExerciseSet]) -> String? {
        let grouped = Dictionary(grouping: sets.compactMap { set -> (WeightUnit, Double)? in
            guard let weight = set.weight, let unit = set.weightUnit, let reps = set.reps else {
                return nil
            }
            return (unit, weight * Double(reps))
        }) { $0.0 }

        let parts = grouped.map { unit, values -> String in
            let total = values.map { $0.1 }.reduce(0, +)
            let formatted = String(format: "%.0f", total)
            let label = unit == .pounds ? "lb" : "kg"
            return "\(formatted) \(label)"
        }

        return parts.sorted().joined(separator: " · ").isEmpty ? nil : parts.sorted().joined(separator: " · ")
    }
}

struct SettingsMockView: View {
    @EnvironmentObject private var preferencesStore: UserPreferencesStore
    @StateObject private var networkMonitor = NetworkStatusMonitor()
    @State private var apiKeyInput = ""
    @State private var keySaveMessage: String?

    private var llmRuntimeState: LLMRuntimeState {
        preferencesStore.llmRuntimeState(isNetworkAvailable: networkMonitor.isNetworkAvailable)
    }

    private var llmStatusText: String {
        switch llmRuntimeState {
        case .disabled:
            return "Disabled"
        case .missingAPIKey:
            return "Missing API key"
        case .offline:
            return "Offline"
        case .ready:
            return "Ready"
        }
    }

    private var llmStatusColor: Color {
        switch llmRuntimeState {
        case .ready:
            return .green
        case .disabled:
            return .secondary
        case .missingAPIKey, .offline:
            return .orange
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Calendar Sync", isOn: $preferencesStore.preferences.calendarSyncEnabled)
                Toggle("HealthKit Sync", isOn: $preferencesStore.preferences.healthKitSyncEnabled)
            }

            Section(header: Text("LLM")) {
                Toggle("Enable LLM Assistance", isOn: $preferencesStore.preferences.llm.enabled)

                HStack {
                    Text("Provider")
                    Spacer()
                    Picker("Provider", selection: $preferencesStore.preferences.llm.provider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                }

                TextField("Model ID", text: $preferencesStore.preferences.llm.modelID)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                Picker("Prompt Mode", selection: $preferencesStore.preferences.llm.promptDetailLevel) {
                    ForEach(LLMPromptDetailLevel.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                SecureField("API Key", text: $apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack {
                    Button("Save API Key") {
                        if preferencesStore.saveLLMAPIKey(apiKeyInput) {
                            apiKeyInput = ""
                            keySaveMessage = "API key saved in Keychain."
                        } else {
                            keySaveMessage = "Unable to save API key."
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if preferencesStore.hasLLMAPIKey {
                        Button("Remove Key", role: .destructive) {
                            preferencesStore.clearLLMAPIKey()
                            keySaveMessage = "API key removed."
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let keySaveMessage {
                    Text(keySaveMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label(llmStatusText, systemImage: "bolt.horizontal.circle")
                    .foregroundStyle(llmStatusColor)

                if llmRuntimeState == .offline {
                    Text("Free-form generation is unavailable while offline. Rules/search discovery remains available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if llmRuntimeState == .missingAPIKey {
                    Text("Add an API key to enable free-form generation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("LLM Sharing")) {
                Toggle("Calendar Context", isOn: $preferencesStore.preferences.llm.shareCalendarContext)
                Toggle("History Summaries", isOn: $preferencesStore.preferences.llm.shareHistorySummaries)
                Toggle("Exercise Logs", isOn: $preferencesStore.preferences.llm.shareExerciseLogs)
                Toggle("User Notes", isOn: $preferencesStore.preferences.llm.shareUserNotes)
                Toggle("Templates & Variants", isOn: $preferencesStore.preferences.llm.shareTemplatesAndVariants)
                Text("Templates & Variants only controls local context sent to the LLM. It does not share workouts with other users.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Discovery")) {
                NavigationLink("Equipment Availability") {}
                NavigationLink("Workout Duration") {}
                NavigationLink("Focus Areas") {}

                Stepper(
                    value: $preferencesStore.preferences.discovery.recommendationWeights.repeatPenalty,
                    in: 0...3,
                    step: 0.1
                ) {
                    Text("Repeat Penalty: \(preferencesStore.preferences.discovery.recommendationWeights.repeatPenalty, specifier: "%.1f")")
                }

                Stepper(
                    value: $preferencesStore.preferences.discovery.recommendationWeights.noveltyBoost,
                    in: 0...3,
                    step: 0.1
                ) {
                    Text("Balance Boost: \(preferencesStore.preferences.discovery.recommendationWeights.noveltyBoost, specifier: "%.1f")")
                }

                Stepper(
                    value: $preferencesStore.preferences.discovery.recommendationWeights.focusPreferenceBoost,
                    in: 0...3,
                    step: 0.1
                ) {
                    Text("Focus Match Boost: \(preferencesStore.preferences.discovery.recommendationWeights.focusPreferenceBoost, specifier: "%.1f")")
                }
            }

            Section(header: Text("Account")) {
                NavigationLink("Export Data") {}
                NavigationLink("Privacy Settings") {}
            }
        }
        .navigationTitle("Settings")
    }
}

@MainActor
final class NetworkStatusMonitor: ObservableObject {
    @Published private(set) var isNetworkAvailable: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.workoutapp.network-monitor")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutRow: View {
    let workout: WorkoutDefinition
    let recommendation: RankedWorkout?

    private var sectionTitles: [String] {
        workout.content.parsedSections?.prefix(2).map { $0.title } ?? []
    }

    private var sectionSummary: String {
        if sectionTitles.isEmpty {
            return "Knowledge base workout"
        }
        return sectionTitles.joined(separator: " / ")
    }

    private var sectionCount: Int {
        workout.content.parsedSections?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workout.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(sectionSummary)
                .foregroundStyle(.secondary)

            if let recommendation {
                Text(recommendation.primaryReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                MockChip(title: "\(sectionCount) sections")
                MockChip(title: sourceLabel(for: workout.source))
                if let recommendation {
                    MockChip(title: "Score \(String(format: "%.2f", recommendation.score))")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func sourceLabel(for source: WorkoutSource) -> String {
        switch source {
        case .knowledgeBase:
            return "Knowledge base"
        case .template:
            return "Template"
        case .variant:
            return "Variant"
        case .external:
            return "External"
        case .generated:
            return "Generated"
        }
    }
}

struct WorkoutSectionCard: View {
    let section: WorkoutSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .fontWeight(.semibold)

            if let detail = section.detail, !detail.isEmpty {
                Text(detail)
                    .foregroundStyle(.secondary)
            }

            ForEach(section.items) { item in
                WorkoutSectionItemRow(item: item)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutSectionItemRow: View {
    let item: WorkoutItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("-")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .fontWeight(.semibold)

                if let prescription = item.prescription, !prescription.isEmpty {
                    Text(prescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

struct WorkoutBlockMock: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct HighlightCard: View {
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct MockChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(999)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                .cornerRadius(999)
        }
        .buttonStyle(.plain)
    }
}

struct HistoryStat: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct LogRowMock: View {
    let exercise: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise)
                    .fontWeight(.semibold)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Edit")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

final class SessionDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private func formattedDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

#Preview {
    ContentView()
        .environmentObject(UserPreferencesStore())
}
