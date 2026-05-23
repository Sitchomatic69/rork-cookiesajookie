import Foundation
import SwiftData

@MainActor
@Observable
final class HistoryViewModel {
    private let historyRepository: HistoryRepository

    init(historyRepository: HistoryRepository? = nil) {
        self.historyRepository = historyRepository ?? HistoryRepository()
    }

    func entries(for profile: BrowsingProfile) -> [HistoryEntry] {
        historyRepository.sortedEntries(for: profile)
    }

    func delete(_ entry: HistoryEntry, context: ModelContext) {
        historyRepository.deleteEntry(entry, context: context)
    }

    func clearHistory(for profile: BrowsingProfile, context: ModelContext) {
        historyRepository.clearHistory(for: profile, context: context)
    }
}
