import Foundation

/// A text input.
///
/// In a ``FloconSection``, the text is sent to ``onSubmitted`` when submitted.
/// In a ``FloconForm``, it is one of the values sent with the form.
public struct FloconTextField: FloconDashboardElementConvertible, Sendable {
    /// Identifier of the input, unique in its dashboard. Key of the value in a form.
    public let id: String
    /// Name of the input.
    public let label: String
    /// Text shown while the input is empty.
    public let placeholder: String?
    /// Initial text of the input.
    public let value: String
    /// Called on the main actor with the text, when submitted in a section.
    public let onSubmitted: @MainActor @Sendable (String) -> Void

    /// Creates a text input.
    ///
    /// - Parameters:
    ///   - id: Identifier of the input, unique in its dashboard. Key of the value in a form.
    ///   - label: Name of the input.
    ///   - placeholder: Text shown while the input is empty. Defaults to `nil`.
    ///   - value: Initial text of the input.
    ///   - onSubmitted: Called on the main actor with the text, when submitted in a section. Unused in a form.
    public init(
        id: String,
        label: String,
        placeholder: String? = nil,
        value: String,
        onSubmitted: @escaping @MainActor @Sendable (String) -> Void = { _ in }
    ) {
        self.id = id
        self.label = label
        self.placeholder = placeholder
        self.value = value
        self.onSubmitted = onSubmitted
    }

    public var dashboardElements: [FloconDashboardElement] {
        [FloconDashboardElement(.textField(id: id, label: label, placeholder: placeholder, value: value, onSubmitted: onSubmitted))]
    }
}
