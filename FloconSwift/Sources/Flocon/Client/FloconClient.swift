import Foundation

/// Équivalent de FloconClientImpl : possède le websocket, les plugins,
/// et sait envoyer / dispatcher les messages.
final class FloconClient: FloconMessageSender, @unchecked Sendable {
    private let config: FloconConfig
    // Timestamp de démarrage du SDK pour ce lancement (appInstance côté Android).
    private let appInstance = Int64(Date().timeIntervalSince1970 * 1000)

    private let webSocketClient: FloconWebSocketClient = buildFloconWebSocketClient()

    /// Message pas encore emballé : l'enveloppe a besoin des FloconAppInfos, lues sur le main actor.
    private struct OutgoingMessage: Sendable {
        let plugin: String
        let method: String
        let body: String
    }

    // File d'envoi sérielle : garde l'ordre des messages (un Task par message ne le garantirait pas).
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
            // Lu une seule fois, sans bloquer le thread qui a appelé Flocon.initialize() :
            // les messages envoyés d'ici là attendent dans le stream, dans l'ordre.
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

    // MARK: Connexion

    /// Équivalent de connect(onClosed:). Lance une erreur si la connexion échoue.
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

    // MARK: Réception

    private func onMessageReceived(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let message = try? JSONDecoder().decode(FloconMessageFromServer.self, from: data)
        else {
            FloconLogger.log("Message serveur illisible : \(text)")
            return
        }
        pluginsLock.lock()
        let plugin = plugins[message.plugin]
        pluginsLock.unlock()
        plugin?.onMessageReceived(message)
    }

    // MARK: Envoi (FloconMessageSender)

    func send(plugin: String, method: String, body: String) {
        outbox.yield(OutgoingMessage(plugin: plugin, method: method, body: body))
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
