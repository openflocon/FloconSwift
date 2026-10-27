import Foundation

/// A value with its label, for example `username: florent`.
public struct FloconText: FloconDashboardElementConvertible, Sendable {
    /// Name of the value.
    public let label: String
    /// The value.
    public let value: String
    /// Color of the value, as an ARGB integer such as `0xFFFF0000`, or `nil` for the default color.
    public let color: Int?

    /// Creates a text.
    ///
    /// - Parameters:
    ///   - label: Name of the value.
    ///   - value: The value.
    ///   - color: Color of the value, as an ARGB integer such as `0xFFFF0000`. Defaults to `nil`, the default color.
    public init(_ label: String, _ value: String, color: Int? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.text(label: label, value: value, color: color))]
    }
}
