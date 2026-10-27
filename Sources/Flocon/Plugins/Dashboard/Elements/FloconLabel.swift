import Foundation

/// A line of text, such as a title for the elements below it.
public struct FloconLabel: FloconDashboardElementConvertible, Sendable {
    /// The text.
    public let label: String
    /// Color of the text, as an ARGB integer such as `0xFFFF0000`, or `nil` for the default color.
    public let color: Int?

    /// Creates a label.
    ///
    /// - Parameters:
    ///   - label: The text.
    ///   - color: Color of the text, as an ARGB integer such as `0xFFFF0000`. Defaults to `nil`, the default color.
    public init(_ label: String, color: Int? = nil) {
        self.label = label
        self.color = color
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.label(label: label, color: color))]
    }
}
