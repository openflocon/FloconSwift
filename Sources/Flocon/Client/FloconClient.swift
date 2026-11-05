import Foundation

/// Owns the WebSocket connection and the plugins, sends messages to the desktop
/// and routes the incoming ones to the right plugin.
final class FloconClient: FloconMessageSender, FloconFileSender, @unchecked Sendable {
    private let config: FloconConfig
    // Start time of this app launch, lets the desktop group messages by session.
    private let appInstance = Int64(Date().timeIntervalSince1970 * 1000)

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
        case connected(FloconLink)
        case disconnected(FloconLink)
        case addLink(FloconLink)
        case removeLink(FloconLink)
    }

    /// Read once, on the main actor for `UIDevice`, and shared by the messages and the uploads.
    private let appInfos: Task<FloconAppInfos, Never>

    // Serial outbox: keeps messages in order (one Task per message would not).
    private let outbox: AsyncStream<OutboxItem>.Continuation
    private var outboxTask: Task<Void, Never>?

    private let deviceHandler = FloconDeviceHandler()

    private let pluginsLock = NSLock()
    private var plugins: [String: FloconPlugin] = [:]

    /// The connection to the default address of the desktop app, always tried.
    let defaultLink: FloconLink

    private let linkLock = NSLock()
    private var _extraLink: FloconLink?

    init(config: FloconConfig) {
        self.config = config
        let defaultURL = URL(string: "wss://\(config.host):\(config.webSocketPort)") ?? URL(string: "wss://localhost:9023")!
        self.defaultLink = FloconLink(url: defaultURL)
        var continuation: AsyncStream<OutboxItem>.Continuation!
        let stream = AsyncStream<OutboxItem> { continuation = $0 }
        self.outbox = continuation
        let appInfosTask = Task { await FloconAppInfos.current() }
        self.appInfos = appInfosTask
        let appInstance = appInstance
        let defaultLink = defaultLink
        let pending = FloconOutbox(capacity: config.bufferCapacity)
        deviceHandler.sender = self
        outbox.yield(.addLink(defaultLink))
        outboxTask = Task {
            // Read without blocking the thread that called Flocon.initialize():
            // messages sent in the meantime wait in the stream, in order.
            let appInfos = await appInfosTask.value
            for await item in stream {
                switch item {
                case .message(let message):
                    guard let json = Self.encode(message, appInfos: appInfos, appInstance: appInstance) else { continue }
                    await pending.enqueue(json)
                case .connected(let link):
                    // say hello to the desktop, before the messages kept while disconnected
                    let connectionType: FloconBonjourBody.ConnectionType = link === defaultLink ? .default : .wifi
                    guard let body = FloconBonjourBody(connectionType: connectionType).json() else { continue }
                    let hello = OutgoingMessage(plugin: "bonjour", method: "bonjour", body: .text(body))
                    guard let json = Self.encode(hello, appInfos: appInfos, appInstance: appInstance) else { continue }
                    await pending.connected(link.outboxLink, handshake: json)
                case .disconnected(let link):
                    await pending.disconnected(link.outboxLink)
                case .addLink(let link):
                    await pending.add(link.outboxLink)
                case .removeLink(let link):
                    await pending.remove(link.outboxLink)
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

    var timelinePlugin: FloconTimelinePlugin? {
        pluginsLock.lock(); defer { pluginsLock.unlock() }
        return plugins[FloconTimelinePlugin.name] as? FloconTimelinePlugin
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

    /// The connection to the address given with ``Flocon/connect(address:)``, in addition to the default one.
    var extraLink: FloconLink? {
        linkLock.lock(); defer { linkLock.unlock() }
        return _extraLink
    }

    /// Adds a connection to `url`, next to the default one.
    func addExtraLink(url: URL) -> FloconLink {
        let link = FloconLink(url: url)
        outbox.yield(.addLink(link))
        linkLock.lock(); defer { linkLock.unlock() }
        _extraLink = link
        return link
    }

    /// Closes and forgets `link`, which must be the extra one.
    func removeExtraLink(_ link: FloconLink) async {
        await disconnect(link)
        forgetExtraLink(link)
        outbox.yield(.removeLink(link))
    }

    private func forgetExtraLink(_ link: FloconLink) {
        linkLock.lock(); defer { linkLock.unlock() }
        if _extraLink === link { _extraLink = nil }
    }

    /// Connects `link`, then sends the handshake and the messages kept so far.
    ///
    /// - Parameter onClosed: Called when an established connection is lost.
    /// - Throws: An error if the connection cannot be opened.
    func connect(_ link: FloconLink, onClosed: @escaping @Sendable () -> Void) async throws {
        let outbox = outbox
        try await link.webSocketClient.connect(
            url: link.url,
            onMessageReceived: { [weak self] text in self?.onMessageReceived(text) },
            onClosed: {
                link.isConnected = false
                outbox.yield(.disconnected(link))
                onClosed()
            }
        )
        link.isConnected = true
        // before the plugins: what they send on connection comes after the handshake
        outbox.yield(.connected(link))
        allPlugins.forEach { $0.onConnectedToServer() }
    }

    func disconnect(_ link: FloconLink) async {
        link.isConnected = false
        await link.webSocketClient.disconnect()
        outbox.yield(.disconnected(link))
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
        if deviceHandler.handle(message) { return }
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
        let connected = [extraLink, defaultLink].compactMap { $0 }.first { $0.isConnected }
        let uploader = FloconFileUploader(host: (connected ?? defaultLink).url.host ?? config.host, port: config.httpPort)
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

/// The connection to one address of the desktop app, with its own WebSocket.
///
/// The messages are shared between the links, see ``FloconOutbox``.
final class FloconLink: @unchecked Sendable {
    let url: URL
    let id = UUID()
    let webSocketClient: FloconWebSocketClient = buildFloconWebSocketClient()
    let outboxLink: FloconOutbox.Link

    private let lock = NSLock()
    private var _isConnected = false
    private var _task: Task<Void, Never>?

    init(url: URL) {
        self.url = url
        let webSocketClient = webSocketClient
        self.outboxLink = FloconOutbox.Link { await webSocketClient.sendMessage($0) }
    }

    var isConnected: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isConnected }
        set { lock.lock(); _isConnected = newValue; lock.unlock() }
    }

    /// The task connecting, or retrying to connect, this link.
    var task: Task<Void, Never>? {
        get { lock.lock(); defer { lock.unlock() }; return _task }
        set { lock.lock(); _task = newValue; lock.unlock() }
    }
}
