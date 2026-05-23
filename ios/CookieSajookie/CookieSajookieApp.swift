import SwiftUI
import SwiftData
import Foundation

@main
struct CookieSajookieApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BrowsingProfile.self,
            HistoryEntry.self,
            CookieSnapshot.self,
        ])

        let storeURL = Self.modelStoreURL()
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            Self.resetModelStore(at: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [fallbackConfiguration])
            }
        }
    }()

    private static func modelStoreURL() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = applicationSupport?.appending(path: "CookieSajookie", directoryHint: .isDirectory)
            ?? URL.temporaryDirectory.appending(path: "CookieSajookie", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "CookieSajookie.store")
    }

    private static func resetModelStore(at url: URL) {
        let fileManager = FileManager.default
        let relatedURLs = [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal")
        ]

        for relatedURL in relatedURLs {
            try? fileManager.removeItem(at: relatedURL)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
