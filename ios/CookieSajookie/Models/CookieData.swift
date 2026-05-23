import Foundation

nonisolated enum SameSitePolicy: String, Codable, Sendable, CaseIterable {
    case none
    case lax
    case strict
    case unspecified

    init(fromString raw: String?) {
        guard let raw = raw?.lowercased() else { self = .unspecified; return }
        switch raw {
        case "none": self = .none
        case "lax": self = .lax
        case "strict": self = .strict
        default: self = .unspecified
        }
    }
}

nonisolated enum CookieStatus: String, Codable, Sendable {
    case valid
    case expiringSoon
    case expired
    case session
}

nonisolated struct CookieData: Codable, Sendable, Identifiable, Hashable {
    var name: String
    var value: String
    var domain: String
    var path: String
    var isSecure: Bool
    var isHTTPOnly: Bool
    var expiresDate: Date?
    var isSessionOnly: Bool
    var sameSite: SameSitePolicy

    var id: String { "\(domain)|\(name)|\(path)" }

    var status: CookieStatus {
        if isSessionOnly || expiresDate == nil { return .session }
        guard let d = expiresDate else { return .session }
        let now = Date()
        if d < now { return .expired }
        if d.timeIntervalSince(now) < 60 * 60 * 24 * 3 { return .expiringSoon }
        return .valid
    }

    init(name: String,
         value: String,
         domain: String,
         path: String = "/",
         isSecure: Bool = false,
         isHTTPOnly: Bool = false,
         expiresDate: Date? = nil,
         isSessionOnly: Bool = false,
         sameSite: SameSitePolicy = .unspecified) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path.isEmpty ? "/" : path
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.expiresDate = expiresDate
        self.isSessionOnly = isSessionOnly
        self.sameSite = sameSite
    }

    init(from cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
        self.expiresDate = cookie.expiresDate
        self.isSessionOnly = cookie.isSessionOnly
        self.sameSite = SameSitePolicy(fromString: cookie.sameSitePolicy?.rawValue)
    }

    func toHTTPCookie() -> HTTPCookie? {
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path.isEmpty ? "/" : path,
        ]
        if let exp = expiresDate {
            props[.expires] = exp
        } else if !isSessionOnly {
            props[.expires] = Date().addingTimeInterval(60 * 60 * 24 * 365 * 5)
        }
        if isSecure || sameSite == .none {
            props[.secure] = true
        }
        switch sameSite {
        case .none: props[.sameSitePolicy] = "none"
        case .lax: props[.sameSitePolicy] = "lax"
        case .strict: props[.sameSitePolicy] = "strict"
        case .unspecified: break
        }
        return HTTPCookie(properties: props)
    }

    var toJavaScript: String {
        guard !isHTTPOnly else { return "" }
        var parts: [String] = ["\(name)=\(value)"]
        parts.append("path=\(path)")
        let cleanDomain = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
        parts.append("domain=\(cleanDomain)")
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        let expiry = expiresDate ?? Date().addingTimeInterval(60 * 60 * 24 * 365 * 5)
        parts.append("expires=\(formatter.string(from: expiry))")
        if isSecure { parts.append("Secure") }
        switch sameSite {
        case .none: parts.append("SameSite=None")
        case .lax: parts.append("SameSite=Lax")
        case .strict: parts.append("SameSite=Strict")
        case .unspecified: break
        }
        return "document.cookie = \"\(parts.joined(separator: "; "))\";"
    }

    var httpHeaderValue: String { "\(name)=\(value)" }

    func matchesDomain(_ urlHost: String) -> Bool {
        let host = urlHost.lowercased()
        let clean = (domain.hasPrefix(".") ? String(domain.dropFirst()) : domain).lowercased()
        return host == clean || host.hasSuffix(".\(clean)")
    }
}
