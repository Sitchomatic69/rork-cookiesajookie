import Foundation

nonisolated enum CookieImportFormat: String, Codable, Sendable, CaseIterable, Identifiable {
    case netscape
    case json
    case curl
    case headerString
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .netscape: return "Netscape"
        case .json: return "JSON"
        case .curl: return "cURL"
        case .headerString: return "Cookie Header"
        case .unknown: return "Unknown"
        }
    }
}

nonisolated struct CookieParseResult: Sendable {
    var cookies: [CookieData]
    var format: CookieImportFormat
    var warnings: [String]
}

nonisolated enum CookieParser {
    static func detectFormat(_ raw: String) -> CookieImportFormat {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .unknown }
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") { return .json }
        if trimmed.lowercased().contains("curl ") || trimmed.contains("-H 'Cookie:") || trimmed.contains("-b ") {
            return .curl
        }
        if trimmed.contains("# Netscape HTTP Cookie File") || looksLikeNetscape(trimmed) {
            return .netscape
        }
        if trimmed.contains("=") && !trimmed.contains("\n") {
            return .headerString
        }
        if trimmed.contains("=") {
            return .headerString
        }
        return .unknown
    }

    private static func looksLikeNetscape(_ text: String) -> Bool {
        let lines = text.split(separator: "\n").prefix(20)
        var tabLines = 0
        for line in lines {
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty || stripped.hasPrefix("#") { continue }
            let parts = stripped.split(separator: "\t")
            if parts.count >= 6 { tabLines += 1 }
        }
        return tabLines > 0
    }

    static func parse(_ raw: String, format: CookieImportFormat? = nil) -> CookieParseResult {
        let fmt = format ?? detectFormat(raw)
        switch fmt {
        case .json: return parseJSON(raw)
        case .netscape: return parseNetscape(raw)
        case .curl: return parseCurl(raw)
        case .headerString: return parseHeaderString(raw)
        case .unknown:
            return CookieParseResult(cookies: [], format: .unknown, warnings: ["Unknown cookie format."])
        }
    }

    // MARK: - JSON

    private static func parseJSON(_ raw: String) -> CookieParseResult {
        var warnings: [String] = []
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return CookieParseResult(cookies: [], format: .json, warnings: ["Invalid JSON."])
        }
        let entries: [[String: Any]]
        if let arr = obj as? [[String: Any]] {
            entries = arr
        } else if let wrapper = obj as? [String: Any], let arr = wrapper["cookies"] as? [[String: Any]] {
            entries = arr
        } else if let single = obj as? [String: Any] {
            entries = [single]
        } else {
            return CookieParseResult(cookies: [], format: .json, warnings: ["JSON structure not recognized."])
        }

        var cookies: [CookieData] = []
        for entry in entries {
            if let c = cookieFromJSON(entry) {
                cookies.append(c)
            } else {
                warnings.append("Skipped invalid entry.")
            }
        }
        return CookieParseResult(cookies: cookies, format: .json, warnings: warnings)
    }

    private static func cookieFromJSON(_ entry: [String: Any]) -> CookieData? {
        let name = (entry["name"] as? String) ?? (entry["Name"] as? String) ?? ""
        let value = (entry["value"] as? String) ?? (entry["Value"] as? String) ?? ""
        let domain = (entry["domain"] as? String) ?? (entry["Domain"] as? String) ?? ""
        guard !name.isEmpty, !domain.isEmpty else { return nil }
        let path = (entry["path"] as? String) ?? "/"
        let isSecure = (entry["secure"] as? Bool) ?? (entry["isSecure"] as? Bool) ?? false
        let isHTTPOnly = (entry["httpOnly"] as? Bool) ?? (entry["httponly"] as? Bool) ?? (entry["isHTTPOnly"] as? Bool) ?? false
        let isSessionOnly = (entry["session"] as? Bool) ?? (entry["isSessionOnly"] as? Bool) ?? false
        var expires: Date?
        if let ts = entry["expirationDate"] as? Double {
            expires = Date(timeIntervalSince1970: ts)
        } else if let ts = entry["expires"] as? Double {
            expires = Date(timeIntervalSince1970: ts)
        } else if let s = entry["expires"] as? String, let d = parseAnyDate(s) {
            expires = d
        }
        let sameSiteRaw = entry["sameSite"] as? String ?? entry["samesite"] as? String
        return CookieData(name: name,
                          value: value,
                          domain: domain,
                          path: path,
                          isSecure: isSecure,
                          isHTTPOnly: isHTTPOnly,
                          expiresDate: expires,
                          isSessionOnly: isSessionOnly,
                          sameSite: SameSitePolicy(fromString: sameSiteRaw))
    }

    // MARK: - Netscape

    private static func parseNetscape(_ raw: String) -> CookieParseResult {
        var warnings: [String] = []
        var cookies: [CookieData] = []
        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("#HttpOnly_") { continue }

            var working = trimmed
            var httpOnly = false
            if working.hasPrefix("#HttpOnly_") {
                httpOnly = true
                working = String(working.dropFirst("#HttpOnly_".count))
            }
            let parts = working.split(separator: "\t", omittingEmptySubsequences: false).map { String($0) }
            guard parts.count >= 7 else {
                warnings.append("Line has too few fields.")
                continue
            }
            let domain = parts[0]
            let secureStr = parts[3].uppercased()
            let path = parts[2].isEmpty ? "/" : parts[2]
            let expiresInt = Double(parts[4]) ?? 0
            let name = parts[5]
            let value = parts[6]
            let expires: Date? = expiresInt > 0 ? Date(timeIntervalSince1970: expiresInt) : nil
            let cookie = CookieData(name: name,
                                    value: value,
                                    domain: domain,
                                    path: path,
                                    isSecure: secureStr == "TRUE",
                                    isHTTPOnly: httpOnly,
                                    expiresDate: expires,
                                    isSessionOnly: expires == nil,
                                    sameSite: .unspecified)
            cookies.append(cookie)
        }
        return CookieParseResult(cookies: cookies, format: .netscape, warnings: warnings)
    }

    // MARK: - cURL

    private static func parseCurl(_ raw: String) -> CookieParseResult {
        var warnings: [String] = []
        var header: String?
        var host: String?

        // Look for Cookie header
        if let range = raw.range(of: #"Cookie:\s*([^'\"\n]+)"#, options: .regularExpression) {
            let substr = String(raw[range])
            if let colonIdx = substr.firstIndex(of: ":") {
                header = String(substr[substr.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        if let range = raw.range(of: #"-b\s+['"]([^'\"]+)['"]"#, options: .regularExpression) {
            let substr = String(raw[range])
            if let q = substr.firstIndex(where: { $0 == "'" || $0 == "\"" }) {
                var s = String(substr[substr.index(after: q)...])
                if let endQ = s.lastIndex(where: { $0 == "'" || $0 == "\"" }) {
                    s = String(s[..<endQ])
                }
                header = s
            }
        }
        // Find URL for host
        if let urlMatch = raw.range(of: #"https?://[^\s'\"]+"#, options: .regularExpression) {
            if let url = URL(string: String(raw[urlMatch])) {
                host = url.host
            }
        }
        guard let hdr = header else {
            warnings.append("No Cookie header or -b flag found.")
            return CookieParseResult(cookies: [], format: .curl, warnings: warnings)
        }
        let result = parseHeaderValue(hdr, domain: host ?? "")
        if host == nil {
            warnings.append("No URL in curl; domain defaulted to blank. Set domain manually.")
        }
        return CookieParseResult(cookies: result, format: .curl, warnings: warnings)
    }

    private static func parseHeaderString(_ raw: String) -> CookieParseResult {
        let cookies = parseHeaderValue(raw, domain: "")
        var warnings: [String] = []
        if cookies.contains(where: { $0.domain.isEmpty }) {
            warnings.append("Domain is blank; edit before importing.")
        }
        return CookieParseResult(cookies: cookies, format: .headerString, warnings: warnings)
    }

    private static func parseHeaderValue(_ value: String, domain: String) -> [CookieData] {
        var result: [CookieData] = []
        let pairs = value.split(separator: ";")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2, !kv[0].isEmpty else { continue }
            result.append(CookieData(name: kv[0], value: kv[1], domain: domain, path: "/"))
        }
        return result
    }

    private static func parseAnyDate(_ s: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let d = isoFormatter.date(from: s) { return d }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        for pattern in ["EEE, dd MMM yyyy HH:mm:ss 'GMT'", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            fmt.dateFormat = pattern
            if let d = fmt.date(from: s) { return d }
        }
        return nil
    }
}
