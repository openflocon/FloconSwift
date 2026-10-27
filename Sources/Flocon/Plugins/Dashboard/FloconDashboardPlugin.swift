import Foundation

/// Sends the dashboards of the app to the Flocon desktop app, and runs their actions.
///
/// Create dashboards with ``Flocon.dashboardPlugin.dashboard(id:_:)`` rather than calling this plugin directly.
/// The last state of each dashboard is sent again on each connection.
public final class FloconDashboardPlugin: FloconPlugin, @unchecked Sendable {
    /// Name of the messages received from the desktop.
    static let name = "Dashboard"
    /// Name of the messages sent to the desktop, lowercased unlike ``name``.
    private static let remotePluginName = "dashboard"
    private static let methodUpdate = "update"

    private static let methodOnClick = "onClick"
    private static let methodOnFormSubmitted = "onFormSubmitted"
    private static let methodOnTextFieldSubmitted = "onTextFieldSubmitted"
    private static let methodOnCheckBoxValueChanged = "onCheckBoxValueChanged"

    public let pluginName = FloconDashboardPlugin.name
    private weak var sender: FloconMessageSender?

    private let lock = NSLock()
    private var dashboards: [String: FloconDashboardConfig] = [:]
    private var callbacks: [String: DashboardCallback] = [:]

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    /// Sends a dashboard, replacing the one with the same identifier.
    func register(_ config: FloconDashboardConfig) {
        let (remote, newCallbacks) = DashboardRemote.make(config)
        lock.lock()
        dashboards[config.id] = config
        callbacks.merge(newCallbacks) { _, new in new }
        lock.unlock()
        send(remote)
    }

    public func onConnectedToServer() {
        lock.lock()
        let configs = Array(dashboards.values)
        lock.unlock()
        configs.forEach { send(DashboardRemote.make($0).remote) }
    }

    /// Runs the action of a button, text field, check box or form, on the main actor.
    public func onMessageReceived(_ message: FloconMessageFromServer) {
        let data = Data(message.body.utf8)
        let decoder = JSONDecoder()
        do {
            switch message.method {
            case Self.methodOnClick:
                if case .button(let action) = callback(id: message.body) {
                    Task { @MainActor in action() }
                }
            case Self.methodOnTextFieldSubmitted:
                let event = try decoder.decode(DashboardTextFieldSubmittedRemote.self, from: data)
                if case .textField(let action) = callback(id: event.id) {
                    Task { @MainActor in action(event.value) }
                }
            case Self.methodOnCheckBoxValueChanged:
                let event = try decoder.decode(DashboardCheckBoxValueChangedRemote.self, from: data)
                if case .checkBox(let action) = callback(id: event.id) {
                    Task { @MainActor in action(event.value) }
                }
            case Self.methodOnFormSubmitted:
                let event = try decoder.decode(DashboardFormSubmittedRemote.self, from: data)
                if case .form(let dashboardId, let action) = callback(id: event.id) {
                    // gives back the identifiers of the app: "<dashboardId>_name" -> "name"
                    let prefix = DashboardRemote.actionId(dashboardId: dashboardId, elementId: "")
                    let values = Dictionary(
                        event.values.map { key, value in
                            (key.hasPrefix(prefix) ? String(key.dropFirst(prefix.count)) : key, value)
                        },
                        uniquingKeysWith: { _, last in last }
                    )
                    Task { @MainActor in action(values) }
                }
            default:
                FloconLogger.log("Unknown dashboard method: \(message.method)")
            }
        } catch {
            FloconLogger.logError("Dashboard message parsing error", error)
        }
    }

    private func callback(id: String) -> DashboardCallback? {
        lock.lock(); defer { lock.unlock() }
        return callbacks[id]
    }

    /// Encoded off the calling thread.
    private func send(_ remote: DashboardRemote) {
        sender?.send(plugin: Self.remotePluginName, method: Self.methodUpdate, value: remote)
    }
}
