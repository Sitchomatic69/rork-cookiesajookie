import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        ProfilesHomeView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [BrowsingProfile.self, HistoryEntry.self, CookieSnapshot.self], inMemory: true)
}
