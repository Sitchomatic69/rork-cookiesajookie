import Foundation
import WebKit

@MainActor
struct PrivacyResetService {
    func resetBrowserStateAndRotateIdentity() async {
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        URLCache.shared.removeAllCachedResponses()
        clearTemporaryDirectory()
        await removeWebsiteData()
        IdentitySettings.shared.resetToAuto()
    }

    private func removeWebsiteData() async {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { continuation in
            dataStore.removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {
                continuation.resume()
            }
        }
    }

    private func clearTemporaryDirectory() {
        let fileManager = FileManager.default
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(at: tempURL, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
}
