import MarkdownUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DiscoveryView()
            }
            .tabItem {
                Label("Discover", systemImage: "sparkles")
            }

            NavigationStack {
                SessionMockView()
            }
            .tabItem {
                Label("Session", systemImage: "timer")
            }

            NavigationStack {
                HistoryMockView()
            }
            .tabItem {
                Label("History", systemImage: "chart.bar")
            }

            NavigationStack {
                SettingsMockView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

struct DiscoveryView: View {
    @State private var workouts: [WorkoutDefinition] = []
    @State private var loadError: String?
    @State private var hasLoaded = false
    @State private var searchQuery = ""
    @State private var searchResults: [WorkoutSearchResult] = []
    @State private var searchIndex: WorkoutSearchIndex?
    @State private var searchTask: Task<Void, Never>?

    private var highlightedWorkout: WorkoutDefinition? {
        workouts.first
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

                        if searchResults.isEmpty {
                            Text("No workouts match that search.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(searchResults) { result in
                                NavigationLink {
                                    WorkoutDetailView(workout: result.workout)
                                } label: {
                                    WorkoutRow(workout: result.workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    if let highlightedWorkout {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today")
                                .font(.headline)

                            NavigationLink {
                                WorkoutDetailView(workout: highlightedWorkout)
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

                        ForEach(workouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                WorkoutRow(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Filters")
                        .font(.headline)

                    HStack(spacing: 8) {
                        MockChip(title: "25-40 min")
                        MockChip(title: "No barbell")
                        MockChip(title: "Home")
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
        do {
            workouts = try KnowledgeBaseLoader().loadWorkouts()
            searchIndex = WorkoutSearchIndex(workouts: workouts)
            updateSearchResults()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else {
                return
            }
            updateSearchResults()
        }
    }

    @MainActor
    private func updateSearchResults() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let searchIndex else {
            searchResults = []
            return
        }
        searchResults = searchIndex.search(query: trimmed, limit: 25)
    }
}

struct WorkoutDetailView: View {
    let workout: WorkoutDefinition

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

                Button(action: {}) {
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

struct SessionMockView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Session")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Strength Hinge + Push")
                        .foregroundStyle(.secondary)
                }

                HighlightCard(
                    title: "Interval Timer",
                    subtitle: "00:06 remaining",
                    detail: "Round 2 of 4 - Rest"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Current Block")
                        .font(.headline)

                    WorkoutBlockMock(title: "A1 - Hinge Press", detail: "3x8 @ 70%")
                    WorkoutBlockMock(title: "A2 - Push Up", detail: "3x12 controlled")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Log")
                        .font(.headline)

                    LogRowMock(exercise: "Hinge Press", detail: "Set 2 - 8 reps")
                    LogRowMock(exercise: "Push Up", detail: "Set 2 - 12 reps")
                }
            }
            .padding()
        }
        .navigationTitle("Session")
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
                    .accessibilityIdentifier("settings.calendarSyncToggle")
                Toggle("HealthKit Sync", isOn: $preferencesStore.preferences.healthKitSyncEnabled)
                    .accessibilityIdentifier("settings.healthKitSyncToggle")
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
