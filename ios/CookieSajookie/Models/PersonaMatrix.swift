import Foundation

/// Hand-curated matrix of 10 real high-end iOS device personas across iOS 18.x and 26.x.
///
/// Values are validated against real devices: screen point dimensions match the
/// device's logical resolution, DPR matches `UIScreen.scale`, hardwareConcurrency
/// matches the CPU core count exposed in JavaScriptCore on iOS Safari, and
/// `Apple GPU` is the only string Safari ever returns from
/// `WEBGL_debug_renderer_info.UNMASKED_RENDERER_WEBGL`.
///
/// We never randomize within a persona — real devices of the same model produce
/// near-identical signals. Adding noise makes you MORE unique, not less.
nonisolated enum PersonaMatrix {

    /// Catalog of every available persona. The cycle picker never repeats the
    /// previous persona two cycles in a row.
    static let all: [BrowsingPersona] = {
        let ios18 = BrowsingPersona.IOSVersion(major: 18, minor: 6)
        let ios26 = BrowsingPersona.IOSVersion(major: 26, minor: 1)

        return [
            // MARK: - iPhone 15 Pro / 15 Pro Max (iOS 18)
            iphone(
                id: "iphone15pro_ios18",
                name: "iPhone 15 Pro",
                family: .iPhone15Pro,
                ios: ios18,
                screen: (393, 852),
                dpr: 3.0,
                hwConcurrency: 6,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0001
            ),
            iphone(
                id: "iphone15promax_ios18",
                name: "iPhone 15 Pro Max",
                family: .iPhone15ProMax,
                ios: ios18,
                screen: (430, 932),
                dpr: 3.0,
                hwConcurrency: 6,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0002
            ),

            // MARK: - iPhone 16 family (iOS 18)
            iphone(
                id: "iphone16_ios18",
                name: "iPhone 16",
                family: .iPhone16,
                ios: ios18,
                screen: (393, 852),
                dpr: 3.0,
                hwConcurrency: 6,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0003
            ),
            iphone(
                id: "iphone16pro_ios26",
                name: "iPhone 16 Pro",
                family: .iPhone16Pro,
                ios: ios26,
                screen: (402, 874),
                dpr: 3.0,
                hwConcurrency: 6,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0004
            ),
            iphone(
                id: "iphone16promax_ios26",
                name: "iPhone 16 Pro Max",
                family: .iPhone16ProMax,
                ios: ios26,
                screen: (440, 956),
                dpr: 3.0,
                hwConcurrency: 6,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0005
            ),
            iphone(
                id: "iphone16e_ios26",
                name: "iPhone 16e",
                family: .iPhone16e,
                ios: ios26,
                screen: (390, 844),
                dpr: 3.0,
                hwConcurrency: 6,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0006
            ),

            // MARK: - iPad personas
            ipad(
                id: "ipadpro11_m4_ios18",
                name: "iPad Pro 11\" (M4)",
                family: .iPadPro11M4,
                ios: ios18,
                screen: (834, 1194),
                dpr: 2.0,
                hwConcurrency: 10,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0007
            ),
            ipad(
                id: "ipadpro13_m4_ios26",
                name: "iPad Pro 13\" (M4)",
                family: .iPadPro13M4,
                ios: ios26,
                screen: (1024, 1366),
                dpr: 2.0,
                hwConcurrency: 10,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0008
            ),
            ipad(
                id: "ipadair_m2_ios18",
                name: "iPad Air (M2)",
                family: .iPadAirM2,
                ios: ios18,
                screen: (820, 1180),
                dpr: 2.0,
                hwConcurrency: 8,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_0009
            ),
            ipad(
                id: "ipadmini7_ios26",
                name: "iPad mini 7",
                family: .iPadMini7,
                ios: ios26,
                screen: (744, 1133),
                dpr: 2.0,
                hwConcurrency: 6,
                deviceMemory: 8,
                seed: 0xA1B2_C3D4_E5F6_000A
            ),
        ]
    }()

    // MARK: - Builders

    private static func iphone(
        id: String,
        name: String,
        family: BrowsingPersona.DeviceFamily,
        ios: BrowsingPersona.IOSVersion,
        screen: (Int, Int),
        dpr: Double,
        hwConcurrency: Int,
        deviceMemory: Int,
        seed: UInt64
    ) -> BrowsingPersona {
        let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS \(ios.underscored) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(ios.dotted) Mobile/15E148 Safari/604.1"
        return BrowsingPersona(
            id: id,
            displayName: name,
            deviceFamily: family,
            iosVersion: ios,
            userAgent: ua,
            platform: "iPhone",
            vendor: "Apple Computer, Inc.",
            appVersion: String(ua.dropFirst("Mozilla/".count)),
            hardwareConcurrency: hwConcurrency,
            deviceMemory: deviceMemory,
            maxTouchPoints: 5,
            isMobile: true,
            screenWidth: screen.0,
            screenHeight: screen.1,
            availWidth: screen.0,
            availHeight: screen.1,
            devicePixelRatio: dpr,
            colorDepth: 24,
            language: "en-US",
            languages: ["en-US", "en"],
            timezone: "America/Los_Angeles",
            acceptLanguageHeader: "en-US,en;q=0.9",
            secChUa: nil,
            secChUaMobile: "?1",
            secChUaPlatform: "\"iOS\"",
            webglVendor: "WebKit",
            webglRenderer: "WebKit WebGL",
            webglUnmaskedVendor: "Apple Inc.",
            webglUnmaskedRenderer: "Apple GPU",
            audioSampleRate: 48_000,
            fonts: appleMobileFonts,
            renderSeed: seed
        )
    }

    private static func ipad(
        id: String,
        name: String,
        family: BrowsingPersona.DeviceFamily,
        ios: BrowsingPersona.IOSVersion,
        screen: (Int, Int),
        dpr: Double,
        hwConcurrency: Int,
        deviceMemory: Int,
        seed: UInt64
    ) -> BrowsingPersona {
        // Modern iPadOS Safari sends desktop-Safari UA by default — use desktop-class string.
        let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(ios.dotted) Safari/605.1.15"
        return BrowsingPersona(
            id: id,
            displayName: name,
            deviceFamily: family,
            iosVersion: ios,
            userAgent: ua,
            platform: "MacIntel",
            vendor: "Apple Computer, Inc.",
            appVersion: String(ua.dropFirst("Mozilla/".count)),
            hardwareConcurrency: hwConcurrency,
            deviceMemory: deviceMemory,
            maxTouchPoints: 5,
            isMobile: false,
            screenWidth: screen.0,
            screenHeight: screen.1,
            availWidth: screen.0,
            availHeight: screen.1,
            devicePixelRatio: dpr,
            colorDepth: 24,
            language: "en-US",
            languages: ["en-US", "en"],
            timezone: "America/Los_Angeles",
            acceptLanguageHeader: "en-US,en;q=0.9",
            secChUa: nil,
            secChUaMobile: "?0",
            secChUaPlatform: "\"macOS\"",
            webglVendor: "WebKit",
            webglRenderer: "WebKit WebGL",
            webglUnmaskedVendor: "Apple Inc.",
            webglUnmaskedRenderer: "Apple GPU",
            audioSampleRate: 48_000,
            fonts: applePadFonts,
            renderSeed: seed
        )
    }

    /// Real bundled font set on iPhone Safari (verified subset — keep tight).
    private static let appleMobileFonts: [String] = [
        "Arial", "Helvetica", "Helvetica Neue", "Times New Roman", "Times",
        "Courier", "Courier New", "Verdana", "Georgia", "Trebuchet MS",
        "Gill Sans", "Menlo", "Avenir", "Avenir Next", "Optima",
        "Palatino", "Snell Roundhand", "American Typewriter", "Marker Felt", "Zapfino"
    ]

    /// iPad font set (slightly larger due to desktop-class Safari).
    private static let applePadFonts: [String] = appleMobileFonts + [
        "Baskerville", "Bodoni 72", "Cochin", "Didot", "Futura",
        "Hoefler Text", "Iowan Old Style", "Papyrus", "Savoye LET"
    ]

    /// Pick a new persona different from the previous one.
    static func pickNext(excluding previousID: String?) -> BrowsingPersona {
        let pool = all.filter { $0.id != previousID }
        return pool.randomElement() ?? all[0]
    }
}
