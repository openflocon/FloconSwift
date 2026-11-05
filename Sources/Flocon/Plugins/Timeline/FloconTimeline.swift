import Foundation

/// The type of a timeline event.
///
/// The reserved types are ``navigation``, ``userAction`` and ``lifecycle``: the desktop app shows
/// them with their own icon. Any other name is a custom type, for example `TimelineType("billing")`.
/// To reuse a custom type, declare it once:
///
/// ```swift
/// extension TimelineType {
///     static let billing = TimelineType("billing")
/// }
/// ```
public struct TimelineType: Sendable, Hashable {
    /// Name of the type, as sent to the desktop app.
    public let name: String

    /// Creates a type.
    ///
    /// - Parameter name: Name of the type. Reserved names are matched case-insensitively by the desktop app.
    public init(_ name: String) {
        self.name = name
    }

    /// A screen change.
    public static let navigation = TimelineType("navigation")
    /// An action of the user: a tap, a swipe, a form submission...
    public static let userAction = TimelineType("userAction")
    /// A lifecycle event of the app or of a screen.
    public static let lifecycle = TimelineType("lifecycle")
}

/// Severity of a tagged timeline event.
public enum TimelineLevel: String, Sendable, Hashable {
    case debug
    case info
    case warning
    case error
}
