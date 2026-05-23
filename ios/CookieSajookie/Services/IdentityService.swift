import Foundation
import SwiftUI
import UIKit

nonisolated enum IdentityMode: String, Codable, Sendable, CaseIterable {
    case auto
    case preset
    case custom
}

nonisolated struct IdentityProfile: Sendable, Hashable {
    let userAgent: String
    let platform: String
    let vendor: String
    let appVersion: String
    let oscpu: String?
    let language: String
    let languages: [String]
    let timezone: String
    let hardwareConcurrency: Int
    let deviceMemory: Int
    let screenWidth: Int
    let screenHeight: Int
    let devicePixelRatio: Double
    let colorDepth: Int
    let touchSupport: Bool
    let maxTouchPoints: Int
    let secChUa: String?
    let secChUaMobile: String?
    let secChUaPlatform: String?
    let acceptLanguageHeader: String
    let isMobile: Bool
}

nonisolated struct IdentityPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let systemImage: String
    let isMobile: Bool
}

nonisolated enum IdentityPresets {
    static let all: [IdentityPreset] = [
        .init(id: "auto",            name: "Auto (Match Device)", systemImage: "wand.and.stars", isMobile: true),
        .init(id: "iphone_safari",   name: "Safari — iPhone",     systemImage: "iphone",         isMobile: true),
        .init(id: "ipad_safari",     name: "Safari — iPad",       systemImage: "ipad",           isMobile: true),
        .init(id: "mac_safari",      name: "Safari — Mac",        systemImage: "laptopcomputer", isMobile: false),
        .init(id: "chrome_ios",      name: "Chrome — iOS",        systemImage: "iphone",         isMobile: true),
        .init(id: "chrome_android",  name: "Chrome — Android",    systemImage: "candybarphone",  isMobile: true),
        .init(id: "chrome_mac",      name: "Chrome — macOS",      systemImage: "laptopcomputer", isMobile: false),
        .init(id: "chrome_windows",  name: "Chrome — Windows",    systemImage: "pc",             isMobile: false),
        .init(id: "firefox_desktop", name: "Firefox — Desktop",   systemImage: "pc",             isMobile: false),
        .init(id: "custom",          name: "Custom",              systemImage: "slider.horizontal.3", isMobile: true),
    ]

    static func preset(id: String) -> IdentityPreset {
        all.first { $0.id == id } ?? all[0]
    }
}

nonisolated enum IdentityBuilder {
    static let commonLanguages: [(code: String, label: String)] = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("en-AU", "English (Australia)"),
        ("en-CA", "English (Canada)"),
        ("es-ES", "Spanish (Spain)"),
        ("es-MX", "Spanish (Mexico)"),
        ("fr-FR", "French"),
        ("de-DE", "German"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("pt-PT", "Portuguese (Portugal)"),
        ("nl-NL", "Dutch"),
        ("sv-SE", "Swedish"),
        ("nb-NO", "Norwegian"),
        ("da-DK", "Danish"),
        ("fi-FI", "Finnish"),
        ("pl-PL", "Polish"),
        ("ru-RU", "Russian"),
        ("tr-TR", "Turkish"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("zh-CN", "Chinese (Simplified)"),
        ("zh-TW", "Chinese (Traditional)"),
        ("ar-SA", "Arabic"),
        ("hi-IN", "Hindi"),
    ]

    static let commonTimezones: [String] = [
        "America/Los_Angeles", "America/Denver", "America/Chicago", "America/New_York",
        "America/Toronto", "America/Mexico_City", "America/Sao_Paulo",
        "Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Madrid", "Europe/Rome",
        "Europe/Amsterdam", "Europe/Stockholm", "Europe/Warsaw", "Europe/Moscow",
        "Africa/Cairo", "Africa/Johannesburg",
        "Asia/Dubai", "Asia/Kolkata", "Asia/Bangkok", "Asia/Shanghai", "Asia/Singapore",
        "Asia/Hong_Kong", "Asia/Tokyo", "Asia/Seoul",
        "Australia/Sydney", "Australia/Melbourne", "Australia/Perth", "Pacific/Auckland",
    ]

    static func deviceLanguage() -> String {
        Locale.preferredLanguages.first ?? "en-US"
    }

    static func deviceLanguages() -> [String] {
        let langs = Locale.preferredLanguages.prefix(4)
        return langs.isEmpty ? ["en-US"] : Array(langs)
    }

    static func deviceTimezone() -> String {
        TimeZone.current.identifier
    }

    static func acceptLanguageHeader(from languages: [String]) -> String {
        let capped = Array(languages.prefix(4))
        guard !capped.isEmpty else { return "en-US,en;q=0.9" }
        var out: [String] = []
        for (i, l) in capped.enumerated() {
            if i == 0 {
                out.append(l)
                if let base = l.split(separator: "-").first, String(base) != l {
                    out.append("\(base);q=0.9")
                }
            } else {
                let q = max(0.1, 0.8 - Double(i - 1) * 0.1)
                out.append("\(l);q=\(String(format: "%.1f", q))")
            }
        }
        return out.joined(separator: ",")
    }

    @MainActor
    static func build(mode: IdentityMode,
                      presetID: String,
                      customUA: String,
                      overrideLanguage: String?,
                      overrideTimezone: String?,
                      languages: [String]?) -> IdentityProfile {
        let iOS = ProcessInfo.processInfo.operatingSystemVersion
        let iosUnder = "\(iOS.majorVersion)_\(iOS.minorVersion)"
        let iosDot = "\(iOS.majorVersion).\(iOS.minorVersion)"
        let deviceIsIPad = UIDevice.current.userInterfaceIdiom == .pad

        let primaryLanguage = (overrideLanguage?.isEmpty == false ? overrideLanguage! : deviceLanguage())
        let langList: [String] = {
            if let custom = languages, !custom.isEmpty { return custom }
            if let ov = overrideLanguage, !ov.isEmpty { return [ov, String(ov.split(separator: "-").first ?? "en")] }
            return deviceLanguages()
        }()
        let tz = overrideTimezone?.isEmpty == false ? overrideTimezone! : deviceTimezone()

        let screen = UIScreen.main.bounds
        let scale = Double(UIScreen.main.scale)
        let screenW = Int(screen.width)
        let screenH = Int(screen.height)

        let effectiveID: String = {
            switch mode {
            case .auto: return deviceIsIPad ? "ipad_safari" : "iphone_safari"
            case .preset: return presetID == "auto" ? (deviceIsIPad ? "ipad_safari" : "iphone_safari") : presetID
            case .custom: return "custom"
            }
        }()

        func profile(for id: String) -> IdentityProfile {
            switch id {
            case "iphone_safari":
                let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosUnder) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(iosDot) Mobile/15E148 Safari/604.1"
                return IdentityProfile(
                    userAgent: ua,
                    platform: "iPhone",
                    vendor: "Apple Computer, Inc.",
                    appVersion: "5.0 (iPhone; CPU iPhone OS \(iosUnder) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(iosDot) Mobile/15E148 Safari/604.1",
                    oscpu: nil,
                    language: primaryLanguage,
                    languages: langList,
                    timezone: tz,
                    hardwareConcurrency: 4,
                    deviceMemory: 4,
                    screenWidth: screenW,
                    screenHeight: screenH,
                    devicePixelRatio: scale,
                    colorDepth: 24,
                    touchSupport: true,
                    maxTouchPoints: 5,
                    secChUa: nil,
                    secChUaMobile: "?1",
                    secChUaPlatform: "\"iOS\"",
                    acceptLanguageHeader: acceptLanguageHeader(from: langList),
                    isMobile: true
                )
            case "ipad_safari":
                let ua = "Mozilla/5.0 (iPad; CPU OS \(iosUnder) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(iosDot) Mobile/15E148 Safari/604.1"
                return IdentityProfile(
                    userAgent: ua, platform: "iPad", vendor: "Apple Computer, Inc.",
                    appVersion: ua.replacingOccurrences(of: "Mozilla/", with: ""),
                    oscpu: nil, language: primaryLanguage, languages: langList, timezone: tz,
                    hardwareConcurrency: 8, deviceMemory: 8,
                    screenWidth: screenW, screenHeight: screenH, devicePixelRatio: scale,
                    colorDepth: 24, touchSupport: true, maxTouchPoints: 5,
                    secChUa: nil, secChUaMobile: "?1", secChUaPlatform: "\"iPadOS\"",
                    acceptLanguageHeader: acceptLanguageHeader(from: langList), isMobile: true
                )
            case "mac_safari":
                let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
                return IdentityProfile(
                    userAgent: ua, platform: "MacIntel", vendor: "Apple Computer, Inc.",
                    appVersion: "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15",
                    oscpu: "Intel Mac OS X 10.15", language: primaryLanguage, languages: langList, timezone: tz,
                    hardwareConcurrency: 8, deviceMemory: 8,
                    screenWidth: 1920, screenHeight: 1080, devicePixelRatio: 2.0,
                    colorDepth: 24, touchSupport: false, maxTouchPoints: 0,
                    secChUa: nil, secChUaMobile: "?0", secChUaPlatform: "\"macOS\"",
                    acceptLanguageHeader: acceptLanguageHeader(from: langList), isMobile: false
                )
            case "chrome_ios":
                let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosUnder) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/126.0.6478.108 Mobile/15E148 Safari/604.1"
                return IdentityProfile(
                    userAgent: ua, platform: "iPhone", vendor: "Apple Computer, Inc.",
                    appVersion: "5.0 (iPhone; CPU iPhone OS \(iosUnder) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/126.0.6478.108 Mobile/15E148 Safari/604.1",
                    oscpu: nil, language: primaryLanguage, languages: langList, timezone: tz,
                    hardwareConcurrency: 4, deviceMemory: 4,
                    screenWidth: screenW, screenHeight: screenH, devicePixelRatio: scale,
                    colorDepth: 24, touchSupport: true, maxTouchPoints: 5,
                    secChUa: "\"Google Chrome\";v=\"126\", \"Chromium\";v=\"126\", \"Not=A?Brand\";v=\"99\"",
                    secChUaMobile: "?1", secChUaPlatform: "\"iOS\"",
                    acceptLanguageHeader: acceptLanguageHeader(from: langList), isMobile: true
                )
            case "chrome_android":
                let ua = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.108 Mobile Safari/537.36"
                return IdentityProfile(
                    userAgent: ua, platform: "Linux armv8l", vendor: "Google Inc.",
                    appVersion: "5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.108 Mobile Safari/537.36",
                    oscpu: nil, language: primaryLanguage, languages: langList, timezone: tz,
                    hardwareConcurrency: 8, deviceMemory: 8,
                    screenWidth: 412, screenHeight: 915, devicePixelRatio: 2.625,
                    colorDepth: 24, touchSupport: true, maxTouchPoints: 5,
                    secChUa: "\"Google Chrome\";v=\"126\", \"Chromium\";v=\"126\", \"Not=A?Brand\";v=\"99\"",
                    secChUaMobile: "?1", secChUaPlatform: "\"Android\"",
                    acceptLanguageHeader: acceptLanguageHeader(from: langList), isMobile: true
                )
            case "chrome_mac":
                let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
                return IdentityProfile(
                    userAgent: ua, platform: "MacIntel", vendor: "Google Inc.",
                    appVersion: "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                    oscpu: "Intel Mac OS X 10.15", language: primaryLanguage, languages: langList, timezone: tz,
                    hardwareConcurrency: 10, deviceMemory: 8,
                    screenWidth: 1920, screenHeight: 1080, devicePixelRatio: 2.0,
                    colorDepth: 24, touchSupport: false, maxTouchPoints: 0,
                    secChUa: "\"Google Chrome\";v=\"126\", \"Chromium\";v=\"126\", \"Not=A?Brand\";v=\"99\"",
                    secChUaMobile: "?0", secChUaPlatform: "\"macOS\"",
                    acceptLanguageHeader: acceptLanguageHeader(from: langList), isMobile: false
                )
            case "chrome_windows":
                let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
                return IdentityProfile(
                    userAgent: ua, platform: "Win32", vendor: "Google Inc.",
                    appVersion: "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                    oscpu: nil, language: primaryLanguage, languages: langList, timezone: tz,
                    hardwareConcurrency: 8, deviceMemory: 8,
                    screenWidth: 1920, screenHeight: 1080, devicePixelRatio: 1.0,
                    colorDepth: 24, touchSupport: false, maxTouchPoints: 0,
                    secChUa: "\"Google Chrome\";v=\"126\", \"Chromium\";v=\"126\", \"Not=A?Brand\";v=\"99\"",
                    secChUaMobile: "?0", secChUaPlatform: "\"Windows\"",
                    acceptLanguageHeader: acceptLanguageHeader(from: langList), isMobile: false
                )
            case "firefox_desktop":
                let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0"
                return IdentityProfile(
                    userAgent: ua, platform: "Win32", vendor: "",
                    appVersion: "5.0 (Windows)",
                    oscpu: "Windows NT 10.0; Win64; x64", language: primaryLanguage, languages: langList, timezone: tz,
                    hardwareConcurrency: 8, deviceMemory: 8,
                    screenWidth: 1920, screenHeight: 1080, devicePixelRatio: 1.0,
                    colorDepth: 24, touchSupport: false, maxTouchPoints: 0,
                    secChUa: nil, secChUaMobile: nil, secChUaPlatform: nil,
                    acceptLanguageHeader: acceptLanguageHeader(from: langList), isMobile: false
                )
            case "custom":
                let ua = customUA.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalUA = ua.isEmpty ? "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosUnder) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(iosDot) Mobile/15E148 Safari/604.1" : ua
                let inferredIsMobile = finalUA.contains("Mobile") || finalUA.contains("iPhone") || finalUA.contains("Android")
                let inferredPlatform: String = {
                    if finalUA.contains("iPhone") { return "iPhone" }
                    if finalUA.contains("iPad") { return "iPad" }
                    if finalUA.contains("Android") { return "Linux armv8l" }
                    if finalUA.contains("Macintosh") { return "MacIntel" }
                    if finalUA.contains("Windows") { return "Win32" }
                    if finalUA.contains("Linux") { return "Linux x86_64" }
                    return "iPhone"
                }()
                return IdentityProfile(
                    userAgent: finalUA, platform: inferredPlatform,
                    vendor: finalUA.contains("Chrome") && !finalUA.contains("CriOS") ? "Google Inc." : "Apple Computer, Inc.",
                    appVersion: finalUA.replacingOccurrences(of: "Mozilla/", with: ""),
                    oscpu: nil, language: primaryLanguage, languages: langList, timezone: tz,
                    hardwareConcurrency: 4, deviceMemory: 4,
                    screenWidth: screenW, screenHeight: screenH, devicePixelRatio: scale,
                    colorDepth: 24, touchSupport: inferredIsMobile, maxTouchPoints: inferredIsMobile ? 5 : 0,
                    secChUa: nil, secChUaMobile: inferredIsMobile ? "?1" : "?0", secChUaPlatform: nil,
                    acceptLanguageHeader: acceptLanguageHeader(from: langList), isMobile: inferredIsMobile
                )
            default:
                return profile(for: "iphone_safari")
            }
        }

        return profile(for: effectiveID)
    }
}

@MainActor
@Observable
final class IdentitySettings {
    static let shared = IdentitySettings()

    private let modeKey = "identity.mode"
    private let presetKey = "identity.preset"
    private let customKey = "identity.customUA"
    private let langKey = "identity.language"
    private let tzKey = "identity.timezone"

    var mode: IdentityMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: modeKey) }
    }
    var presetID: String {
        didSet { UserDefaults.standard.set(presetID, forKey: presetKey) }
    }
    var customUA: String {
        didSet { UserDefaults.standard.set(customUA, forKey: customKey) }
    }
    var languageOverride: String {
        didSet { UserDefaults.standard.set(languageOverride, forKey: langKey) }
    }
    var timezoneOverride: String {
        didSet { UserDefaults.standard.set(timezoneOverride, forKey: tzKey) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: modeKey) ?? IdentityMode.auto.rawValue
        self.mode = IdentityMode(rawValue: raw) ?? .auto
        self.presetID = UserDefaults.standard.string(forKey: presetKey) ?? "iphone_safari"
        self.customUA = UserDefaults.standard.string(forKey: customKey) ?? ""
        self.languageOverride = UserDefaults.standard.string(forKey: langKey) ?? ""
        self.timezoneOverride = UserDefaults.standard.string(forKey: tzKey) ?? ""
    }

    func resetToAuto() {
        mode = .auto
        presetID = "iphone_safari"
        customUA = ""
        languageOverride = ""
        timezoneOverride = ""
    }

    var currentIdentity: IdentityProfile {
        IdentityBuilder.build(
            mode: mode,
            presetID: presetID,
            customUA: customUA,
            overrideLanguage: languageOverride.isEmpty ? nil : languageOverride,
            overrideTimezone: timezoneOverride.isEmpty ? nil : timezoneOverride,
            languages: nil
        )
    }

    var effectiveLanguageDisplay: String {
        languageOverride.isEmpty ? "Auto · \(IdentityBuilder.deviceLanguage())" : languageOverride
    }
    var effectiveTimezoneDisplay: String {
        timezoneOverride.isEmpty ? "Auto · \(IdentityBuilder.deviceTimezone())" : timezoneOverride
    }
    var effectiveUAString: String {
        currentIdentity.userAgent
    }
}

nonisolated enum IdentityScript {
    static func makeScript(for id: IdentityProfile) -> String {
        let langsJSON = "[" + id.languages.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        let touchPart = id.isMobile ? """
        try { Object.defineProperty(navigator, 'maxTouchPoints', { get: () => \(id.maxTouchPoints) }); } catch(e){}
        """ : """
        try { Object.defineProperty(navigator, 'maxTouchPoints', { get: () => 0 }); } catch(e){}
        """
        let oscpuPart = id.oscpu.map { "try { Object.defineProperty(navigator, 'oscpu', { get: () => '\($0)' }); } catch(e){}" } ?? ""
        return """
        (function(){
            try {
                Object.defineProperty(navigator, 'platform', { get: () => '\(id.platform)' });
            } catch(e){}
            try {
                Object.defineProperty(navigator, 'vendor', { get: () => '\(id.vendor)' });
            } catch(e){}
            try {
                Object.defineProperty(navigator, 'language', { get: () => '\(id.language)' });
            } catch(e){}
            try {
                Object.defineProperty(navigator, 'languages', { get: () => \(langsJSON) });
            } catch(e){}
            try {
                Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => \(id.hardwareConcurrency) });
            } catch(e){}
            try {
                Object.defineProperty(navigator, 'deviceMemory', { get: () => \(id.deviceMemory) });
            } catch(e){}
            \(touchPart)
            \(oscpuPart)
            try {
                var _DTF = Intl.DateTimeFormat;
                var _resolved = _DTF.prototype.resolvedOptions;
                Intl.DateTimeFormat.prototype.resolvedOptions = function(){
                    var r = _resolved.call(this);
                    r.timeZone = '\(id.timezone)';
                    r.locale = '\(id.language)';
                    return r;
                };
            } catch(e){}
            try {
                var _gtzo = Date.prototype.getTimezoneOffset;
                Date.prototype.getTimezoneOffset = function(){
                    try {
                        var utc = new Date(this.toLocaleString('en-US', { timeZone: 'UTC' }));
                        var tz = new Date(this.toLocaleString('en-US', { timeZone: '\(id.timezone)' }));
                        return Math.round((utc - tz) / 60000);
                    } catch(e) { return _gtzo.call(this); }
                };
            } catch(e){}
            try {
                Object.defineProperty(screen, 'colorDepth', { get: () => \(id.colorDepth) });
                Object.defineProperty(screen, 'pixelDepth', { get: () => \(id.colorDepth) });
            } catch(e){}
            try {
                if (navigator.userAgentData) {
                    Object.defineProperty(navigator, 'userAgentData', { get: () => ({
                        brands: [{brand:'Chromium', version:'126'},{brand:'Not=A?Brand', version:'99'}],
                        mobile: \(id.isMobile ? "true" : "false"),
                        platform: '\(id.secChUaPlatform?.replacingOccurrences(of: "\"", with: "") ?? "")',
                        getHighEntropyValues: function(){ return Promise.resolve({}); }
                    })});
                }
            } catch(e){}
            try {
                if (navigator.plugins && navigator.plugins.length === 0 && !\(id.isMobile ? "true" : "false")) {
                    // keep as-is
                }
            } catch(e){}
            try {
                var origQuery = navigator.permissions && navigator.permissions.query;
                if (origQuery) {
                    navigator.permissions.query = function(p){
                        if (p && p.name === 'notifications') {
                            return Promise.resolve({ state: Notification.permission || 'prompt', onchange: null });
                        }
                        return origQuery.call(navigator.permissions, p);
                    };
                }
            } catch(e){}
        })();
        """
    }
}
