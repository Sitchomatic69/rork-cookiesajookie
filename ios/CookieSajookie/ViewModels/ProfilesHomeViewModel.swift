import Foundation
import SwiftData

@MainActor
@Observable
final class ProfilesHomeViewModel {
    var showNewProfile: Bool = false
    var showSettings: Bool = false
    var profileToEdit: BrowsingProfile?
    var pendingProfile: BrowsingProfile?

    private var unlockedProfileIDs: Set<UUID> = []
    private let profileRepository: ProfileRepository

    init(profileRepository: ProfileRepository? = nil) {
        self.profileRepository = profileRepository ?? ProfileRepository()
    }

    func open(_ profile: BrowsingProfile) async {
        if profile.isLocked && !unlockedProfileIDs.contains(profile.id) {
            let isAuthenticated = await BiometricService.authenticate(reason: "Unlock \(profile.name)")
            guard isAuthenticated else { return }
            unlockedProfileIDs.insert(profile.id)
        }
        pendingProfile = profile
    }

    func clone(_ profile: BrowsingProfile, context: ModelContext) async {
        _ = await profileRepository.cloneProfile(profile, context: context)
    }

    func delete(_ profile: BrowsingProfile, context: ModelContext) async {
        await profileRepository.deleteProfile(profile, context: context)
    }
}
