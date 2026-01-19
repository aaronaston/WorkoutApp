import SwiftUI

@main
struct WorkoutAppApp: App {
    @StateObject private var preferencesStore: UserPreferencesStore

    init() {
        let store = UserPreferencesStore()
        if ProcessInfo.processInfo.arguments.contains("ui-testing-reset") {
            store.reset()
        }
        _preferencesStore = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferencesStore)
        }
    }
}
