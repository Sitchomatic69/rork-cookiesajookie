import Foundation
import SwiftUI

nonisolated enum CookiePurpose: String, Codable, Sendable, CaseIterable {
    case authentication
    case tracking
    case analytics
    case preferences
    case session
    case security
    case other

    var label: String {
        switch self {
        case .authentication: return "Auth"
        case .tracking: return "Tracking"
        case .analytics: return "Analytics"
        case .preferences: return "Prefs"
        case .session: return "Session"
        case .security: return "Security"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .authentication: return "person.badge.key.fill"
        case .tracking: return "dot.radiowaves.left.and.right"
        case .analytics: return "chart.bar.fill"
        case .preferences: return "slider.horizontal.3"
        case .session: return "clock.fill"
        case .security: return "lock.shield.fill"
        case .other: return "circle.hexagongrid.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .authentication: return "#22C55E"
        case .tracking: return "#EF4444"
        case .analytics: return "#F59E0B"
        case .preferences: return "#3B82F6"
        case .session: return "#A855F7"
        case .security: return "#14B8A6"
        case .other: return "#9CA3AF"
        }
    }
}

nonisolated enum CookiePurposeClassifier {
    static func classify(_ cookie: CookieData) -> CookiePurpose {
        let name = cookie.name.lowercased()
        let authMarkers = ["sess", "session", "auth", "token", "jwt", "sid", "sso", "login", "logged", "user", "uid", "access", "refresh", "oauth", "csrftoken", "rememberme"]
        let trackMarkers = ["_ga", "_gid", "_gcl", "_fbp", "_fbc", "fr", "ide", "nid", "anj", "uid2", "mp_", "amplitude", "mixpanel", "segment_", "hjid", "hjsession", "hubspotutk", "ajs_", "_pin_unauth", "_tt_", "tiktok"]
        let analyticsMarkers = ["_gat", "_utm", "utm_", "_clck", "_clsk", "_hjincludedinsessionsample", "optimizely", "_pk_"]
        let prefMarkers = ["pref", "lang", "locale", "theme", "color", "layout", "consent", "cookieconsent", "accept", "ui-", "display"]
        let securityMarkers = ["csrf", "xsrf", "secure", "antiforgery", "__host-", "__secure-"]

        for m in authMarkers where name.contains(m) { return .authentication }
        for m in securityMarkers where name.contains(m) || cookie.name.lowercased().hasPrefix(m) { return .security }
        for m in trackMarkers where name.contains(m) { return .tracking }
        for m in analyticsMarkers where name.contains(m) { return .analytics }
        for m in prefMarkers where name.contains(m) { return .preferences }
        if cookie.isSessionOnly { return .session }
        return .other
    }
}

nonisolated enum RootDomainResolver {
    private static let multiPartTLDs: Set<String> = [
        "co.uk", "co.jp", "co.kr", "co.in", "co.nz", "co.za",
        "com.au", "com.br", "com.cn", "com.mx", "com.tr", "com.sg", "com.hk",
        "org.uk", "net.au", "gov.uk", "ac.uk", "ne.jp", "or.jp",
    ]

    static func root(of domain: String) -> String {
        let clean = (domain.hasPrefix(".") ? String(domain.dropFirst()) : domain).lowercased()
        let parts = clean.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return clean }
        if parts.count >= 3 {
            let lastTwo = parts.suffix(2).joined(separator: ".")
            if multiPartTLDs.contains(lastTwo) {
                return parts.suffix(3).joined(separator: ".")
            }
        }
        return parts.suffix(2).joined(separator: ".")
    }
}

nonisolated struct CookieSet: Identifiable, Hashable, Sendable {
    let rootDomain: String
    let cookies: [CookieData]
    let purposes: [CookiePurpose]
    let totalBytes: Int
    let isFirstParty: Bool
    let lastSeen: Date?

    var id: String { rootDomain }

    var domainsCount: Int {
        Set(cookies.map { $0.domain.hasPrefix(".") ? String($0.domain.dropFirst()) : $0.domain }).count
    }

    var validCount: Int { cookies.filter { $0.status == .valid || $0.status == .session }.count }
    var expiredCount: Int { cookies.filter { $0.status == .expired }.count }
}

nonisolated enum CookieSetSort: String, CaseIterable, Sendable {
    case size
    case count
    case party
    case alphabetical

    var label: String {
        switch self {
        case .size: return "Size"
        case .count: return "Count"
        case .party: return "Party"
        case .alphabetical: return "A–Z"
        }
    }
}

nonisolated enum CookieSetBuilder {
    static func buildSets(from cookies: [CookieData], currentHost: String?) -> [CookieSet] {
        let currentRoot = currentHost.map { RootDomainResolver.root(of: $0) }
        let grouped = Dictionary(grouping: cookies) { RootDomainResolver.root(of: $0.domain) }
        var sets: [CookieSet] = []
        for (root, group) in grouped {
            let sorted = group.sorted { $0.name.lowercased() < $1.name.lowercased() }
            let purposes = Array(Set(sorted.map { CookiePurposeClassifier.classify($0) }))
                .sorted { $0.rawValue < $1.rawValue }
            let bytes = sorted.reduce(0) { $0 + $1.name.utf8.count + $1.value.utf8.count + $1.domain.utf8.count }
            let firstParty = currentRoot.map { $0 == root } ?? true
            let lastSeen = sorted.compactMap { $0.expiresDate }.max()
            sets.append(CookieSet(
                rootDomain: root,
                cookies: sorted,
                purposes: purposes,
                totalBytes: bytes,
                isFirstParty: firstParty,
                lastSeen: lastSeen
            ))
        }
        return sets
    }

    static func sort(_ sets: [CookieSet], by sort: CookieSetSort) -> [CookieSet] {
        switch sort {
        case .size: return sets.sorted { $0.totalBytes > $1.totalBytes }
        case .count: return sets.sorted { $0.cookies.count > $1.cookies.count }
        case .party: return sets.sorted { (a, b) in
            if a.isFirstParty != b.isFirstParty { return a.isFirstParty && !b.isFirstParty }
            return a.rootDomain < b.rootDomain
        }
        case .alphabetical: return sets.sorted { $0.rootDomain < $1.rootDomain }
        }
    }
}
