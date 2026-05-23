import Foundation
import SwiftData

@MainActor
struct ProfileRepository {
    private let cookieService: CookieService

    init(cookieService: CookieService? = nil) {
        self.cookieService = cookieService ?? .shared
    }

    @discardableResult
    func createProfile(name: String,
                       iconName: String,
                       colorHex: String,
                       isLocked: Bool,
                       context: ModelContext) -> BrowsingProfile? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let profile = BrowsingProfile(name: trimmedName,
                                      iconName: iconName,
                                      colorHex: colorHex,
                                      isLocked: isLocked)
        context.insert(profile)
        try? context.save()
        return profile
    }

    func saveChanges(context: ModelContext) {
        try? context.save()
    }

    @discardableResult
    func cloneProfile(_ source: BrowsingProfile, context: ModelContext) async -> BrowsingProfile {
        let copy = BrowsingProfile(name: source.name + " Copy",
                                   iconName: source.iconName,
                                   colorHex: source.colorHex,
                                   isLocked: false)
        context.insert(copy)
        try? context.save()
        await cookieService.copyCookies(from: source, to: copy)
        return copy
    }

    func deleteProfile(_ profile: BrowsingProfile, context: ModelContext) async {
        await cookieService.deleteAllData(for: profile)
        context.delete(profile)
        try? context.save()
    }
}
