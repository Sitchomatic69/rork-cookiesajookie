import Foundation
import SwiftData

@MainActor
@Observable
final class CookieManagerViewModel {
    var selectedTab: CookieManagerTab = .cookies
    var showImportExport: Bool = false
    var showCleanAlert: Bool = false
    var cleanedCount: Int = 0
    var showCleanedBanner: Bool = false
    var searchText: String = ""
    var showSaveSnapshot: Bool = false
    var newSnapshotLabel: String = ""
    var sortMode: CookieSetSort = .size
    var expanded: Set<String> = []
    var partyFilter: CookiePartyFilter = .all
    var purposeFilter: CookiePurpose?

    var snapshotSuggestion: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return "Snapshot \(formatter.string(from: Date()))"
    }

    func effectiveHost(from currentHost: String?) -> String? {
        guard let host = currentHost, !host.isEmpty else { return nil }
        return host
    }

    func allSets(cookies: [CookieData], currentHost: String?) -> [CookieSet] {
        CookieSetBuilder.buildSets(from: cookies, currentHost: effectiveHost(from: currentHost))
    }

    func filteredSets(cookies: [CookieData], currentHost: String?) -> [CookieSet] {
        var sets = allSets(cookies: cookies, currentHost: currentHost)
        if partyFilter == .first { sets = sets.filter { $0.isFirstParty } }
        if partyFilter == .third { sets = sets.filter { !$0.isFirstParty } }
        if let purposeFilter { sets = sets.filter { $0.purposes.contains(purposeFilter) } }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            sets = sets.compactMap { set in
                if set.rootDomain.lowercased().contains(query) { return set }
                let matching = set.cookies.filter { $0.name.lowercased().contains(query) || $0.domain.lowercased().contains(query) }
                if matching.isEmpty { return nil }
                return CookieSet(rootDomain: set.rootDomain, cookies: matching, purposes: set.purposes, totalBytes: set.totalBytes, isFirstParty: set.isFirstParty, lastSeen: set.lastSeen)
            }
        }
        return CookieSetBuilder.sort(sets, by: sortMode)
    }

    func toggleSet(_ setID: String) {
        if expanded.contains(setID) {
            expanded.remove(setID)
        } else {
            expanded.insert(setID)
        }
    }

    func prepareSnapshot() {
        newSnapshotLabel = snapshotSuggestion
        showSaveSnapshot = true
    }

    func copySet(_ set: CookieSet) {
        let text = set.cookies
            .map { "\($0.name)=\($0.value); domain=\($0.domain); path=\($0.path)" }
            .joined(separator: "\n")
        ClipboardService.writeString(text)
    }

    func cleanExpiredCookies(from profile: BrowsingProfile, store: ProfileStore) async {
        cleanedCount = await store.cleanExpiredCookies(from: profile)
        showCleanedBanner = true
        try? await Task.sleep(for: .seconds(2))
        showCleanedBanner = false
    }
}

enum CookiePartyFilter: String, CaseIterable {
    case all
    case first
    case third

    var label: String {
        switch self {
        case .all: return "All"
        case .first: return "1st"
        case .third: return "3rd"
        }
    }
}
