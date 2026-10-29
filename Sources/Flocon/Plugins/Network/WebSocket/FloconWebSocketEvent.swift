import Foundation

/// An event of a WebSocket connection, shown with the network calls in the Flocon desktop app.
///
/// See ``FloconNetworkPlugin/logWebSocketEvent(_:)``.
public struct FloconWebSocketEvent: Sendable {
    /// Kind of WebSocket event.
    public enum Event: Sendable {
        /// The connection is closed.
        case closed
        /// The connection is closing.
        case closing
        /// The connection failed.
        case error
        /// The app received a message.
        case receiveMessage
        /// The app sent a message.
        case sendMessage
        /// The connection is open.
        case open
    }

    /// URL of the WebSocket.
    public let websocketUrl: String
    /// Kind of event.
    public let event: Event
    /// Size of the message, in bytes.
    public let size: Int64
    /// Content of the message, if any.
    public let message: String?
    /// Description of the error, if any.
    public let error: String?
    /// When the event happened.
    public let timestamp: Date

    /// Creates a WebSocket event.
    ///
    /// - Parameters:
    ///   - websocketUrl: URL of the WebSocket.
    ///   - event: Kind of event.
    ///   - size: Size of the message, in bytes. Defaults to the UTF-8 size of `message`,
    ///     or `0` without a message.
    ///   - message: Content of the message, if any.
    ///   - error: The error, for an ``Event/error`` event.
    ///   - timestamp: When the event happened. Defaults to now.
    public init(
        websocketUrl: String,
        event: Event,
        size: Int64? = nil,
        message: String? = nil,
        error: Error? = nil,
        timestamp: Date = Date()
    ) {
        self.websocketUrl = websocketUrl
        self.event = event
        self.size = size ?? Int64(message?.utf8.count ?? 0)
        self.message = message
        self.error = error?.localizedDescription
        self.timestamp = timestamp
    }
}

// MARK: - Sending

extension FloconNetworkPlugin {
    private static let methodLogWebSocketEvent = "log_websocket_event"

    /// Logs an event of a WebSocket connection. See ``FloconNetworkPlugin/logWebSocketEvent(_:)``.
    ///
    /// - Parameter event: The event.
    public func logWebSocketEvent(_ event: FloconWebSocketEvent) {
        let model = FloconWebSocketEventRemote(
            id: UUID().uuidString,
            event: {
                switch event.event {
                case .closed: return "closed"
                case .closing: return "closing"
                case .error: return "error"
                case .receiveMessage: return "received"
                case .sendMessage: return "sent"
                case .open: return "open"
                }
            }(),
            url: event.websocketUrl,
            size: event.size,
            timestamp: Int64(event.timestamp.timeIntervalSince1970 * 1000),
            message: event.message,
            error: event.error
        )
        send(model, method: Self.methodLogWebSocketEvent)
    }
}
