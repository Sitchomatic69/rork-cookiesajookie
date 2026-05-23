import Foundation
import WebKit
import UIKit
import SwiftUI

/// Coordinates the multi-step cycle reset sequence.
///
/// Each step is awaited fully — in particular `WKWebsiteDataStore.removeData`
/// MUST complete before we exit, otherwise WebContent processes leak state
/// into the next launch (the bug the user explicitly flagged).
@MainActor
final class CycleCoordinator {

    nonisolated enum Step: String, Sendable, CaseIterable {
        case stopBrowsers     = "Stopping browsers"
        case clearWebData     = "Clearing web data"
        case clearCaches      = "Wiping caches"
        case sealIdentity     = "Sealing new identity"
        case coldStart        = "Cold start"
    }

    /// Async progress channel — UI subscribes to drive the overlay checklist.
    var onStep: ((Step) -> Void)?

    /// Run the full cycle. Returns after the new persona has been sealed.
    /// The hard exit happens last so callers can show the overlay completion
    /// frame before the process terminates.
    func cycle() async {
        let previousID = ProfileManager.shared.activePersona.id

        // 1. Tell observers (browser views) to stop and dismiss.
        await MainActor.run { onStep?(.stopBrowsers) }
        NotificationCenter.default.post(name: ProfileManager.willCycleNotification, object: nil)
        try? await Task.sleep(for: .milliseconds(250))

        // 2. Clear WebKit website data — MUST await full completion.
        await MainActor.run { onStep?(.clearWebData) }
        await clearAllWebsiteData()

        // 3. Wipe ambient caches and tmp dir.
        await MainActor.run { onStep?(.clearCaches) }
        clearAmbientCaches()

        // 4. Pick + seal a new persona.
        await MainActor.run { onStep?(.sealIdentity) }
        PersonaVault.wipe()
        let next = PersonaMatrix.pickNext(excluding: previousID)
        ProfileManager.shared.sealNewPersona(next)
        NotificationCenter.default.post(name: ProfileManager.didCycleNotification, object: nil)
        try? await Task.sleep(for: .milliseconds(200))

        // 5. Cold start.
        await MainActor.run { onStep?(.coldStart) }
        try? await Task.sleep(for: .milliseconds(600))
        performHardColdStart()
    }

    // MARK: - Steps

    private func clearAllWebsiteData() async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()

        // Default store
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            WKWebsiteDataStore.default().removeData(
                ofTypes: types,
                modifiedSince: .distantPast
            ) { continuation.resume() }
        }

        // Non-default identifier-based stores (per-profile cookie jars).
        if #available(iOS 17.0, *) {
            let identifiers = await WKWebsiteDataStore.allDataStoreIdentifiers
            for id in identifiers {
                let store = WKWebsiteDataStore(forIdentifier: id)
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    store.removeData(ofTypes: types, modifiedSince: .distantPast) {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func clearAmbientCaches() {
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        URLCache.shared.removeAllCachedResponses()

        // tmp directory
        let fm = FileManager.default
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        if let files = try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for f in files { try? fm.removeItem(at: f) }
        }

        // Caches directory
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first,
           let files = try? fm.contentsOfDirectory(at: caches, includingPropertiesForKeys: nil) {
            for f in files { try? fm.removeItem(at: f) }
        }

        // Identity-related UserDefaults keys.
        let keysToClear = [
            "identity.mode", "identity.preset", "identity.customUA",
            "identity.language", "identity.timezone"
        ]
        for k in keysToClear { UserDefaults.standard.removeObject(forKey: k) }
    }

    /// Hard cold-start as requested. NOTE: Apple App Store guideline 2.5.2
    /// forbids programmatic termination — flip `USE_SOFT_RESTART` to true
    /// before App Store submission.
    private func performHardColdStart() {
        #if USE_SOFT_RESTART
        // Soft restart fallback: rebuild the root window scene.
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView())
            window.makeKeyAndVisible()
        }
        #else
        // Suspend then exit — produces a clean cold launch on next foreground.
        let suspendSel = Selector(("suspend"))
        if UIApplication.shared.responds(to: suspendSel) {
            UIApplication.shared.perform(suspendSel)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            exit(0)
        }
        #endif
    }
}
