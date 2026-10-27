import Foundation

/// A check box.
///
/// In a ``FloconSection``, the new value is sent to ``onUpdated`` each time it changes.
/// In a ``FloconForm``, it is one of the values sent with the form, as `"true"` or `"false"`.
public struct FloconCheckBox: FloconDashboardElementConvertible, Sendable {
    /// Identifier of the check box, unique in its dashboard. Key of the value in a form.
    public let id: String
    /// Name of the check box.
    public let label: String
    /// Whether the box is checked.
    public let value: Bool
    /// Called on the main actor with the new value, when changed in a section.
    public let onUpdated: @MainActor @Sendable (Bool) -> Void

    /// Creates a check box.
    ///
    /// - Parameters:
    ///   - id: Identifier of the check box, unique in its dashboard. Key of the value in a form.
    ///   - label: Name of the check box.
    ///   - value: Whether the box is checked.
    ///   - onUpdated: Called on the main actor with the new value, when changed in a section. Unused in a form.
    public init(
        id: String,
        label: String,
        value: Bool,
        onUpdated: @escaping @MainActor @Sendable (Bool) -> Void = { _ in }
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.onUpdated = onUpdated
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.checkBox(id: id, label: label, value: value, onUpdated: onUpdated))]
    }
}
