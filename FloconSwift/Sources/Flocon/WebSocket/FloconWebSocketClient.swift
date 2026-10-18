import Foundation

/// Équivalent de l'interface commonMain FloconWebSocketClient.
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

/// Équivalent de buildFloconWebSocketClient() (expect/actual).
func buildFloconWebSocketClient() -> FloconWebSocketClient {
    FloconWebSocketClientImpl()
}
