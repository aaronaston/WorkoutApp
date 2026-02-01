import MarkdownUI
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
                HistoryMockView()
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
    }
}

private enum DurationFilter: String, CaseIterable, Identifiable {
    case short = "<= 20 min"
    case medium = "25-40 min"
    case long = "45+ min"

    var id: String { rawValue }
}

struct DiscoveryView: View {
    @Binding var selectedTab: AppTab
    @State private var workouts: [WorkoutDefinition] = []
    @State private var loadError: String?
    @State private var hasLoaded = false
    @State private var searchQuery = ""
    @State private var searchResults: [WorkoutSearchResult] = []
    @State private var searchIndex: WorkoutSearchIndex?
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedEquipment: Set<String> = []
    @State private var selectedLocations: Set<String> = []
    @State private var selectedDurations: Set<DurationFilter> = []

    private let equipmentFilterOptions = ["Bodyweight", "Dumbbell", "Barbell", "Band", "Kettlebell"]
    private let locationFilterOptions = ["Home", "Gym", "Away"]

    private var highlightedWorkout: WorkoutDefinition? {
        filteredWorkouts.first
    }

    private var hasActiveFilters: Bool {
        !selectedEquipment.isEmpty || !selectedLocations.isEmpty || !selectedDurations.isEmpty
    }

    private var filteredWorkouts: [WorkoutDefinition] {
        workouts.filter { workoutMatchesFilters($0) }
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
                                    WorkoutDetailView(workout: result.workout, selectedTab: $selectedTab)
                                } label: {
                                    WorkoutRow(workout: result.workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    if filteredWorkouts.isEmpty {
                        Text(hasActiveFilters ? "No workouts match those filters." : "No workouts available.")
                            .foregroundStyle(.secondary)
                    } else {
                        if let highlightedWorkout {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today")
                                    .font(.headline)

                                NavigationLink {
                                    WorkoutDetailView(workout: highlightedWorkout, selectedTab: $selectedTab)
                                } label: {
                                    HighlightCard(
                                        title: highlightedWorkout.title,
                                        subtitle: sectionSummary(for: highlightedWorkout),
                                        detail: "Loaded from the knowledge base"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended")
                                .font(.headline)

                            ForEach(filteredWorkouts) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout, selectedTab: $selectedTab)
                                } label: {
                                    WorkoutRow(workout: workout)
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
        Task.detached(priority: .userInitiated) {
            do {
                let loadedWorkouts = try KnowledgeBaseLoader().loadWorkouts()
                let index = WorkoutSearchIndex(workouts: loadedWorkouts)
                await MainActor.run {
                    workouts = loadedWorkouts
                    searchIndex = index
                    scheduleSearch()
                }
            } catch {
                await MainActor.run {
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
                    subtitle: "Structured from the knowledge base",
                    detail: "Sections parsed from the original Markdown"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Overview")
                        .font(.headline)

                    Markdown(overviewMarkdown)
                        .markdownTextStyle(\.text) {
                            FontSize(.em(0.95))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Sections")
                        .font(.headline)

                    if let sections = workout.content.parsedSections, !sections.isEmpty {
                        ForEach(sections) { section in
                            WorkoutSectionCard(section: section)
                        }
                    } else {
                        Text("No structured sections parsed yet.")
                            .foregroundStyle(.secondary)
                    }
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

    private func formattedDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct HistoryMockView: View {
    private let history = MockSession.sample

    var body: some View {
        List {
            Section(header: Text("This Week")) {
                HStack(spacing: 16) {
                    MockStat(title: "4", subtitle: "sessions")
                    MockStat(title: "165", subtitle: "minutes")
                    MockStat(title: "2", subtitle: "new PRs")
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Recent Sessions")) {
                ForEach(history) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.title)
                            .fontWeight(.semibold)
                        Text(session.detail)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("History")
    }
}

struct SettingsMockView: View {
    @EnvironmentObject private var preferencesStore: UserPreferencesStore

    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Calendar Sync", isOn: $preferencesStore.preferences.calendarSyncEnabled)
                Toggle("HealthKit Sync", isOn: $preferencesStore.preferences.healthKitSyncEnabled)
            }

            Section(header: Text("Discovery")) {
                NavigationLink("Equipment Availability") {}
                NavigationLink("Workout Duration") {}
                NavigationLink("Focus Areas") {}
            }

            Section(header: Text("Account")) {
                NavigationLink("Export Data") {}
                NavigationLink("Privacy Settings") {}
            }
        }
        .navigationTitle("Settings")
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

            HStack(spacing: 8) {
                MockChip(title: "\(sectionCount) sections")
                MockChip(title: "Knowledge base")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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

struct MockStat: View {
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

struct MockSession: Identifiable {
    let id = UUID()
    let title: String
    let detail: String

    static let sample: [MockSession] = [
        MockSession(title: "Hinge + Push", detail: "Today - 36 min"),
        MockSession(title: "Mobility Only", detail: "Yesterday - 22 min"),
        MockSession(title: "Squat + Pull", detail: "2 days ago - 41 min")
    ]
}

#Preview {
    ContentView()
        .environmentObject(UserPreferencesStore())
}
