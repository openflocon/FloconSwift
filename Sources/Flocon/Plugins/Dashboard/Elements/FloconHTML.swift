import Foundation

/// An HTML text, shown rendered.
public struct FloconHTML: FloconDashboardElementConvertible, Sendable {
    /// Name of the text.
    public let label: String
    /// The HTML text.
    public let value: String

    /// Creates an HTML text.
    ///
    /// - Parameters:
    ///   - label: Name of the text.
    ///   - value: The HTML text.
    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.html(label: label, value: value))]
    }
}
