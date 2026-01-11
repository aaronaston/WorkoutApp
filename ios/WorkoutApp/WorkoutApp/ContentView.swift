import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Workout Discovery")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Find a workout that fits your day.")
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Workout App")
        }
    }
}

#Preview {
    ContentView()
}
