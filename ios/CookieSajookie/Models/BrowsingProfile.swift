import Foundation
import SwiftUI
import SwiftData

@Model
final class BrowsingProfile {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var isLocked: Bool
    var createdAt: Date
    var dataStoreIdentifier: UUID
    var cachedCookieData: Data

    @Relationship(deleteRule: .cascade, inverse: \HistoryEntry.profile)
    var historyEntries: [HistoryEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \CookieSnapshot.profile)
    var snapshots: [CookieSnapshot] = []

    init(name: String, iconName: String, colorHex: String, isLocked: Bool = false) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isLocked = isLocked
        self.createdAt = Date()
        self.dataStoreIdentifier = UUID()
        self.cachedCookieData = Data()
    }

    var color: Color { Color(hex: colorHex) }

    var cachedCookies: [CookieData] {
        get {
            guard !cachedCookieData.isEmpty else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode([CookieData].self, from: cachedCookieData)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            cachedCookieData = (try? encoder.encode(newValue)) ?? Data()
        }
    }

    func mergeCachedCookies(_ newCookies: [CookieData]) {
        var existing = cachedCookies
        for cookie in newCookies {
            if let idx = existing.firstIndex(where: {
                $0.name == cookie.name &&
                $0.domain.lowercased() == cookie.domain.lowercased() &&
                $0.path == cookie.path
            }) {
                existing[idx] = cookie
            } else {
                existing.append(cookie)
            }
        }
        cachedCookies = existing
    }
}
