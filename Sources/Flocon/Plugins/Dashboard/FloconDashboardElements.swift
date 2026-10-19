import Foundation

/// An element of a dashboard section or form, such as a text, a button or a check box.
///
/// Elements are created with the types that conform to ``FloconDashboardElementConvertible``,
/// such as ``FloconText`` or ``FloconButton``, inside a ``FloconSection`` or a ``FloconForm``.
public struct FloconDashboardElement: Sendable {
    enum Kind: Sendable {
        case text(label: String, value: String, color: Int?)
        case label(label: String, color: Int?)
        case button(text: String, id: String, onClick: @MainActor @Sendable () -> Void)
        case textField(id: String, label: String, placeholder: String?, value: String, onSubmitted: @MainActor @Sendable (String) -> Void)
        case checkBox(id: String, label: String, value: Bool, onUpdated: @MainActor @Sendable (Bool) -> Void)
        case plainText(label: String, value: String, type: String)
        case markdown(label: String, value: String)
        case html(label: String, value: String)
    }

    let kind: Kind

    init(_ kind: Kind) {
        self.kind = kind
    }
}

/// A value that can be shown as a ``FloconDashboardElement``.
///
/// Conform your own types to group several elements:
///
/// ```swift
/// struct UserRows: FloconDashboardElementConvertible {
///     let user: User
///     var dashboardElements: [FloconDashboardElement] {
///         FloconText("name", user.name).dashboardElements + FloconText("id", user.id).dashboardElements
///     }
/// }
/// ```
public protocol FloconDashboardElementConvertible {
    /// The elements shown in the dashboard.
    var dashboardElements: [FloconDashboardElement] { get }
}

extension FloconDashboardElement: FloconDashboardElementConvertible {
    public var dashboardElements: [FloconDashboardElement] { [self] }
}

/// Builds the elements of a ``FloconSection`` or a ``FloconForm``. Supports `if`, `switch` and `for`.
@resultBuilder
public enum FloconDashboardElementsBuilder {
    public static func buildExpression(_ expression: some FloconDashboardElementConvertible) -> [FloconDashboardElement] {
        expression.dashboardElements
    }

    public static func buildExpression(_ expression: [FloconDashboardElement]) -> [FloconDashboardElement] {
        expression
    }

    public static func buildBlock(_ components: [FloconDashboardElement]...) -> [FloconDashboardElement] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [FloconDashboardElement]?) -> [FloconDashboardElement] {
        component ?? []
    }

    public static func buildEither(first component: [FloconDashboardElement]) -> [FloconDashboardElement] {
        component
    }

    public static func buildEither(second component: [FloconDashboardElement]) -> [FloconDashboardElement] {
        component
    }

    public static func buildArray(_ components: [[FloconDashboardElement]]) -> [FloconDashboardElement] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [FloconDashboardElement]) -> [FloconDashboardElement] {
        component
    }
}

// MARK: - Elements

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
