import Foundation

/// WebSocket connection to the Flocon desktop app.
protocol FloconWebSocketClient: AnyObject {
    func connect(
        address: String,
        port: Int,
        onMessageReceived: @escaping @Sendable (String) -> Void,
        onClosed: @escaping @Sendable () -> Void
    ) async throws

    func sendPendingMessages() async
    func sendMessage(_ message: String) async -> Bool
    func disconnect() async
}

/// Creates the default WebSocket client, based on `URLSessionWebSocketTask`.
func buildFloconWebSocketClient() -> FloconWebSocketClient {
    FloconWebSocketClientImpl()
}
