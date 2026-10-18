import Foundation

// MARK: - API publique (même forme que floconLogWebSocketEvent côté Android)

/// Équivalent de FloconWebSocketEvent (flocon-base/.../network/model/FloconWebSocketEvent.kt).
public struct FloconWebSocketEvent: Sendable {
    public enum Event: Sendable {
        case closed
        case closing
        case error
        /// Message entrant (reçu par l'app).
        case receiveMessage
        /// Message sortant (envoyé par l'app).
        case sendMessage
        case open
    }

    public let websocketUrl: String
    public let event: Event
    /// Taille du message en octets. Par défaut : taille UTF-8 de `message` (0 sans message).
    public let size: Int64
    public let message: String?
    public let error: String?
    public let timestamp: Date

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

/// Mode manuel : à appeler à chaque trame envoyée / reçue.
/// (Le WebSocket de URLSession n'est pas observable par un URLProtocol.)
public func floconLogWebSocketEvent(_ event: FloconWebSocketEvent) {
    Flocon.shared.client?.networkPlugin?.logWebSocketEvent(event)
}

extension Flocon {
    public static func logWebSocketEvent(_ event: FloconWebSocketEvent) {
        floconLogWebSocketEvent(event)
    }
}

// MARK: - Envoi

extension FloconNetworkPlugin {
    private static let methodLogWebSocketEvent = "logWebSocketEvent"

    func logWebSocketEvent(_ event: FloconWebSocketEvent) {
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
