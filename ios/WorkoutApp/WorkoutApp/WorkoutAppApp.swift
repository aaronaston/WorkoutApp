import SwiftUI

@main
struct WorkoutAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var preferencesStore: UserPreferencesStore
    @StateObject private var workoutSessionStore: WorkoutSessionStore
    @StateObject private var workoutArtifactStore: WorkoutArtifactStore
    @StateObject private var workoutTemplateStore: WorkoutTemplateStore
    @StateObject private var workoutVariantStore: WorkoutVariantStore
    @StateObject private var generatedCandidateStore: GeneratedCandidateStore
    @StateObject private var sessionStateStore: SessionStateStore

    init() {
        let workoutSessionStore = WorkoutSessionStore()
        let workoutArtifactStore = WorkoutArtifactStore()
        let workoutTemplateStore = WorkoutTemplateStore()
        let workoutVariantStore = WorkoutVariantStore()
        let generatedCandidateStore = GeneratedCandidateStore()
        _preferencesStore = StateObject(wrappedValue: UserPreferencesStore())
        _workoutSessionStore = StateObject(wrappedValue: workoutSessionStore)
        _workoutArtifactStore = StateObject(wrappedValue: workoutArtifactStore)
        _workoutTemplateStore = StateObject(wrappedValue: workoutTemplateStore)
        _workoutVariantStore = StateObject(wrappedValue: workoutVariantStore)
        _generatedCandidateStore = StateObject(wrappedValue: generatedCandidateStore)
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
                .environmentObject(workoutTemplateStore)
                .environmentObject(workoutVariantStore)
                .environmentObject(generatedCandidateStore)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                sessionStateStore.persistDraftIfNeeded()
            }
        }
    }
}
