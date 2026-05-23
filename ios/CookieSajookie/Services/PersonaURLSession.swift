import Foundation

/// Builds a `URLSession` whose every request carries persona-matching headers
/// in the same order iOS Safari emits them, on an `.ephemeral` configuration
/// so disk caches can't survive a profile cycle.
///
/// NOTE on TLS/JA3/JA4: Apple's Network framework / URLSession reuses the
/// system TLS stack — we cannot fully reshape the ClientHello to mimic
/// Chrome/Firefox. We CAN ensure that the TLS fingerprint and the User-Agent
/// agree (both originate from iOS), which is what fingerprint vendors
/// actually flag as "tampering".
@MainActor
final class PersonaURLSession {

    private(set) var session: URLSession
    private(set) var persona: BrowsingPersona

    init(persona: BrowsingPersona) {
        self.persona = persona
        self.session = Self.makeSession(for: persona)
    }

    func rebuild(for persona: BrowsingPersona) {
        self.session.invalidateAndCancel()
        self.persona = persona
        self.session = Self.makeSession(for: persona)
    }

    private static func makeSession(for p: BrowsingPersona) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = headers(for: p)
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        if #available(iOS 15.0, *) {
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
        }
        return URLSession(configuration: config)
    }

    /// Header order matches what iOS Safari actually sends (User-Agent first,
    /// then Accept, Accept-Language, etc.). `URLSession` doesn't strictly
    /// honor insertion order, but provides best-effort consistency.
    static func headers(for p: BrowsingPersona) -> [AnyHashable: Any] {
        var h: [AnyHashable: Any] = [:]
        h["User-Agent"] = p.userAgent
        h["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        h["Accept-Language"] = p.acceptLanguageHeader
        h["Accept-Encoding"] = "gzip, deflate, br"
        h["Sec-Fetch-Site"] = "none"
        h["Sec-Fetch-Mode"] = "navigate"
        h["Sec-Fetch-Dest"] = "document"
        if let secChUa = p.secChUa {
            h["Sec-CH-UA"] = secChUa
            h["Sec-CH-UA-Mobile"] = p.secChUaMobile
            h["Sec-CH-UA-Platform"] = p.secChUaPlatform
        }
        return h
    }
}
