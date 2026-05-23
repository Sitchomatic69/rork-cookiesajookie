import Foundation
import SwiftData

@MainActor
struct SnapshotRepository {
    private let cookieService: CookieService

    init(cookieService: CookieService? = nil) {
        self.cookieService = cookieService ?? .shared
    }

    func sortedSnapshots(for profile: BrowsingProfile) -> [CookieSnapshot] {
        profile.snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    func saveSnapshot(for profile: BrowsingProfile, label: String, context: ModelContext) async -> Bool {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = await cookieService.snapshot(profile: profile)
        guard !data.isEmpty else { return false }
        let snapshot = CookieSnapshot(label: trimmedLabel.isEmpty ? "Snapshot" : trimmedLabel, cookieData: data)
        snapshot.profile = profile
        context.insert(snapshot)
        try? context.save()
        return true
    }

    func restoreSnapshot(_ snapshot: CookieSnapshot, to profile: BrowsingProfile) async {
        await cookieService.restore(snapshot: snapshot.cookieData, to: profile)
    }

    func deleteSnapshot(_ snapshot: CookieSnapshot, context: ModelContext) {
        context.delete(snapshot)
        try? context.save()
    }
}
