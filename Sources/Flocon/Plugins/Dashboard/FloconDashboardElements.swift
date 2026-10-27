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
