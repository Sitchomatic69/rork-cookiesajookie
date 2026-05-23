import Foundation
import SwiftData

@MainActor
@Observable
final class NewProfileViewModel {
    var name: String = ""
    var iconName: String = ProfilePalette.icons[0]
    var colorHex: String = ProfilePalette.colors[0]
    var isLocked: Bool = false

    private let profileRepository: ProfileRepository

    init(profileRepository: ProfileRepository? = nil) {
        self.profileRepository = profileRepository ?? ProfileRepository()
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createProfile(context: ModelContext) -> Bool {
        profileRepository.createProfile(name: name,
                                        iconName: iconName,
                                        colorHex: colorHex,
                                        isLocked: isLocked,
                                        context: context) != nil
    }
}

@MainActor
@Observable
final class EditProfileViewModel {
    private let profileRepository: ProfileRepository

    init(profileRepository: ProfileRepository? = nil) {
        self.profileRepository = profileRepository ?? ProfileRepository()
    }

    func save(context: ModelContext) {
        profileRepository.saveChanges(context: context)
    }
}
