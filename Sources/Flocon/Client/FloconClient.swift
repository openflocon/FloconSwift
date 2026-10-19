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
        let body: String
    }

    // Serial outbox: keeps messages in order (one Task per message would not).
    private let outbox: AsyncStream<OutgoingMessage>.Continuation
    private var outboxTask: Task<Void, Never>?

    private let pluginsLock = NSLock()
    private var plugins: [String: FloconPlugin] = [:]

    init(config: FloconConfig) {
        self.config = config
        var continuation: AsyncStream<OutgoingMessage>.Continuation!
        let stream = AsyncStream<OutgoingMessage> { continuation = $0 }
        self.outbox = continuation
        let ws = webSocketClient
        let appInstance = appInstance
        outboxTask = Task {
            // Read once, without blocking the thread that called Flocon.initialize():
            // messages sent in the meantime wait in the stream, in order.
            let appInfos = await FloconAppInfos.current()
            for await message in stream {
                guard let json = Self.encode(message, appInfos: appInfos, appInstance: appInstance) else { continue }
                _ = await ws.sendMessage(json)
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

    /// Connects to the desktop app.
    ///
    /// - Parameter onClosed: Called when an established connection is lost.
    /// - Throws: An error if the connection cannot be opened.
    func connect(onClosed: @escaping @Sendable () -> Void) async throws {
        try await webSocketClient.connect(
            address: config.host,
            port: config.webSocketPort,
            onMessageReceived: { [weak self] text in self?.onMessageReceived(text) },
            onClosed: onClosed
        )
        allPlugins.forEach { $0.onConnectedToServer() }
    }

    func disconnect() async {
        await webSocketClient.disconnect()
    }

    func sendPendingMessages() {
        let ws = webSocketClient
        Task { await ws.sendPendingMessages() }
    }

    // MARK: Receiving

    private func onMessageReceived(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let message = try? JSONDecoder().decode(FloconMessageFromServer.self, from: data)
        else {
            FloconLogger.log("Unreadable message from the desktop: \(text)")
            return
        }
        pluginsLock.lock()
        let plugin = plugins[message.plugin]
        pluginsLock.unlock()
        plugin?.onMessageReceived(message)
    }

    // MARK: Sending (FloconMessageSender)

    func send(plugin: String, method: String, body: String) {
        outbox.yield(OutgoingMessage(plugin: plugin, method: method, body: body))
    }

    // MARK: Sending files (FloconFileSender)

    func sendFile(at fileURL: URL, remotePath: String, requestId: String) async {
        let appInfos = await FloconAppInfos.current()
        let uploader = FloconFileUploader(host: config.host, port: config.httpPort)
        await uploader.upload(
            fileAt: fileURL,
            remotePath: remotePath,
            requestId: requestId,
            identity: .init(deviceId: appInfos.deviceId, appPackageName: appInfos.appPackageName, appInstance: appInstance)
        )
    }

    private static func encode(_ message: OutgoingMessage, appInfos: FloconAppInfos, appInstance: Int64) -> String? {
        let envelope = FloconMessageToServer(
            deviceId: appInfos.deviceId,
            plugin: message.plugin,
            body: message.body,
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
