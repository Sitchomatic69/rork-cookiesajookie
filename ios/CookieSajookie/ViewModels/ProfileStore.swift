import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class ProfileStore {
    var cookies: [CookieData] = []
    var domains: [String] = []
    var isLoading: Bool = false

    private let service: CookieService
    private let snapshotRepository: SnapshotRepository

    init(service: CookieService? = nil,
         snapshotRepository: SnapshotRepository? = nil) {
        self.service = service ?? .shared
        self.snapshotRepository = snapshotRepository ?? SnapshotRepository()
    }

    func loadCookies(for profile: BrowsingProfile) async {
        isLoading = true
        cookies = await service.loadCookies(for: profile)
        domains = await service.allDomains(for: profile)
        isLoading = false
    }

    func deleteCookie(_ cookie: CookieData, from profile: BrowsingProfile) async {
        await service.deleteCookie(cookie, from: profile)
        await loadCookies(for: profile)
    }

    func cleanExpiredCookies(from profile: BrowsingProfile) async -> Int {
        let n = await service.cleanExpired(in: profile)
        await loadCookies(for: profile)
        return n
    }

    func importCookies(_ data: [CookieData], into profile: BrowsingProfile) async -> (imported: Int, skipped: Int) {
        let result = await service.addCookies(data, to: profile)
        await loadCookies(for: profile)
        return result
    }

    func exportCookies(for profile: BrowsingProfile, format: CookieExportFormat) async -> String {
        await service.exportCookies(for: profile, format: format)
    }

    func saveSnapshot(for profile: BrowsingProfile, label: String, in context: ModelContext) async -> Bool {
        await snapshotRepository.saveSnapshot(for: profile, label: label, context: context)
    }

    func restoreSnapshot(_ snapshot: CookieSnapshot, to profile: BrowsingProfile) async {
        await snapshotRepository.restoreSnapshot(snapshot, to: profile)
        await loadCookies(for: profile)
    }

    func deleteProfileData(_ profile: BrowsingProfile) async {
        await service.deleteAllData(for: profile)
        await loadCookies(for: profile)
    }

    var totalCookies: Int { cookies.count }
    var expiredCount: Int { cookies.filter { $0.status == .expired }.count }
    var expiringSoonCount: Int { cookies.filter { $0.status == .expiringSoon }.count }
    var validCount: Int { cookies.filter { $0.status == .valid || $0.status == .session }.count }

    var cookiesByDomain: [(domain: String, cookies: [CookieData])] {
        let grouped = Dictionary(grouping: cookies) { c -> String in
            c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain
        }
        return grouped.map { (domain: $0.key, cookies: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.domain < $1.domain }
    }
}
