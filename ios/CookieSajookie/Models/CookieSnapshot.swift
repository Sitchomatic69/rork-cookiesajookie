import Foundation
import SwiftData

@Model
final class CookieSnapshot {
    var id: UUID
    var label: String
    var createdAt: Date
    var cookieData: Data
    var profile: BrowsingProfile?

    init(label: String, cookieData: Data) {
        self.id = UUID()
        self.label = label
        self.createdAt = Date()
        self.cookieData = cookieData
    }

    var cookies: [CookieData] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CookieData].self, from: cookieData)) ?? []
    }
}
