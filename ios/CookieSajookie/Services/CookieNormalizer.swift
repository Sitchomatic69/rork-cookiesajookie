import Foundation

nonisolated enum CookieNormalizer {
    static func normalize(_ cookies: [CookieData], defaultDomain: String? = nil) -> [CookieData] {
        var seen: [String: CookieData] = [:]
        for raw in cookies {
            var c = raw
            if c.domain.isEmpty, let d = defaultDomain, !d.isEmpty {
                c.domain = d
            }
            if c.path.isEmpty { c.path = "/" }
            if c.sameSite == .none && !c.isSecure { c.isSecure = true }
            // Session cookies get a far-future expiry so they survive navigations.
            if c.expiresDate == nil && !c.isSessionOnly {
                c.expiresDate = Date().addingTimeInterval(60 * 60 * 24 * 365 * 5)
            }
            seen[c.id] = c
        }
        return Array(seen.values).sorted { $0.domain < $1.domain }
    }

    static func validate(_ cookie: CookieData) -> [String] {
        var issues: [String] = []
        if cookie.name.isEmpty { issues.append("Missing name") }
        if cookie.domain.isEmpty { issues.append("Missing domain") }
        if cookie.sameSite == .none && !cookie.isSecure {
            issues.append("SameSite=None requires Secure")
        }
        return issues
    }
}
