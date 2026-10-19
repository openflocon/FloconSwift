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
///
/// The mocks and the bad network simulation set in the desktop app apply to the calls made
/// with `URLSession`. They are saved, and apply from the next launch too.
public final class FloconNetworkPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "network"
    private static let methodLogRequest = "logNetworkCallRequest"
    private static let methodLogResponse = "logNetworkCallResponse"
    private static let methodSetupMocks = "setupMocks"
    private static let methodSetupBadNetworkConfig = "setupBadNetworkConfig"

    public let pluginName = FloconNetworkPlugin.name
    private weak var sender: FloconMessageSender?
    private let store: FloconNetworkStore

    private let lock = NSLock()
    private var _mocks: [FloconNetworkMock]
    private var _badNetworkConfig: FloconBadNetworkConfig?

    init(sender: FloconMessageSender, store: FloconNetworkStore = .app) {
        self.sender = sender
        self.store = store
        _mocks = store.mocksJSON.map(FloconNetworkMockRemote.parse) ?? []
        _badNetworkConfig = store.badNetworkConfigJSON.flatMap(FloconBadNetworkConfigRemote.parse)
    }

    /// The mocks set in the desktop app.
    public var mocks: [FloconNetworkMock] {
        lock.lock(); defer { lock.unlock() }
        return _mocks
    }

    /// The bad network simulation set in the desktop app, or `nil` when it is disabled.
    public var badNetworkConfig: FloconBadNetworkConfig? {
        lock.lock(); defer { lock.unlock() }
        return _badNetworkConfig
    }

    /// The first mock matching a request, if any.
    func mock(url: String, method: String) -> FloconNetworkMock? {
        mocks.first { $0.expectation.matches(url: url, method: method) }
    }

    public func onConnectedToServer() {}

    public func onMessageReceived(_ message: FloconMessageFromServer) {
        switch message.method {
        case Self.methodSetupMocks:
            let mocks = FloconNetworkMockRemote.parse(message.body)
            lock.lock(); _mocks = mocks; lock.unlock()
            store.mocksJSON = message.body
        case Self.methodSetupBadNetworkConfig:
            let config = FloconBadNetworkConfigRemote.parse(message.body)
            lock.lock(); _badNetworkConfig = config; lock.unlock()
            store.badNetworkConfigJSON = config == nil ? nil : message.body
        default:
            break
        }
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
