import Combine
import Foundation

/// A section or a form of a dashboard, at a given time.
struct FloconDashboardContainer: Sendable {
    enum Kind: Sendable {
        case section
        case form(submitText: String, onSubmitted: @MainActor @Sendable ([String: String]) -> Void)
    }

    let name: String
    let elements: [FloconDashboardElement]
    let kind: Kind
}

/// A dashboard, at a given time.
struct FloconDashboardConfig: Sendable {
    let id: String
    let containers: [FloconDashboardContainer]
}

/// A section or a form of a dashboard, which can update over time.
///
/// Created by ``FloconSection`` and ``FloconForm``, inside ``floconDashboard(id:_:)``.
public struct FloconDashboardContent {
    let publisher: AnyPublisher<FloconDashboardContainer, Never>
}

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

/// A group of inputs sent together to the app, with a submit button.
///
/// The values are keyed by the identifiers of the ``FloconTextField`` and ``FloconCheckBox``
/// of the form. Check boxes are sent as `"true"` or `"false"`:
///
/// ```swift
/// FloconForm("Create user", submitText: "Create", onSubmitted: { values in
///     createUser(name: values["name"] ?? "", isAdmin: values["admin"] == "true")
/// }) {
///     FloconTextField(id: "name", label: "Name", value: "")
///     FloconCheckBox(id: "admin", label: "Admin", value: false)
/// }
/// ```
public struct FloconForm {
    let content: FloconDashboardContent

    /// Creates a static form.
    ///
    /// - Parameters:
    ///   - name: Title of the form, unique in its dashboard.
    ///   - submitText: Text of the submit button. Defaults to `"Submit"`.
    ///   - onSubmitted: Called on the main actor with the values of the form, keyed by input identifier.
    ///   - content: The inputs of the form.
    public init(
        _ name: String,
        submitText: String = "Submit",
        onSubmitted: @escaping @MainActor @Sendable ([String: String]) -> Void,
        @FloconDashboardElementsBuilder content: () -> [FloconDashboardElement]
    ) {
        let container = FloconDashboardContainer(
            name: name,
            elements: content(),
            kind: .form(submitText: submitText, onSubmitted: onSubmitted)
        )
        self.content = FloconDashboardContent(publisher: Just(container).eraseToAnyPublisher())
    }

    /// Creates a form rebuilt each time the publisher emits.
    ///
    /// - Parameters:
    ///   - name: Title of the form, unique in its dashboard.
    ///   - submitText: Text of the submit button. Defaults to `"Submit"`.
    ///   - publisher: The data shown by the form, such as a `@Published` property or a `CurrentValueSubject`.
    ///   - onSubmitted: Called on the main actor with the values of the form, keyed by input identifier.
    ///   - content: Builds the inputs of the form from the latest value. Called on the thread the publisher emits on.
    public init<P: Publisher>(
        _ name: String,
        submitText: String = "Submit",
        publisher: P,
        onSubmitted: @escaping @MainActor @Sendable ([String: String]) -> Void,
        @FloconDashboardElementsBuilder content: @escaping (P.Output) -> [FloconDashboardElement]
    ) where P.Failure == Never {
        self.content = FloconDashboardContent(
            publisher: publisher
                .map {
                    FloconDashboardContainer(
                        name: name,
                        elements: content($0),
                        kind: .form(submitText: submitText, onSubmitted: onSubmitted)
                    )
                }
                .eraseToAnyPublisher()
        )
    }
}

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

/// Keeps a dashboard up to date with its publishers.
///
/// The dashboard stops updating when ``cancel()`` is called or when the handle is released:
/// keep it as long as the dashboard should follow the data of the app. A dashboard made
/// of static sections only does not need it.
public final class FloconDashboardHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var cancellable: AnyCancellable?

    init(_ cancellable: AnyCancellable?) {
        self.cancellable = cancellable
    }

    /// Stops updating the dashboard. The desktop app keeps showing its last state.
    public func cancel() {
        lock.lock()
        let cancellable = cancellable
        self.cancellable = nil
        lock.unlock()
        cancellable?.cancel()
    }
}

/// Shows a dashboard in the Flocon desktop app: values of the app, and actions to run on it.
///
/// ```swift
/// final class DebugDashboard {
///     private var handle: FloconDashboardHandle?
///
///     func start(session: Session) {
///         handle = floconDashboard(id: "main") {
///             FloconSection("User", publisher: session.$user) { user in
///                 FloconText("name", user.name)
///                 FloconTextField(id: "name", label: "Rename", value: user.name) { session.rename($0) }
///                 FloconButton("Log out", id: "logout") { session.logOut() }
///             }
///             FloconSection("Build") {
///                 FloconText("version", Bundle.main.version)
///             }
///         }
///     }
/// }
/// ```
///
/// The dashboard is sent again each time a publisher emits, and on each connection.
/// Registering a dashboard with the same identifier replaces the previous one.
/// It can be called before ``Flocon/initialize(config:)``: the dashboard is sent from the next update.
///
/// - Parameters:
///   - id: Identifier of the dashboard, shown in the desktop app.
///   - content: The sections and forms of the dashboard.
/// - Returns: A handle that keeps the dashboard up to date with its publishers.
@discardableResult
public func floconDashboard(id: String, @FloconDashboardBuilder _ content: () -> [FloconDashboardContent]) -> FloconDashboardHandle {
    startDashboard(id: id, contents: content()) { config in
        Flocon.shared.client?.dashboardPlugin?.register(config)
    }
}

extension Flocon {
    /// Shows a dashboard in the Flocon desktop app.
    ///
    /// See ``floconDashboard(id:_:)``.
    ///
    /// - Parameters:
    ///   - id: Identifier of the dashboard, shown in the desktop app.
    ///   - content: The sections and forms of the dashboard.
    /// - Returns: A handle that keeps the dashboard up to date with its publishers.
    @discardableResult
    public static func dashboard(id: String, @FloconDashboardBuilder _ content: () -> [FloconDashboardContent]) -> FloconDashboardHandle {
        floconDashboard(id: id, content)
    }
}

/// Combines the latest value of each container, like `combine` on Android: nothing is sent
/// until every container has a value.
func startDashboard(
    id: String,
    contents: [FloconDashboardContent],
    register: @escaping (FloconDashboardConfig) -> Void
) -> FloconDashboardHandle {
    guard !contents.isEmpty else {
        register(FloconDashboardConfig(id: id, containers: []))
        return FloconDashboardHandle(nil)
    }
    let indexed = contents.enumerated().map { index, content in
        content.publisher.map { (index, $0) }
    }
    let initial = [FloconDashboardContainer?](repeating: nil, count: contents.count)
    // MergeMany delivers the values one at a time, so the dashboards are sent in order
    let cancellable = Publishers.MergeMany(indexed)
        .scan(initial) { latest, update in
            var latest = latest
            latest[update.0] = update.1
            return latest
        }
        .compactMap { latest -> FloconDashboardConfig? in
            let containers = latest.compactMap { $0 }
            guard containers.count == latest.count else { return nil }
            return FloconDashboardConfig(id: id, containers: containers)
        }
        .sink(receiveValue: register)
    return FloconDashboardHandle(cancellable)
}
