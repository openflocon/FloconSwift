import Combine
import Foundation

/// A section or a form of a dashboard, at a given time.
struct FloconDashboardContainer: Sendable {
    enum Kind: Sendable {
        case section
        case form(submitText: String, onSubmitted: @MainActor @Sendable ([String: String]) -> Void)
    }

    let name: String
    let elements: [FloconDashboardElement]
    let kind: Kind
}

/// A dashboard, at a given time.
struct FloconDashboardConfig: Sendable {
    let id: String
    let containers: [FloconDashboardContainer]
}
