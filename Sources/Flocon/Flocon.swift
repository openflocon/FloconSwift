import Foundation

/// Where the SDK finds the Flocon desktop app.
///
/// The defaults work from the iOS Simulator, which shares the network of the Mac.
/// On a physical device, use the local IP address of the Mac running Flocon:
///
/// ```swift
/// Flocon.initialize(config: FloconConfig(host: "192.168.1.20"))
/// ```
public struct FloconConfig: Sendable {
    /// Host name or IP address of the Mac running the Flocon desktop app.
    public var host: String
    /// Port of the desktop WebSocket server.
    public var webSocketPort: Int
    /// Port of the desktop HTTP server, used to send the files downloaded from the desktop app.
    public var httpPort: Int
    /// Whether the crashes of the app are reported to the desktop app, on the next launch.
    ///
    /// The crash handlers keep the handlers already installed, by another crash reporter for
    /// example, and call them. Turn this off if you prefer the SDK not to install any handler.
    public var isCrashReporterEnabled: Bool

    /// Version of the SDK, reported to the desktop app.
    public static let sdkVersion = "0.3.0"

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - host: Host name or IP address of the Mac running Flocon. Defaults to `localhost`.
    ///   - webSocketPort: Port of the desktop WebSocket server. Defaults to `9023`.
    ///   - httpPort: Port of the desktop HTTP server. Defaults to `9024`.
    ///   - isCrashReporterEnabled: Whether the crashes are reported to the desktop app. Defaults to `true`.
    public init(
        host: String = "localhost",
        webSocketPort: Int = 9023,
        httpPort: Int = 9024,
        isCrashReporterEnabled: Bool = true
    ) {
        self.host = host
        self.webSocketPort = webSocketPort
        self.httpPort = httpPort
        self.isCrashReporterEnabled = isCrashReporterEnabled
    }
}

/// Entry point of the Flocon SDK.
///
/// Call ``initialize(config:)`` once, as early as possible in the app lifecycle:
///
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         Flocon.initialize()
///     }
///     // ...
/// }
/// ```
///
/// The SDK then connects to the Flocon desktop app in the background and keeps retrying
/// until it is reachable. Messages sent before the connection is up are queued.
public final class Flocon: @unchecked Sendable {
    /// The shared SDK instance.
    public static let shared = Flocon()

    /// Starts the SDK and connects to the Flocon desktop app.
    ///
    /// Calling this method more than once has no effect. It can be called from any thread.
    ///
    /// - Parameter config: Where to find the desktop app. Defaults to `localhost`.
    public static func initialize(config: FloconConfig = FloconConfig()) {
        shared.initializeFlocon(config: config)
    }

    /// Registers a custom plugin.
    ///
    /// The built-in plugins (network, analytics, tables, preferences, files, databases, dashboards, deeplinks, crash reporter, device) are registered by
    /// ``initialize(config:)``. Registering a plugin with the same ``FloconPlugin/pluginName``
    /// replaces the previous one. Has no effect before ``initialize(config:)``.
    ///
    /// - Parameter plugin: The plugin that receives the desktop messages addressed to it.
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

    /// Whether ``initialize(config:)`` has been called.
    public var isInitialized: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isInitialized
    }

    // MARK: Connection

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
        newClient.register(plugin: FloconPreferencesPlugin(sender: newClient))
        newClient.register(plugin: FloconFilesPlugin(sender: newClient, fileSender: newClient))
        newClient.register(plugin: FloconDatabasePlugin(sender: newClient))
        newClient.register(plugin: FloconDashboardPlugin(sender: newClient))
        newClient.register(plugin: FloconDeeplinksPlugin(sender: newClient))
        let crashReporter = FloconCrashReporterPlugin(sender: newClient)
        newClient.register(plugin: crashReporter)
        // before connecting: it also prepares the crash of the previous launch, sent on connection
        if config.isCrashReporterEnabled {
            crashReporter.installCrashHandlers()
        }
        _client = newClient
        _isInitialized = true
        _connectTask = Task { [weak self] in
            await self?.start(client: newClient)
        }
        lock.unlock()

    }

    /// Called from the WebSocket's `onClosed` callback, on another thread, hence the lock.
    private func restartConnection(client: FloconClient) {
        lock.lock(); defer { lock.unlock() }
        _connectTask = Task { [weak self] in
            await self?.start(client: client)
        }
    }

    /// Connects to the desktop app, retrying every 3 seconds until it succeeds.
    private func start(client: FloconClient) async {
        while !Task.isCancelled {
            do {
                try await client.connect(onClosed: { [weak self] in
                    // connection lost: start connecting again
                    self?.restartConnection(client: client)
                })
                // connected: say hello to the desktop, then flush the queued messages
                client.send(plugin: "bonjour", method: "bonjour", body: "bonjour")
                client.sendPendingMessages()
                return
            } catch {
                FloconLogger.logError("Cannot connect, retrying in 3s", error)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
}
