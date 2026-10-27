import Combine
import Foundation

/// Builds the sections and forms of a dashboard. Supports `if`, `switch` and `for`.
@resultBuilder
public enum FloconDashboardBuilder {
    public static func buildExpression(_ expression: FloconSection) -> [FloconDashboardContent] {
        [expression.content]
    }

    public static func buildExpression(_ expression: FloconForm) -> [FloconDashboardContent] {
        [expression.content]
    }

    public static func buildBlock(_ components: [FloconDashboardContent]...) -> [FloconDashboardContent] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [FloconDashboardContent]?) -> [FloconDashboardContent] {
        component ?? []
    }

    public static func buildEither(first component: [FloconDashboardContent]) -> [FloconDashboardContent] {
        component
    }

    public static func buildEither(second component: [FloconDashboardContent]) -> [FloconDashboardContent] {
        component
    }

    public static func buildArray(_ components: [[FloconDashboardContent]]) -> [FloconDashboardContent] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [FloconDashboardContent]) -> [FloconDashboardContent] {
        component
    }
}
