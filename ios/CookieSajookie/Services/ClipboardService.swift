import Foundation
import UIKit

@MainActor
enum ClipboardService {
    static func readString() -> String? {
        UIPasteboard.general.string
    }

    static func writeString(_ value: String) {
        UIPasteboard.general.string = value
    }
}
