import Foundation

nonisolated enum CookieExportFormat: String, Codable, Sendable, CaseIterable, Identifiable {
    case netscape
    case json
    case headerString

    var id: String { rawValue }

    var label: String {
        switch self {
        case .netscape: return "Netscape"
        case .json: return "JSON"
        case .headerString: return "Cookie Header"
        }
    }

    var fileExtension: String {
        switch self {
        case .netscape: return "txt"
        case .json: return "json"
        case .headerString: return "txt"
        }
    }
}

nonisolated enum CookieExporter {
    static func export(_ cookies: [CookieData], format: CookieExportFormat) -> String {
        switch format {
        case .netscape: return exportNetscape(cookies)
        case .json: return exportJSON(cookies)
        case .headerString: return exportHeader(cookies)
        }
    }

    private static func exportNetscape(_ cookies: [CookieData]) -> String {
        var lines: [String] = [
            "# Netscape HTTP Cookie File",
            "# Exported by CookieSajookie",
            ""
        ]
        for c in cookies {
            let prefix = c.isHTTPOnly ? "#HttpOnly_" : ""
            let domain = c.domain
            let includeSubdomains = domain.hasPrefix(".") ? "TRUE" : "FALSE"
            let path = c.path.isEmpty ? "/" : c.path
            let secure = c.isSecure ? "TRUE" : "FALSE"
            let exp: String = {
                if let d = c.expiresDate { return String(Int(d.timeIntervalSince1970)) }
                return "0"
            }()
            let line = "\(prefix)\(domain)\t\(includeSubdomains)\t\(path)\t\(secure)\t\(exp)\t\(c.name)\t\(c.value)"
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private static func exportJSON(_ cookies: [CookieData]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cookies),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func exportHeader(_ cookies: [CookieData]) -> String {
        cookies.map { $0.httpHeaderValue }.joined(separator: "; ")
    }
}
