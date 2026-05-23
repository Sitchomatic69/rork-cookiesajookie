import Foundation

@MainActor
struct BrowserRequestFactory {
    /// Build a navigation request whose headers exactly match the active persona.
    /// User-Agent is set on the webview separately (`customUserAgent`) so we
    /// don't double it here.
    func makeRequest(url: URL, profile: BrowsingProfile, persona: BrowsingPersona) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(persona.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        if let secChUa = persona.secChUa {
            request.setValue(secChUa, forHTTPHeaderField: "Sec-CH-UA")
            request.setValue(persona.secChUaMobile, forHTTPHeaderField: "Sec-CH-UA-Mobile")
            request.setValue(persona.secChUaPlatform, forHTTPHeaderField: "Sec-CH-UA-Platform")
        }

        let cookies = profile.cachedCookies.filter { $0.matchesDomain(url.host ?? "") }
        if !cookies.isEmpty {
            let header = cookies.map(\.httpHeaderValue).joined(separator: "; ")
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
        return request
    }
}
