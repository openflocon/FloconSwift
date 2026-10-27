import Foundation

/// A long text, shown in a block that can be copied.
public struct FloconPlainText: FloconDashboardElementConvertible, Sendable {
    /// Name of the text.
    public let label: String
    /// The text.
    public let value: String

    /// Creates a plain text.
    ///
    /// - Parameters:
    ///   - label: Name of the text.
    ///   - value: The text.
    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.plainText(label: label, value: value, type: "text"))]
    }
}
