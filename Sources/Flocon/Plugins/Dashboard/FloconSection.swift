import Combine
import Foundation

/// A group of elements in a dashboard.
///
/// A section is either static, or rebuilt each time a publisher emits:
///
/// ```swift
/// FloconSection("User", publisher: $user) { user in
///     FloconText("name", user.name)
///     FloconButton("Log out", id: "logout") { session.logOut() }
/// }
/// ```
public struct FloconSection {
    let content: FloconDashboardContent

    /// Creates a static section.
    ///
    /// - Parameters:
    ///   - name: Title of the section.
    ///   - content: The elements of the section.
    public init(_ name: String, @FloconDashboardElementsBuilder content: () -> [FloconDashboardElement]) {
        let container = FloconDashboardContainer(name: name, elements: content(), kind: .section)
        self.content = FloconDashboardContent(publisher: Just(container).eraseToAnyPublisher())
    }

    /// Creates a section rebuilt each time the publisher emits.
    ///
    /// The dashboard is sent once every reactive section and form of it has received a value.
    ///
    /// - Parameters:
    ///   - name: Title of the section.
    ///   - publisher: The data shown by the section, such as a `@Published` property (`$user`) or a `CurrentValueSubject`.
    ///   - content: Builds the elements of the section from the latest value. Called on the thread the publisher emits on.
    public init<P: Publisher>(
        _ name: String,
        publisher: P,
        @FloconDashboardElementsBuilder content: @escaping (P.Output) -> [FloconDashboardElement]
    ) where P.Failure == Never {
        self.content = FloconDashboardContent(
            publisher: publisher
                .map { FloconDashboardContainer(name: name, elements: content($0), kind: .section) }
                .eraseToAnyPublisher()
        )
    }
}
