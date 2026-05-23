import Foundation
import SwiftData

@Model
final class HistoryEntry {
    var id: UUID
    var urlString: String
    var title: String
    var visitedAt: Date
    var profile: BrowsingProfile?

    init(urlString: String, title: String) {
        self.id = UUID()
        self.urlString = urlString
        self.title = title
        self.visitedAt = Date()
    }
}
