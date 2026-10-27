import Foundation

/// Sends analytics events to the Flocon desktop app.
///
/// Log events with ``floconAnalytics(_:)`` rather than calling this plugin directly.
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
