import Foundation

@MainActor
@Observable
final class ProfileDetailViewModel {
    var showBrowser: Bool = false
    var showCookies: Bool = false
    var showHistory: Bool = false
    var showImportExport: Bool = false

    private let historyRepository: HistoryRepository

    init(historyRepository: HistoryRepository? = nil) {
        self.historyRepository = historyRepository ?? HistoryRepository()
    }

    func recentHistory(for profile: BrowsingProfile) -> [HistoryEntry] {
        historyRepository.recentEntries(for: profile)
    }
}
