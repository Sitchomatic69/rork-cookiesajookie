import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

enum ProfilePalette {
    static let colors: [String] = [
        "#14B8A6", // teal
        "#EC4899", // pink
        "#A855F7", // purple
        "#F59E0B", // amber
        "#22C55E", // green
        "#3B82F6", // blue
        "#EF4444", // red
        "#06B6D4", // cyan
        "#F97316", // orange
        "#8B5CF6", // violet
    ]

    static let icons: [String] = [
        "person.crop.circle.fill",
        "globe",
        "bolt.fill",
        "flame.fill",
        "leaf.fill",
        "star.fill",
        "heart.fill",
        "moon.stars.fill",
        "sparkles",
        "gamecontroller.fill",
        "cart.fill",
        "briefcase.fill",
        "graduationcap.fill",
        "music.note",
        "camera.fill",
    ]
}
