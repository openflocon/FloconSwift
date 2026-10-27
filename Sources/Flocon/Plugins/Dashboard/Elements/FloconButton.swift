import Foundation

/// A button that runs an action of the app when clicked in the desktop app.
public struct FloconButton: FloconDashboardElementConvertible, Sendable {
    /// Text of the button.
    public let text: String
    /// Identifier of the button, unique in its dashboard.
    public let id: String
    /// Called on the main actor when the button is clicked.
    public let onClick: @MainActor @Sendable () -> Void

    /// Creates a button.
    ///
    /// - Parameters:
    ///   - text: Text of the button.
    ///   - id: Identifier of the button, unique in its dashboard.
    ///   - onClick: Called on the main actor when the button is clicked.
    public init(_ text: String, id: String, onClick: @escaping @MainActor @Sendable () -> Void) {
        self.text = text
        self.id = id
        self.onClick = onClick
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.button(text: text, id: id, onClick: onClick))]
    }
}
