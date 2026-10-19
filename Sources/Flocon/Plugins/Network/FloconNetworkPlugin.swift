import Foundation

/// Sends the network calls and WebSocket events of the app to the Flocon desktop app.
///
/// The calls made with `URLSession` are logged by the SDK. Use this plugin to log the calls of
/// other clients, such as a gRPC or a custom socket client:
///
/// ```swift
/// let call = FloconNetworkCallRequest(
///     networkType: "http",
///     request: FloconNetworkRequest(url: "https://api.example.com/users", method: "GET")
/// )
/// Flocon.shared.networkPlugin?.logRequest(call)
/// // later
/// Flocon.shared.networkPlugin?.logResponse(
///     FloconNetworkCallResponse(
///         callId: call.callId,
///         networkType: "http",
///         durationMs: 120,
///         response: FloconNetworkResponse(httpCode: 200, body: #"{"users": []}"#)
///     )
/// )
/// ```
public final class FloconNetworkPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "network"
    private static let methodLogRequest = "logNetworkCallRequest"
    private static let methodLogResponse = "logNetworkCallResponse"

    public let pluginName = FloconNetworkPlugin.name
    private weak var sender: FloconMessageSender?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    public func onConnectedToServer() {}

    public func onMessageReceived(_ message: FloconMessageFromServer) {
        // TODO: network mocks and bad network simulation, configured from the desktop
    }

    /// Logs the request of a call. Log its response with ``logResponse(_:)``, using the same `callId`.
    ///
    /// - Parameter call: The request.
    public func logRequest(_ call: FloconNetworkCallRequest) {
        send(FloconNetworkCallRequestRemote(call), method: Self.methodLogRequest)
    }

    /// Logs the response of a call whose request was logged with ``logRequest(_:)``.
    ///
    /// - Parameter call: The response, with the `callId` of its request.
    public func logResponse(_ call: FloconNetworkCallResponse) {
        send(FloconNetworkCallResponseRemote(call), method: Self.methodLogResponse)
    }

    func send<T: Encodable>(_ value: T, method: String) {
        guard
            let data = try? JSONEncoder().encode(value),
            let json = String(data: data, encoding: .utf8)
        else { return }
        sender?.send(plugin: pluginName, method: method, body: json)
    }
}
