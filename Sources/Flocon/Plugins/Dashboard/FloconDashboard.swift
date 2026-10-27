import Combine
import Foundation

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

extension FloconDashboardPlugin {
    /// Shows a dashboard in the Flocon desktop app: values of the app, and actions to run on it.
    ///
    /// ```swift
    /// final class DebugDashboard {
    ///     private var handle: FloconDashboardHandle?
    ///
    ///     func start(session: Session) {
    ///         handle = Flocon.dashboardPlugin.dashboard(id: "main") {
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
    ///
    /// - Parameters:
    ///   - id: Identifier of the dashboard, shown in the desktop app.
    ///   - content: The sections and forms of the dashboard.
    /// - Returns: A handle that keeps the dashboard up to date with its publishers.
    @discardableResult
    public func dashboard(id: String, @FloconDashboardBuilder _ content: () -> [FloconDashboardContent]) -> FloconDashboardHandle {
        startDashboard(id: id, contents: content()) { [self] config in
            register(config)
        }
    }
}
