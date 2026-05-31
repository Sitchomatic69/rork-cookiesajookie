import Foundation
import Observation

/// Exposes the active persona for the Settings → Profile section.
@MainActor
@Observable
final class PersonaSettingsViewModel {
    private(set) var persona: BrowsingPersona

    init() {
        self.persona = ProfileManager.shared.activePersona
        for name in [ProfileManager.didCycleNotification, ProfileManager.didChangeLocaleNotification] {
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.persona = ProfileManager.shared.activePersona
                }
            }
        }
    }

    var deviceLine: String {
        "\(persona.displayName) · iOS \(persona.iosVersion.dotted)"
    }
    var screenLine: String {
        "\(persona.screenWidth)×\(persona.screenHeight) @\(String(format: "%.1f", persona.devicePixelRatio))x"
    }
    var gpuLine: String { "\(persona.webglUnmaskedVendor) — \(persona.webglUnmaskedRenderer)" }
    var localeLine: String { "\(persona.language) · \(persona.timezone)" }
    var hardwareLine: String { "\(persona.hardwareConcurrency) cores · \(persona.deviceMemory) GB" }
}
