import Foundation

/// A JSON document, shown formatted.
public struct FloconJSON: FloconDashboardElementConvertible, Sendable {
    /// Name of the document.
    public let label: String
    /// The JSON text.
    public let value: String

    /// Creates a JSON document.
    ///
    /// - Parameters:
    ///   - label: Name of the document.
    ///   - value: The JSON text.
    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.plainText(label: label, value: value, type: "json"))]
    }
}
