import Foundation
import SwiftData

@MainActor
@Observable
final class BrowserViewModel {
    var addressText: String
    var currentURL: URL?
    var loadTrigger: Int = 0
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isLoading: Bool = false
    var progress: Double = 0
    var pageTitle: String = ""
    var navAction: BrowserNavigationAction = .none
    var showCookies: Bool = false

    private let historyRepository: HistoryRepository

    init(initialURL: URL = URL(string: "https://www.google.com")!,
         historyRepository: HistoryRepository? = nil) {
        self.addressText = initialURL.absoluteString
        self.currentURL = initialURL
        self.historyRepository = historyRepository ?? HistoryRepository()
    }

    func goHome() {
        addressText = "https://www.google.com"
        go()
    }

    func clearAddress() {
        addressText = ""
    }

    func go() {
        let raw = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        var urlString = raw
        if !raw.contains("://") {
            if raw.contains(" ") || !raw.contains(".") {
                let query = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
                urlString = "https://www.google.com/search?q=\(query)"
            } else {
                urlString = "https://" + raw
            }
        }
        guard let url = URL(string: urlString) else { return }
        currentURL = url
        loadTrigger &+= 1
    }

    func didNavigate(to url: URL, title: String, profile: BrowsingProfile, context: ModelContext) {
        addressText = url.absoluteString
        historyRepository.addHistoryEntry(url: url, title: title, profile: profile, context: context)
    }
}
