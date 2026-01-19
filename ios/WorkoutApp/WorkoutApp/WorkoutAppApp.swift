import SwiftUI

@main
struct WorkoutAppApp: App {
    @StateObject private var preferencesStore = UserPreferencesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferencesStore)
        }
    }
}
