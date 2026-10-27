import Foundation

/// Sends analytics events to the Flocon desktop app.
///
/// Log events with ``FloconAnalyticsPlugin/sender(_:)`` rather than calling this plugin directly.
public final class FloconAnalyticsPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "Analytics"
    private static let methodAddItems = "AddItems"

    public let pluginName = FloconAnalyticsPlugin.name
    private weak var sender: FloconMessageSender?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    public func onConnectedToServer() {}

    /// The desktop app sends nothing to this plugin.
    public func onMessageReceived(_ message: FloconMessageFromServer) {}

    /// Sends analytics items to the desktop app, in a single message.
    ///
    /// - Parameter items: The items to send. Nothing is sent if empty.
    public func registerAnalytics(_ items: [FloconAnalyticsItem]) {
        guard !items.isEmpty else { return }
        let models = items.compactMap { item -> FloconAnalyticsItemRemote? in
            return FloconAnalyticsItemRemote(
                id: UUID().uuidString,
                analyticsTableId: item.streamName,
                eventName: item.eventName,
                createdAt: Int64(item.createdAt.timeIntervalSince1970 * 1000),
                properties: item.properties.map { .init(name: $0.name, value: $0.value) }
            )
        }

        // the desktop expects a JSON array of items, encoded off the calling thread
        sender?.send(plugin: pluginName, method: Self.methodAddItems, value: models)
    }
}

extension FloconAnalyticsPlugin {
    /// Returns a logger bound to an analytics stream, so the stream name is not repeated at each call.
    ///
    /// ```swift
    /// Flocon.analyticsPlugin.sender("firebase").logEvents(AnalyticsEvent(eventName: "app_opened"))
    /// ```
    ///
    /// - Parameter streamName: Name of the stream, shown as a table in the desktop app.
    /// - Returns: A logger for that stream.
    public func sender(_ streamName: String) -> FloconAnalytics {
        FloconAnalytics(plugin: self, streamName: streamName)
    }
}
