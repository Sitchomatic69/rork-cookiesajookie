import Foundation

/// Static catalog of selectable languages and timezones for the custom locale
/// picker, plus small display helpers. Kept lightweight (no per-launch work).
nonisolated enum LocaleCatalog {

    struct Language: Identifiable, Hashable, Sendable {
        let code: String
        let label: String
        var id: String { code }
    }

    struct Timezone: Identifiable, Hashable, Sendable {
        /// IANA identifier, e.g. `Australia/Melbourne`.
        let id: String
        let city: String
        let region: String
    }

    static let languages: [Language] = [
        .init(code: "en-US", label: "English (United States)"),
        .init(code: "en-GB", label: "English (United Kingdom)"),
        .init(code: "en-AU", label: "English (Australia)"),
        .init(code: "en-CA", label: "English (Canada)"),
        .init(code: "en-IE", label: "English (Ireland)"),
        .init(code: "en-IN", label: "English (India)"),
        .init(code: "en-NZ", label: "English (New Zealand)"),
        .init(code: "en-ZA", label: "English (South Africa)"),
        .init(code: "es-ES", label: "Spanish (Spain)"),
        .init(code: "es-MX", label: "Spanish (Mexico)"),
        .init(code: "es-AR", label: "Spanish (Argentina)"),
        .init(code: "es-US", label: "Spanish (United States)"),
        .init(code: "fr-FR", label: "French (France)"),
        .init(code: "fr-CA", label: "French (Canada)"),
        .init(code: "fr-BE", label: "French (Belgium)"),
        .init(code: "de-DE", label: "German (Germany)"),
        .init(code: "de-AT", label: "German (Austria)"),
        .init(code: "de-CH", label: "German (Switzerland)"),
        .init(code: "it-IT", label: "Italian (Italy)"),
        .init(code: "nl-NL", label: "Dutch (Netherlands)"),
        .init(code: "pt-BR", label: "Portuguese (Brazil)"),
        .init(code: "pt-PT", label: "Portuguese (Portugal)"),
        .init(code: "sv-SE", label: "Swedish (Sweden)"),
        .init(code: "nb-NO", label: "Norwegian (Norway)"),
        .init(code: "da-DK", label: "Danish (Denmark)"),
        .init(code: "fi-FI", label: "Finnish (Finland)"),
        .init(code: "pl-PL", label: "Polish (Poland)"),
        .init(code: "cs-CZ", label: "Czech (Czechia)"),
        .init(code: "ru-RU", label: "Russian (Russia)"),
        .init(code: "uk-UA", label: "Ukrainian (Ukraine)"),
        .init(code: "tr-TR", label: "Turkish (Türkiye)"),
        .init(code: "ar-SA", label: "Arabic (Saudi Arabia)"),
        .init(code: "he-IL", label: "Hebrew (Israel)"),
        .init(code: "hi-IN", label: "Hindi (India)"),
        .init(code: "th-TH", label: "Thai (Thailand)"),
        .init(code: "vi-VN", label: "Vietnamese (Vietnam)"),
        .init(code: "id-ID", label: "Indonesian (Indonesia)"),
        .init(code: "ja-JP", label: "Japanese (Japan)"),
        .init(code: "ko-KR", label: "Korean (South Korea)"),
        .init(code: "zh-CN", label: "Chinese (Simplified)"),
        .init(code: "zh-TW", label: "Chinese (Traditional)"),
        .init(code: "zh-HK", label: "Chinese (Hong Kong)"),
    ]

    static let timezones: [Timezone] = [
        .init(id: "America/Los_Angeles", city: "Los Angeles", region: "United States"),
        .init(id: "America/Denver", city: "Denver", region: "United States"),
        .init(id: "America/Chicago", city: "Chicago", region: "United States"),
        .init(id: "America/New_York", city: "New York", region: "United States"),
        .init(id: "America/Toronto", city: "Toronto", region: "Canada"),
        .init(id: "America/Vancouver", city: "Vancouver", region: "Canada"),
        .init(id: "America/Mexico_City", city: "Mexico City", region: "Mexico"),
        .init(id: "America/Bogota", city: "Bogotá", region: "Colombia"),
        .init(id: "America/Sao_Paulo", city: "São Paulo", region: "Brazil"),
        .init(id: "America/Argentina/Buenos_Aires", city: "Buenos Aires", region: "Argentina"),
        .init(id: "Europe/London", city: "London", region: "United Kingdom"),
        .init(id: "Europe/Dublin", city: "Dublin", region: "Ireland"),
        .init(id: "Europe/Paris", city: "Paris", region: "France"),
        .init(id: "Europe/Madrid", city: "Madrid", region: "Spain"),
        .init(id: "Europe/Berlin", city: "Berlin", region: "Germany"),
        .init(id: "Europe/Amsterdam", city: "Amsterdam", region: "Netherlands"),
        .init(id: "Europe/Rome", city: "Rome", region: "Italy"),
        .init(id: "Europe/Zurich", city: "Zurich", region: "Switzerland"),
        .init(id: "Europe/Stockholm", city: "Stockholm", region: "Sweden"),
        .init(id: "Europe/Oslo", city: "Oslo", region: "Norway"),
        .init(id: "Europe/Warsaw", city: "Warsaw", region: "Poland"),
        .init(id: "Europe/Istanbul", city: "Istanbul", region: "Türkiye"),
        .init(id: "Europe/Moscow", city: "Moscow", region: "Russia"),
        .init(id: "Africa/Cairo", city: "Cairo", region: "Egypt"),
        .init(id: "Africa/Johannesburg", city: "Johannesburg", region: "South Africa"),
        .init(id: "Asia/Dubai", city: "Dubai", region: "United Arab Emirates"),
        .init(id: "Asia/Jerusalem", city: "Jerusalem", region: "Israel"),
        .init(id: "Asia/Kolkata", city: "Kolkata", region: "India"),
        .init(id: "Asia/Bangkok", city: "Bangkok", region: "Thailand"),
        .init(id: "Asia/Singapore", city: "Singapore", region: "Singapore"),
        .init(id: "Asia/Hong_Kong", city: "Hong Kong", region: "Hong Kong"),
        .init(id: "Asia/Shanghai", city: "Shanghai", region: "China"),
        .init(id: "Asia/Tokyo", city: "Tokyo", region: "Japan"),
        .init(id: "Asia/Seoul", city: "Seoul", region: "South Korea"),
        .init(id: "Australia/Perth", city: "Perth", region: "Australia"),
        .init(id: "Australia/Sydney", city: "Sydney", region: "Australia"),
        .init(id: "Australia/Melbourne", city: "Melbourne", region: "Australia"),
        .init(id: "Pacific/Auckland", city: "Auckland", region: "New Zealand"),
    ]

    static func languageLabel(_ code: String) -> String {
        languages.first { $0.code == code }?.label ?? code
    }

    static func timezoneCity(_ id: String) -> String {
        timezones.first { $0.id == id }?.city ?? id
    }

    /// Current UTC offset string for a timezone, e.g. `GMT+10:00`. Reflects DST.
    static func gmtOffset(_ id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "" }
        let seconds = tz.secondsFromGMT()
        let sign = seconds >= 0 ? "+" : "-"
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        return String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }
}
