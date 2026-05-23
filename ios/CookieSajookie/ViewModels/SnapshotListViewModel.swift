import Foundation
import SwiftData

@MainActor
@Observable
final class SnapshotListViewModel {
    private let snapshotRepository: SnapshotRepository

    init(snapshotRepository: SnapshotRepository? = nil) {
        self.snapshotRepository = snapshotRepository ?? SnapshotRepository()
    }

    func snapshots(for profile: BrowsingProfile) -> [CookieSnapshot] {
        snapshotRepository.sortedSnapshots(for: profile)
    }

    func delete(_ snapshot: CookieSnapshot, context: ModelContext) {
        snapshotRepository.deleteSnapshot(snapshot, context: context)
    }
}
