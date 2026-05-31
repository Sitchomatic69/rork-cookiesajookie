import Foundation

/// Whether the app uses the persona's built-in locale or a user-chosen one.
nonisolated enum LocaleMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case auto
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Persona Default"
        case .custom: return "Custom"
        }
    }
}

/// User-selected locale layered on top of the active device persona.
///
/// Stored independently from the persona so it survives profile cycles — a
/// person keeps the same language/timezone even when their device changes,
/// and matching a target region (e.g. the IP's country) is exactly what keeps
/// the suspect score low.
nonisolated struct LocaleOverride: Codable, Sendable, Hashable {
    var mode: LocaleMode
    /// Primary BCP-47 language tag, e.g. `en-AU`.
    var primaryLanguage: String
    /// Extra fallback tags appended to `navigator.languages` / `Accept-Language`.
    var additionalLanguages: [String]
    /// IANA timezone identifier, e.g. `Australia/Melbourne`.
    var timezone: String

    /// The neutral default that defers entirely to the persona's own locale.
    static let personaDefault = LocaleOverride(
        mode: .auto,
        primaryLanguage: "en-US",
        additionalLanguages: [],
        timezone: "America/Los_Angeles"
    )

    /// Full ordered language list for `navigator.languages`:
    /// primary first, then its base code, then any user-added fallbacks.
    var resolvedLanguages: [String] {
        var out: [String] = []
        let primary = primaryLanguage.trimmingCharacters(in: .whitespaces)
        if !primary.isEmpty { out.append(primary) }
        if let base = primary.split(separator: "-").first.map(String.init), base != primary {
            out.append(base)
        }
        for raw in additionalLanguages {
            let tag = raw.trimmingCharacters(in: .whitespaces)
            guard !tag.isEmpty, !out.contains(tag) else { continue }
            out.append(tag)
            if let base = tag.split(separator: "-").first.map(String.init), base != tag, !out.contains(base) {
                out.append(base)
            }
        }
        return out.isEmpty ? ["en-US", "en"] : out
    }

    /// `Accept-Language` header derived from `resolvedLanguages` with descending q-values.
    var acceptLanguageHeader: String {
        LocaleOverride.acceptLanguageHeader(from: resolvedLanguages)
    }

    /// Builds a believable `Accept-Language` header (Safari-style q weighting).
    static func acceptLanguageHeader(from languages: [String]) -> String {
        let capped = Array(languages.prefix(6))
        guard !capped.isEmpty else { return "en-US,en;q=0.9" }
        var parts: [String] = []
        var q = 1.0
        for (index, tag) in capped.enumerated() {
            if index == 0 {
                parts.append(tag)
            } else {
                q = max(0.1, q - 0.1)
                parts.append("\(tag);q=\(String(format: "%.1f", q))")
            }
        }
        return parts.joined(separator: ",")
    }
}

extension BrowsingPersona {
    /// Returns a copy of the persona with the locale override applied.
    /// `.auto` leaves the persona untouched; `.custom` rewrites every
    /// locale-derived signal so the WKWebView JS and the network headers agree.
    func applyingLocale(_ override: LocaleOverride) -> BrowsingPersona {
        guard override.mode == .custom else { return self }
        return BrowsingPersona(
            id: id,
            displayName: displayName,
            deviceFamily: deviceFamily,
            iosVersion: iosVersion,
            userAgent: userAgent,
            platform: platform,
            vendor: vendor,
            appVersion: appVersion,
            hardwareConcurrency: hardwareConcurrency,
            deviceMemory: deviceMemory,
            maxTouchPoints: maxTouchPoints,
            isMobile: isMobile,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            availWidth: availWidth,
            availHeight: availHeight,
            devicePixelRatio: devicePixelRatio,
            colorDepth: colorDepth,
            language: override.primaryLanguage,
            languages: override.resolvedLanguages,
            timezone: override.timezone,
            acceptLanguageHeader: override.acceptLanguageHeader,
            secChUa: secChUa,
            secChUaMobile: secChUaMobile,
            secChUaPlatform: secChUaPlatform,
            webglVendor: webglVendor,
            webglRenderer: webglRenderer,
            webglUnmaskedVendor: webglUnmaskedVendor,
            webglUnmaskedRenderer: webglUnmaskedRenderer,
            audioSampleRate: audioSampleRate,
            fonts: fonts,
            renderSeed: renderSeed
        )
    }
}

/// Persists the locale override in `UserDefaults` as JSON.
/// Deliberately separate from `PersonaVault` so it is NOT wiped on cycle.
nonisolated enum LocaleVault {
    private static let key = "locale.override.v1"

    static func load() -> LocaleOverride {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(LocaleOverride.self, from: data)
        else {
            return .personaDefault
        }
        return decoded
    }

    static func save(_ override: LocaleOverride) {
        guard let data = try? JSONEncoder().encode(override) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
