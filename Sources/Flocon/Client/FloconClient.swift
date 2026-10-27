import Foundation

/// Owns the WebSocket connection and the plugins, sends messages to the desktop
/// and routes the incoming ones to the right plugin.
final class FloconClient: FloconMessageSender, FloconFileSender, @unchecked Sendable {
    private let config: FloconConfig
    // Start time of this app launch, lets the desktop group messages by session.
    private let appInstance = Int64(Date().timeIntervalSince1970 * 1000)

    private let webSocketClient: FloconWebSocketClient = buildFloconWebSocketClient()

    /// A message waiting for its envelope, which needs the app infos read on the main actor.
    private struct OutgoingMessage: Sendable {
        let plugin: String
        let method: String
        let body: Body
    }

    private enum Body: Sendable {
        case text(String)
        /// Encoded by the outbox task, off the thread that sent it.
        case value(any Encodable & Sendable)
    }

    /// What the outbox task handles, in order: the connection changes go through the same
    /// stream as the messages, so they are never reordered with them.
    private enum OutboxItem: Sendable {
        case message(OutgoingMessage)
        case connected
        case disconnected
    }

    /// Read once, on the main actor for `UIDevice`, and shared by the messages and the uploads.
    private let appInfos: Task<FloconAppInfos, Never>

    // Serial outbox: keeps messages in order (one Task per message would not).
    private let outbox: AsyncStream<OutboxItem>.Continuation
    private var outboxTask: Task<Void, Never>?

    private let pluginsLock = NSLock()
    private var plugins: [String: FloconPlugin] = [:]

    private let serverLock = NSLock()
    private var _serverURL: URL?

    init(config: FloconConfig) {
        self.config = config
        _serverURL = config.connectsAutomatically ? URL(string: "ws://\(config.host):\(config.webSocketPort)") : nil
        var continuation: AsyncStream<OutboxItem>.Continuation!
        let stream = AsyncStream<OutboxItem> { continuation = $0 }
        self.outbox = continuation
        let appInfosTask = Task { await FloconAppInfos.current() }
        self.appInfos = appInfosTask
        let ws = webSocketClient
        let appInstance = appInstance
        let pending = FloconOutbox(capacity: config.bufferCapacity) { await ws.sendMessage($0) }
        outboxTask = Task {
            // Read without blocking the thread that called Flocon.initialize():
            // messages sent in the meantime wait in the stream, in order.
            let appInfos = await appInfosTask.value
            for await item in stream {
                switch item {
                case .message(let message):
                    guard let json = Self.encode(message, appInfos: appInfos, appInstance: appInstance) else { continue }
                    await pending.enqueue(json)
                case .connected:
                    // say hello to the desktop, before the messages kept while disconnected
                    let hello = OutgoingMessage(plugin: "bonjour", method: "bonjour", body: .text("bonjour"))
                    guard let json = Self.encode(hello, appInfos: appInfos, appInstance: appInstance) else { continue }
                    await pending.connected(handshake: json)
                case .disconnected:
                    await pending.disconnected()
                }
            }
        }
    }

    deinit {
        outbox.finish()
        outboxTask?.cancel()
    }

    // MARK: Plugins

    func register(plugin: FloconPlugin) {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        plugins[plugin.pluginName] = plugin
    }

    private var allPlugins: [FloconPlugin] {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return Array(plugins.values)
    }

    var networkPlugin: FloconNetworkPlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconNetworkPlugin.name] as? FloconNetworkPlugin
    }

    var analyticsPlugin: FloconAnalyticsPlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconAnalyticsPlugin.name] as? FloconAnalyticsPlugin
    }

    var featureFlagsPlugin: FloconFeatureFlagsPlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconFeatureFlagsPlugin.name] as? FloconFeatureFlagsPlugin
    }

    var tablePlugin: FloconTablePlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconTablePlugin.name] as? FloconTablePlugin
    }

    var deeplinksPlugin: FloconDeeplinksPlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconDeeplinksPlugin.name] as? FloconDeeplinksPlugin
    }

    var filesPlugin: FloconFilesPlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconFilesPlugin.name] as? FloconFilesPlugin
    }

    var databasePlugin: FloconDatabasePlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconDatabasePlugin.name] as? FloconDatabasePlugin
    }

    var dashboardPlugin: FloconDashboardPlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconDashboardPlugin.name] as? FloconDashboardPlugin
    }

    var preferencesPlugin: FloconPreferencesPlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconPreferencesPlugin.name] as? FloconPreferencesPlugin
    }

    // MARK: Connection

    /// Address of the desktop WebSocket server, `nil` until it is known.
    var serverURL: URL? {
        serverLock.lock(); defer { serverLock.unlock() }
        return _serverURL
    }

    func setServer(url: URL) {
        serverLock.lock(); defer { serverLock.unlock() }
        _serverURL = url
    }

    /// Connects to ``serverURL``, then sends the handshake and the messages kept so far.
    ///
    /// - Parameter onClosed: Called when an established connection is lost.
    /// - Throws: An error if the connection cannot be opened.
    func connect(onClosed: @escaping @Sendable () -> Void) async throws {
        guard let url = serverURL else { throw URLError(.badURL) }
        let outbox = outbox
        try await webSocketClient.connect(
            url: url,
            onMessageReceived: { [weak self] text in self?.onMessageReceived(text) },
            onClosed: {
                outbox.yield(.disconnected)
                onClosed()
            }
        )
        // before the plugins: what they send on connection comes after the handshake
        outbox.yield(.connected)
        allPlugins.forEach { $0.onConnectedToServer() }
    }

    func disconnect() async {
        await webSocketClient.disconnect()
        outbox.yield(.disconnected)
    }

    // MARK: Receiving

    private func onMessageReceived(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let message = try? JSONDecoder().decode(FloconMessageFromServer.self, from: data)
        else {
            FloconLogger.log(payload: text, "Unreadable message from the desktop:")
            return
        }
        pluginsLock.lock()
        let plugin = plugins[message.plugin]
        pluginsLock.unlock()
        plugin?.onMessageReceived(message)
    }

    // MARK: Sending (FloconMessageSender)

    func send(plugin: String, method: String, body: String) {
        outbox.yield(.message(OutgoingMessage(plugin: plugin, method: method, body: .text(body))))
    }

    func send<T: Encodable & Sendable>(plugin: String, method: String, value: T) {
        outbox.yield(.message(OutgoingMessage(plugin: plugin, method: method, body: .value(value))))
    }

    // MARK: Sending files (FloconFileSender)

    func sendFile(at fileURL: URL, remotePath: String, requestId: String) async {
        let appInfos = await self.appInfos.value
        let uploader = FloconFileUploader(host: serverURL?.host ?? config.host, port: config.httpPort)
        await uploader.upload(
            fileAt: fileURL,
            remotePath: remotePath,
            requestId: requestId,
            identity: .init(deviceId: appInfos.deviceId, appPackageName: appInfos.appPackageName, appInstance: appInstance)
        )
    }

    private static func encode(_ message: OutgoingMessage, appInfos: FloconAppInfos, appInstance: Int64) -> String? {
        let body: String
        switch message.body {
        case .text(let text):
            body = text
        case .value(let value):
            guard let encoded = FloconMessageEncoder.encode(value, plugin: message.plugin) else { return nil }
            body = encoded
        }
        let envelope = FloconMessageToServer(
            deviceId: appInfos.deviceId,
            plugin: message.plugin,
            body: body,
            appName: appInfos.appName,
            appPackageName: appInfos.appPackageName,
            method: message.method,
            deviceName: appInfos.deviceName,
            appInstance: appInstance,
            platform: appInfos.platform,
            versionName: FloconConfig.sdkVersion
        )
        guard let data = try? JSONEncoder().encode(envelope) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
