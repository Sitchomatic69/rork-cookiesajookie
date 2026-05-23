import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    var isResettingPrivacyState: Bool = false
    var resetMessage: String?

    private let resetService = PrivacyResetService()

    func resetPrivacyState() async {
        guard !isResettingPrivacyState else { return }
        isResettingPrivacyState = true
        await resetService.resetBrowserStateAndRotateIdentity()
        resetMessage = "Browser data was cleared and identity settings were reset."
        isResettingPrivacyState = false
    }
}
