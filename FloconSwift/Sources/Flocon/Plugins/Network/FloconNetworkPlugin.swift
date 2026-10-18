import Foundation

// MARK: - Plugin

/// Équivalent de FloconNetworkPlugin côté Android (partie « log » uniquement).
/// Mocks et « bad network quality » ne sont pas portés.
final class FloconNetworkPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "network"
    // Protocol.FromDevice.Network côté Kotlin
    private static let methodLogRequest = "logNetworkCallRequest"
    private static let methodLogResponse = "logNetworkCallResponse"

    let pluginName = FloconNetworkPlugin.name
    private weak var sender: FloconMessageSender?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    func onConnectedToServer() {}

    func onMessageReceived(_ message: FloconMessageFromServer) {
        // TODO: mocks, bad network quality (messages envoyés par le desktop)
    }

    func logRequest(_ call: FloconNetworkCallRequestRemote) {
        send(call, method: Self.methodLogRequest)
    }

    func logResponse(_ call: FloconNetworkCallResponseRemote) {
        send(call, method: Self.methodLogResponse)
    }

    func send<T: Encodable>(_ value: T, method: String) {
        guard
            let data = try? JSONEncoder().encode(value),
            let json = String(data: data, encoding: .utf8)
        else { return }
        sender?.send(plugin: pluginName, method: method, body: json)
    }
}
