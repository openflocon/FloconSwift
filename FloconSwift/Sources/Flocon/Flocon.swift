import Foundation

/// Équivalent de getServerHost(context) + des constantes de port de FloconClientImpl.
public struct FloconConfig: Sendable {
    /// "localhost" fonctionne depuis le simulateur iOS.
    /// Sur un vrai iPhone, mets l'IP locale de ton Mac (ex: "192.168.1.20").
    public var host: String
    public var webSocketPort: Int
    public var httpPort: Int // pas encore utilisé : envoi de fichiers (FloconFileSender) pas porté

    public static let sdkVersion = "0.1.0"

    public init(host: String = "localhost", webSocketPort: Int = 9023, httpPort: Int = 9024) {
        self.host = host
        self.webSocketPort = webSocketPort
        self.httpPort = httpPort
    }
}

/// Équivalent de FloconApp + FloconCore + object Flocon.
/// Usage : `Flocon.initialize()`
public final class Flocon: @unchecked Sendable {
    public static let shared = Flocon()

    /// Point d'entrée, comme Flocon.initialize(context) sur Android.
    public static func initialize(config: FloconConfig = FloconConfig()) {
        shared.initializeFlocon(config: config)
    }

    /// Enregistrer un plugin (réseau, base de données, etc.) une fois qu'ils seront portés.
    public static func register(plugin: FloconPlugin) {
        shared.client?.register(plugin: plugin)
    }

    private let lock = NSLock()
    private var _client: FloconClient?
    private var _isInitialized = false
    private var _connectTask: Task<Void, Never>?

    private init() {}

    var client: FloconClient? {
        lock.lock(); defer { lock.unlock() }
        return _client
    }

    public var isInitialized: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isInitialized
    }

    // MARK: FloconCore

    private func initializeFlocon(config: FloconConfig) {
        lock.lock()
        if _isInitialized {
            lock.unlock()
            return
        }
        let newClient = FloconClient(config: config)
        newClient.register(plugin: FloconNetworkPlugin(sender: newClient))
        newClient.register(plugin: FloconAnalyticsPlugin(sender: newClient))
        newClient.register(plugin: FloconTablePlugin(sender: newClient))
        newClient.register(plugin: FloconDevicePlugin(sender: newClient))
        _client = newClient
        _isInitialized = true
        _connectTask = Task { [weak self] in
            await self?.start(client: newClient)
        }
        lock.unlock()

        // TODO: équivalent de crashReporterPlugin.setupCrashHandler()
        // (NSSetUncaughtExceptionHandler + signal handlers), à brancher quand le plugin sera porté.
    }

    /// Le callback onClosed arrive depuis le WebSocket, sur un autre thread : on passe par le verrou.
    private func restartConnection(client: FloconClient) {
        lock.lock(); defer { lock.unlock() }
        _connectTask = Task { [weak self] in
            await self?.start(client: client)
        }
    }

    /// Essaie de se connecter ; en cas d'échec, réessaie dans 3 s (comme FloconCore.start).
    private func start(client: FloconClient) async {
        while !Task.isCancelled {
            do {
                try await client.connect(onClosed: { [weak self] in
                    // connexion perdue : on relance la boucle de connexion
                    self?.restartConnection(client: client)
                })
                // succès : on dit bonjour au desktop, puis on vide les messages en attente
                client.send(plugin: "bonjour", method: "bonjour", body: "bonjour")
                client.sendPendingMessages()
                return
            } catch {
                FloconLogger.logError("Connexion impossible, nouvel essai dans 3s", error)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
}
