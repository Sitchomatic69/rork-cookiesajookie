import Foundation

/// Immutable, Codable description of one believable real-world iOS device persona.
///
/// Every signal a fingerprinting library can read MUST be derivable from this
/// struct — that's how we keep the entire app's identity internally consistent.
nonisolated struct BrowsingPersona: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let deviceFamily: DeviceFamily
    let iosVersion: IOSVersion

    // Navigator / UA
    let userAgent: String
    let platform: String
    let vendor: String
    let appVersion: String
    let hardwareConcurrency: Int
    let deviceMemory: Int
    let maxTouchPoints: Int
    let isMobile: Bool

    // Screen
    let screenWidth: Int
    let screenHeight: Int
    let availWidth: Int
    let availHeight: Int
    let devicePixelRatio: Double
    let colorDepth: Int

    // Locale / timezone (filled at cycle time)
    let language: String
    let languages: [String]
    let timezone: String
    let acceptLanguageHeader: String

    // Client hints (Safari iOS does NOT send Sec-CH-UA; keep nil for Safari personas)
    let secChUa: String?
    let secChUaMobile: String
    let secChUaPlatform: String

    // Rendering / GPU
    let webglVendor: String
    let webglRenderer: String
    let webglUnmaskedVendor: String
    let webglUnmaskedRenderer: String

    // Audio
    let audioSampleRate: Int

    // Fonts (real iOS bundled font subset)
    let fonts: [String]

    // Deterministic seed for canvas/audio sub-pixel offsets.
    let renderSeed: UInt64

    nonisolated enum DeviceFamily: String, Codable, Sendable, Hashable {
        case iPhone15Pro
        case iPhone15ProMax
        case iPhone16
        case iPhone16Pro
        case iPhone16ProMax
        case iPhone16e
        case iPadPro11M4
        case iPadPro13M4
        case iPadAirM2
        case iPadMini7
    }

    nonisolated struct IOSVersion: Codable, Sendable, Hashable {
        let major: Int
        let minor: Int
        var underscored: String { "\(major)_\(minor)" }
        var dotted: String { "\(major).\(minor)" }
    }
}
