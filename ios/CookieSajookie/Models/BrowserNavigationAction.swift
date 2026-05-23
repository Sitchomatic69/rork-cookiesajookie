import Foundation

nonisolated enum BrowserNavigationAction: Sendable {
    case none
    case back
    case forward
    case reload
    case stop
}
