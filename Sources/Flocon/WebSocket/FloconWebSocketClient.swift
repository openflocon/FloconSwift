import Foundation

/// WebSocket connection to the Flocon desktop app.
protocol FloconWebSocketClient: AnyObject, Sendable {
    func connect(
        url: URL,
        onMessageReceived: @escaping @Sendable (String) -> Void,
        onClosed: @escaping @Sendable () -> Void
    ) async throws

    /// - Returns: `false` if the message could not be sent, for example when not connected.
    func sendMessage(_ message: String) async -> Bool
    func disconnect() async
}

/// Creates the default WebSocket client, based on `URLSessionWebSocketTask`.
func buildFloconWebSocketClient() -> FloconWebSocketClient {
    FloconWebSocketClientImpl()
}
