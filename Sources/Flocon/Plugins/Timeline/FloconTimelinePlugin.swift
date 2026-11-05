import Foundation

/// Sends timeline logs to the Flocon desktop app: navigation, user actions, lifecycle and your own events.
///
/// There are two kinds of calls, never mixed: the typed ones (``log(type:value:params:)`` and the
/// shortcuts) have no level, the tagged one (``log(tag:value:params:level:)``) has a level.
public final class FloconTimelinePlugin: FloconPlugin, @unchecked Sendable {
    static let name = "timeline"
    private static let methodLog = "log"

    public let pluginName = FloconTimelinePlugin.name
    private weak var sender: FloconMessageSender?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    /// Logs an event of the given type, without any level.
    ///
    /// - Parameters:
    ///   - type: Type of the event.
    ///   - value: Main text shown in the row, for example a screen name.
    ///   - params: Optional details, shown when the row is opened.
    public func log(type: TimelineType, value: String, params: [String: String] = [:]) {
        send(type: type.name, value: value, params: params, level: nil)
    }

    /// Logs a custom event: the tag is the type of the event, with a level.
    ///
    /// - Parameters:
    ///   - tag: Type of the event, for example `"billing"`.
    ///   - value: Main text shown in the row.
    ///   - params: Optional details, shown when the row is opened.
    ///   - level: Severity of the event.
    public func log(tag: String, value: String, params: [String: String] = [:], level: TimelineLevel = .info) {
        send(type: tag, value: value, params: params, level: level)
    }

    /// Logs a screen change.
    ///
    /// - Parameters:
    ///   - value: Name of the screen.
    ///   - params: Optional details.
    public func logNavigation(_ value: String, params: [String: String] = [:]) {
        log(type: .navigation, value: value, params: params)
    }

    /// Logs an action of the user.
    ///
    /// - Parameters:
    ///   - value: Name of the action.
    ///   - params: Optional details.
    public func logUserAction(_ value: String, params: [String: String] = [:]) {
        log(type: .userAction, value: value, params: params)
    }

    /// Logs a lifecycle event.
    ///
    /// - Parameters:
    ///   - value: Name of the event.
    ///   - params: Optional details.
    public func logLifecycle(_ value: String, params: [String: String] = [:]) {
        log(type: .lifecycle, value: value, params: params)
    }

    /// Nothing is kept: the events are sent when they are logged, then queued by the SDK.
    public func onConnectedToServer() {}

    /// The desktop app is read only: it sends nothing to this plugin.
    public func onMessageReceived(_ message: FloconMessageFromServer) {}

    private func send(type: String, value: String, params: [String: String], level: TimelineLevel?) {
        // the moment of the call, not the moment the message is sent
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let event = FloconTimelineEventRemote(
            type: type, value: value, params: params, level: level, timestamp: timestamp
        )
        sender?.send(plugin: pluginName, method: Self.methodLog, value: event)
    }
}
