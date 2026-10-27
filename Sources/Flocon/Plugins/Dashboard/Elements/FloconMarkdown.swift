import Foundation

/// A Markdown text, shown rendered.
public struct FloconMarkdown: FloconDashboardElementConvertible, Sendable {
    /// Name of the text.
    public let label: String
    /// The Markdown text.
    public let value: String

    /// Creates a Markdown text.
    ///
    /// - Parameters:
    ///   - label: Name of the text.
    ///   - value: The Markdown text.
    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.markdown(label: label, value: value))]
    }
}
