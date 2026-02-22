import SwiftUI

@main
struct WorkoutAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var preferencesStore: UserPreferencesStore
    @StateObject private var workoutSessionStore: WorkoutSessionStore
    @StateObject private var workoutArtifactStore: WorkoutArtifactStore
    @StateObject private var sessionStateStore: SessionStateStore

    init() {
        let workoutSessionStore = WorkoutSessionStore()
        let workoutArtifactStore = WorkoutArtifactStore()
        _preferencesStore = StateObject(wrappedValue: UserPreferencesStore())
        _workoutSessionStore = StateObject(wrappedValue: workoutSessionStore)
        _workoutArtifactStore = StateObject(wrappedValue: workoutArtifactStore)
        _sessionStateStore = StateObject(
            wrappedValue: SessionStateStore(
                sessionStore: workoutSessionStore,
                artifactStore: workoutArtifactStore
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferencesStore)
                .environmentObject(workoutSessionStore)
                .environmentObject(sessionStateStore)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                sessionStateStore.persistDraftIfNeeded()
            }
        }
    }
}
