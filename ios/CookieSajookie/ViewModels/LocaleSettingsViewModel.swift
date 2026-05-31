import Foundation
import Observation
import UIKit

/// Drives the custom Locale editor. Holds an editable `draft` and commits every
/// change straight to `ProfileManager`, so the active persona, injected JS, and
/// network headers update live.
@MainActor
@Observable
final class LocaleSettingsViewModel {
    private(set) var draft: LocaleOverride

    init() {
        self.draft = ProfileManager.shared.localeOverride
    }

    // MARK: - Mode

    var mode: LocaleMode {
        get { draft.mode }
        set {
            draft.mode = newValue
            commit()
        }
    }

    var isCustom: Bool { draft.mode == .custom }

    // MARK: - Picker data

    var languageItems: [LocalePickItem] {
        LocaleCatalog.languages.map {
            LocalePickItem(id: $0.code, title: $0.label, subtitle: $0.code)
        }
    }

    var timezoneItems: [LocalePickItem] {
        LocaleCatalog.timezones.map {
            LocalePickItem(
                id: $0.id,
                title: $0.city,
                subtitle: "\($0.region) · \(LocaleCatalog.gmtOffset($0.id))"
            )
        }
    }

    /// Languages still available to add as secondary fallbacks.
    var addableLanguages: [LocaleCatalog.Language] {
        LocaleCatalog.languages.filter {
            $0.code != draft.primaryLanguage && !draft.additionalLanguages.contains($0.code)
        }
    }

    var additionalLanguages: [String] { draft.additionalLanguages }

    // MARK: - Editing

    func setPrimaryLanguage(_ code: String) {
        draft.primaryLanguage = code
        draft.additionalLanguages.removeAll { $0 == code }
        commit()
    }

    func setTimezone(_ identifier: String) {
        draft.timezone = identifier
        commit()
    }

    func addLanguage(_ code: String) {
        guard code != draft.primaryLanguage, !draft.additionalLanguages.contains(code) else { return }
        draft.additionalLanguages.append(code)
        commit()
    }

    func removeAdditionalLanguage(_ code: String) {
        draft.additionalLanguages.removeAll { $0 == code }
        commit()
    }

    /// Quick-fill from the real device so the locale lines up with the IP/region.
    func matchDevice() {
        let preferred = Array(Locale.preferredLanguages.prefix(4))
        let primary = preferred.first ?? "en-US"
        draft.mode = .custom
        draft.primaryLanguage = primary
        draft.additionalLanguages = preferred.dropFirst().filter { $0 != primary }
        draft.timezone = TimeZone.current.identifier
        commit()
    }

    func resetToDefault() {
        draft = .personaDefault
        commit()
    }

    // MARK: - Display helpers

    var primaryLanguageLabel: String { LocaleCatalog.languageLabel(draft.primaryLanguage) }
    var timezoneCity: String { LocaleCatalog.timezoneCity(draft.timezone) }
    var timezoneOffset: String { LocaleCatalog.gmtOffset(draft.timezone) }

    /// What the WKWebView / requests will actually report with the current draft.
    private var previewPersona: BrowsingPersona {
        ProfileManager.shared.basePersona.applyingLocale(draft)
    }
    var previewLanguage: String { previewPersona.language }
    var previewLanguages: String { previewPersona.languages.joined(separator: ", ") }
    var previewTimezone: String { previewPersona.timezone }
    var previewAcceptLanguage: String { previewPersona.acceptLanguageHeader }

    private func commit() {
        ProfileManager.shared.applyLocaleOverride(draft)
    }
}
