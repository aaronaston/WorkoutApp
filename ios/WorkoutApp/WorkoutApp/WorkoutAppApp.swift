import SwiftUI

@main
struct WorkoutAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var preferencesStore: UserPreferencesStore
    @StateObject private var workoutSessionStore: WorkoutSessionStore
    @StateObject private var sessionStateStore: SessionStateStore

    init() {
        let workoutSessionStore = WorkoutSessionStore()
        _preferencesStore = StateObject(wrappedValue: UserPreferencesStore())
        _workoutSessionStore = StateObject(wrappedValue: workoutSessionStore)
        _sessionStateStore = StateObject(wrappedValue: SessionStateStore(sessionStore: workoutSessionStore))
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
