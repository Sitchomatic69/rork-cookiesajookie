import Foundation
import WebKit

@MainActor
final class CookieService {
    static let shared = CookieService()
    private init() {}

    private var dataStores: [UUID: WKWebsiteDataStore] = [:]

    func dataStore(for profile: BrowsingProfile) -> WKWebsiteDataStore {
        if let existing = dataStores[profile.dataStoreIdentifier] { return existing }
        let store = WKWebsiteDataStore(forIdentifier: profile.dataStoreIdentifier)
        dataStores[profile.dataStoreIdentifier] = store
        return store
    }

    func loadCookies(for profile: BrowsingProfile) async -> [CookieData] {
        let store = dataStore(for: profile)
        let cookies = await store.httpCookieStore.allCookies()
        let converted = cookies.map { CookieData(from: $0) }
        let cached = profile.cachedCookies
        var merged: [String: CookieData] = [:]
        for c in cached { merged[c.id] = c }
        for c in converted { merged[c.id] = c }
        let all = Array(merged.values).sorted { $0.domain < $1.domain }
        profile.cachedCookies = all
        return all
    }

    func allDomains(for profile: BrowsingProfile) async -> [String] {
        let cookies = await loadCookies(for: profile)
        let set = Set(cookies.map { $0.domain.hasPrefix(".") ? String($0.domain.dropFirst()) : $0.domain })
        return Array(set).sorted()
    }

    func addCookies(_ cookies: [CookieData], to profile: BrowsingProfile) async -> (imported: Int, skipped: Int) {
        let store = dataStore(for: profile)
        let normalized = CookieNormalizer.normalize(cookies)
        var imported = 0
        var skipped = 0
        for c in normalized {
            if let http = c.toHTTPCookie() {
                await store.httpCookieStore.setCookie(http)
                imported += 1
            } else {
                skipped += 1
            }
        }
        profile.mergeCachedCookies(normalized)
        return (imported, skipped)
    }

    func deleteCookie(_ cookie: CookieData, from profile: BrowsingProfile) async {
        let store = dataStore(for: profile)
        let all = await store.httpCookieStore.allCookies()
        for c in all where c.name == cookie.name && c.domain.lowercased() == cookie.domain.lowercased() && c.path == cookie.path {
            await store.httpCookieStore.deleteCookie(c)
        }
        var cached = profile.cachedCookies
        cached.removeAll { $0.id == cookie.id }
        profile.cachedCookies = cached
    }

    func cleanExpired(in profile: BrowsingProfile) async -> Int {
        let cookies = await loadCookies(for: profile)
        let expired = cookies.filter { $0.status == .expired }
        for c in expired {
            await deleteCookie(c, from: profile)
        }
        return expired.count
    }

    func deleteAllData(for profile: BrowsingProfile) async {
        let store = dataStore(for: profile)
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        await store.removeData(ofTypes: types, for: records)
        profile.cachedCookies = []
    }

    func exportCookies(for profile: BrowsingProfile, format: CookieExportFormat = .json) async -> String {
        let cookies = await loadCookies(for: profile)
        return CookieExporter.export(cookies, format: format)
    }

    func copyCookies(from source: BrowsingProfile, to target: BrowsingProfile) async {
        let cookies = await loadCookies(for: source)
        _ = await addCookies(cookies, to: target)
    }

    func snapshot(profile: BrowsingProfile) async -> Data {
        let cookies = await loadCookies(for: profile)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(cookies)) ?? Data()
    }

    func restore(snapshot data: Data, to profile: BrowsingProfile) async {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cookies = try? decoder.decode([CookieData].self, from: data) else { return }
        await deleteAllData(for: profile)
        _ = await addCookies(cookies, to: profile)
    }
}
