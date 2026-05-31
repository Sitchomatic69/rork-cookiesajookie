import Foundation
import WebKit
import SwiftUI
import Observation

/// Single source of truth for the app's active browsing persona.
///
/// Because the project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
/// this class is implicitly MainActor-isolated — which is the correct
/// isolation for vending `WKWebViewConfiguration` (MainActor-bound) and
/// observable UI state. State persistence is delegated to `PersonaVault`,
/// which uses Keychain so the persona survives launches but is wiped on cycle.
@Observable
final class ProfileManager {

    static let shared = ProfileManager()

    /// Posted before a cycle starts so any open WKWebView can tear down.
    static let willCycleNotification = Notification.Name("ProfileManager.willCycle")
    /// Posted after cycle persona is sealed but before cold-start (mostly for tests).
    static let didCycleNotification = Notification.Name("ProfileManager.didCycle")
    /// Posted after the locale override changes so open web views can reload.
    static let didChangeLocaleNotification = Notification.Name("ProfileManager.didChangeLocale")

    /// The raw device persona picked from the matrix (what cycling replaces).
    private(set) var basePersona: BrowsingPersona
    /// User locale preference layered on top of `basePersona`.
    private(set) var localeOverride: LocaleOverride
    /// The effective persona every web view + request actually uses
    /// (`basePersona` with the locale override applied).
    private(set) var activePersona: BrowsingPersona
    private(set) var network: PersonaURLSession

    private init() {
        let initial: BrowsingPersona = {
            if let stored = PersonaVault.load() { return stored }
            let fresh = PersonaMatrix.pickNext(excluding: nil)
            PersonaVault.save(fresh)
            return fresh
        }()
        let override = LocaleVault.load()
        let effective = initial.applyingLocale(override)
        self.basePersona = initial
        self.localeOverride = override
        self.activePersona = effective
        self.network = PersonaURLSession(persona: effective)
    }

    // MARK: - WKWebView vending

    /// Build a fully-configured WKWebViewConfiguration for the active persona.
    /// EVERY web view in the app must come through here — that's how identity
    /// stays consistent without manual coordination.
    func makeWebViewConfiguration(websiteDataStore: WKWebsiteDataStore) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = websiteDataStore
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        if #available(iOS 15.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        // Hardcoded global cookie policy — Accept all, including third-party.
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always

        let script = WKUserScript(
            source: PersonaScript.make(for: activePersona),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(script)
        return config
    }

    /// Apply persona-correct UA + headers to a webview after instantiation.
    func apply(to webView: WKWebView) {
        webView.customUserAgent = activePersona.userAgent
    }

    // MARK: - Locale override

    /// Apply a new locale preference on top of the current device persona.
    /// Persisted independently so it survives profile cycles.
    func applyLocaleOverride(_ override: LocaleOverride) {
        self.localeOverride = override
        LocaleVault.save(override)
        let effective = basePersona.applyingLocale(override)
        self.activePersona = effective
        self.network.rebuild(for: effective)
        NotificationCenter.default.post(name: Self.didChangeLocaleNotification, object: nil)
    }

    // MARK: - Persona swap (used by cycle)

    func sealNewPersona(_ persona: BrowsingPersona) {
        self.basePersona = persona
        let effective = persona.applyingLocale(localeOverride)
        self.activePersona = effective
        self.network.rebuild(for: effective)
        // Store the raw device persona; the locale override is vaulted separately.
        PersonaVault.save(persona)
    }
}

// MARK: - Persistent storage

/// Stores the active persona JSON in the iOS Keychain so it survives launches
/// but is wiped during the cycle reset.
nonisolated enum PersonaVault {
    private static let service = "app.cookiesajookie.persona"
    private static let account = "active"

    static func load() -> BrowsingPersona? {
        guard let data = read() else { return nil }
        return try? JSONDecoder().decode(BrowsingPersona.self, from: data)
    }

    static func save(_ persona: BrowsingPersona) {
        guard let data = try? JSONEncoder().encode(persona) else { return }
        write(data)
    }

    static func wipe() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func write(_ data: Data) {
        wipe()
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }
}
