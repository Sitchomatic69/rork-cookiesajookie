import Foundation
import SwiftData

@MainActor
struct HistoryRepository {
    func sortedEntries(for profile: BrowsingProfile) -> [HistoryEntry] {
        profile.historyEntries.sorted { $0.visitedAt > $1.visitedAt }
    }

    func recentEntries(for profile: BrowsingProfile, limit: Int = 4) -> [HistoryEntry] {
        Array(sortedEntries(for: profile).prefix(limit))
    }

    func addHistoryEntry(url: URL, title: String, profile: BrowsingProfile, context: ModelContext) {
        guard !url.absoluteString.isEmpty else { return }
        let entry = HistoryEntry(urlString: url.absoluteString, title: title)
        entry.profile = profile
        context.insert(entry)
        try? context.save()
    }

    func deleteEntry(_ entry: HistoryEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }

    func clearHistory(for profile: BrowsingProfile, context: ModelContext) {
        for entry in profile.historyEntries {
            context.delete(entry)
        }
        try? context.save()
    }
}
