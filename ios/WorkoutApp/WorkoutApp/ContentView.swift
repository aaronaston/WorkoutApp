import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DiscoveryMockView()
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

struct DiscoveryMockView: View {
    private let workouts = MockWorkout.sample

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

                SearchFieldMock(placeholder: "Search workouts, equipment, or goals")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Today")
                        .font(.headline)

                    HighlightCard(
                        title: "Strength Hinge + Push",
                        subtitle: "35 min - Minimal equipment",
                        detail: "Based on recent sessions and time available"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recommended")
                        .font(.headline)

                    ForEach(workouts) { workout in
                        NavigationLink {
                            WorkoutDetailMockView(workout: workout)
                        } label: {
                            WorkoutRowMock(workout: workout)
                        }
                        .buttonStyle(.plain)
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
    }
}

struct WorkoutDetailMockView: View {
    let workout: MockWorkout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(workout.subtitle)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    MockChip(title: workout.duration)
                    MockChip(title: workout.focus)
                    MockChip(title: workout.equipment)
                }

                HighlightCard(
                    title: "Why this workout?",
                    subtitle: "Matches your preferred duration and focus",
                    detail: "Last session: Pull-focused - Balance with push"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Preview")
                        .font(.headline)

                    WorkoutBlockMock(title: "Warm-up", detail: "5 min mobility")
                    WorkoutBlockMock(title: "Main Set", detail: "4 rounds - hinge/push")
                    WorkoutBlockMock(title: "Finisher", detail: "Core and carry")
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
    @State private var calendarSync = false
    @State private var healthSync = true

    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Calendar Sync", isOn: $calendarSync)
                Toggle("HealthKit Sync", isOn: $healthSync)
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

struct SearchFieldMock: View {
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(placeholder)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutRowMock: View {
    let workout: MockWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workout.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(workout.subtitle)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                MockChip(title: workout.duration)
                MockChip(title: workout.focus)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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

struct MockWorkout: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let duration: String
    let focus: String
    let equipment: String

    static let sample: [MockWorkout] = [
        MockWorkout(
            title: "Squat + Pull",
            subtitle: "Strength focus",
            duration: "40 min",
            focus: "Lower body",
            equipment: "Barbell"
        ),
        MockWorkout(
            title: "Mobility Reset",
            subtitle: "Recovery and range",
            duration: "20 min",
            focus: "Mobility",
            equipment: "Bodyweight"
        ),
        MockWorkout(
            title: "Single Leg Push",
            subtitle: "Balance and control",
            duration: "30 min",
            focus: "Unilateral",
            equipment: "Dumbbells"
        )
    ]
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
}
