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
    /// Whether the SDK connects to ``host`` as soon as it starts.
    ///
    /// Set it to `false` when the address of the desktop app is not known yet: the messages are
    /// kept in memory until ``Flocon/connect(to:)`` is called.
    public var connectsAutomatically: Bool
    /// Number of messages kept in memory while the SDK is not connected.
    ///
    /// Above it, the oldest messages are dropped.
    public var bufferCapacity: Int

    /// Version of the SDK, reported to the desktop app.
    public static let sdkVersion = "0.3.0"

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - host: Host name or IP address of the Mac running Flocon. Defaults to `localhost`.
    ///   - webSocketPort: Port of the desktop WebSocket server. Defaults to `9023`.
    ///   - httpPort: Port of the desktop HTTP server. Defaults to `9024`.
    ///   - isCrashReporterEnabled: Whether the crashes are reported to the desktop app. Defaults to `true`.
    ///   - connectsAutomatically: Whether to connect to `host` on start. Defaults to `true`.
    ///   - bufferCapacity: Number of messages kept while not connected. Defaults to `5000`.
    public init(
        host: String = "localhost",
        webSocketPort: Int = 9023,
        httpPort: Int = 9024,
        isCrashReporterEnabled: Bool = true,
        connectsAutomatically: Bool = true,
        bufferCapacity: Int = 5_000
    ) {
        self.host = host
        self.webSocketPort = webSocketPort
        self.httpPort = httpPort
        self.isCrashReporterEnabled = isCrashReporterEnabled
        self.connectsAutomatically = connectsAutomatically
        self.bufferCapacity = bufferCapacity
    }
}

/// Entry point of the Flocon SDK.
///
/// Call ``startFlocon(_:)`` once, as early as possible in the app lifecycle, to choose the plugins:
///
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         startFlocon { flocon in
///             flocon.install(.network)
///             flocon.install(.analytics)
///         }
///     }
///     // ...
/// }
/// ```
///
/// ``initialize(config:)`` is the short form, which installs every plugin.
///
/// The SDK then connects to the Flocon desktop app in the background and keeps retrying
/// until it is reachable. Messages sent before the connection is up are queued.
///
/// If the address of the desktop app is only known later, start the SDK with
/// ``FloconBuilder/connectLater(bufferCapacity:)`` and call ``connect(to:)`` when you have it.
public final class Flocon: @unchecked Sendable {
    /// The shared SDK instance.
    public static let shared = Flocon()

    /// Starts the SDK and connects to the Flocon desktop app.
    ///
    /// Calling this method more than once has no effect. It can be called from any thread.
    ///
    /// - Parameter config: Where to find the desktop app. Defaults to `localhost`.
    public static func initialize(config: FloconConfig = FloconConfig()) {
        shared.initializeFlocon(config: config, features: nil)
    }

    /// Connects to the desktop app at the given address.
    ///
    /// Opens the WebSocket, introduces the app to the desktop, then sends everything that was
    /// logged since the start, in the order it was logged, and sends the next messages right away.
    /// If the connection is lost later, the messages are kept again and sent on reconnection,
    /// which is retried every 3 seconds.
    ///
    /// Use it when the SDK was started with ``FloconBuilder/connectLater(bufferCapacity:)``, or to
    /// point a started SDK to another address. Does nothing before the SDK is started.
    ///
    /// ```swift
    /// try await Flocon.connect(to: URL(string: "ws://192.168.1.20:9023")!)
    /// ```
    ///
    /// - Parameter url: The WebSocket address of the desktop app, such as `ws://192.168.1.20:9023`.
    /// - Throws: The error of the connection attempt. The messages are kept, and can be sent by
    ///   calling this method again.
    public static func connect(to url: URL) async throws {
        try await shared.connectClient(to: url)
    }

    /// The current state of the connection to the desktop app.
    public static var connectionState: FloconConnectionState {
        shared.connectionStateStore.state
    }

    /// The states of the connection: the current one first, then each change.
    public static var connectionStates: AsyncStream<FloconConnectionState> {
        shared.connectionStateStore.stream
    }

    /// Registers a custom plugin.
    ///
    /// The built-in plugins (network, analytics, feature flags, tables, preferences, files, databases, dashboards, deeplinks, crash reporter, device) are registered by
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
    let connectionStateStore = FloconConnectionStateStore()

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

    /// - Parameter features: The plugins to register, or `nil` for all of them.
    /// - Returns: `false` if the SDK was already initialized, and nothing was done.
    @discardableResult
    func initializeFlocon(config: FloconConfig, features: Set<FloconFeatureKind>?) -> Bool {
        lock.lock()
        if _isInitialized {
            lock.unlock()
            return false
        }
        let features = features ?? Set(FloconFeatureKind.allCases)
        let newClient = FloconClient(config: config)
        if features.contains(.network) { newClient.register(plugin: FloconNetworkPlugin(sender: newClient)) }
        if features.contains(.analytics) { newClient.register(plugin: FloconAnalyticsPlugin(sender: newClient)) }
        if features.contains(.featureFlags) { newClient.register(plugin: FloconFeatureFlagsPlugin(sender: newClient)) }
        if features.contains(.tables) { newClient.register(plugin: FloconTablePlugin(sender: newClient)) }
        newClient.register(plugin: FloconDevicePlugin(sender: newClient))
        if features.contains(.preferences) { newClient.register(plugin: FloconPreferencesPlugin(sender: newClient)) }
        if features.contains(.files) {
            newClient.register(plugin: FloconFilesPlugin(sender: newClient, fileSender: newClient))
        }
        if features.contains(.database) { newClient.register(plugin: FloconDatabasePlugin(sender: newClient)) }
        if features.contains(.dashboard) { newClient.register(plugin: FloconDashboardPlugin(sender: newClient)) }
        if features.contains(.deeplinks) { newClient.register(plugin: FloconDeeplinksPlugin(sender: newClient)) }
        if features.contains(.crashReporter) {
            let crashReporter = FloconCrashReporterPlugin(sender: newClient)
            newClient.register(plugin: crashReporter)
            // before connecting: it also prepares the crash of the previous launch, sent on connection
            if config.isCrashReporterEnabled {
                crashReporter.installCrashHandlers()
            }
        }
        _client = newClient
        _isInitialized = true
        if config.connectsAutomatically {
            connectionStateStore.set(.connecting)
            _connectTask = Task { [weak self] in
                await self?.start(client: newClient)
            }
        } else {
            connectionStateStore.set(.buffering)
        }
        lock.unlock()
        return true
    }

    /// Stops the retries to the previous address. `nil` if the SDK is not started.
    private func cancelConnectTask() -> FloconClient? {
        lock.lock(); defer { lock.unlock() }
        _connectTask?.cancel()
        _connectTask = nil
        return _client
    }

    func connectClient(to url: URL) async throws {
        guard let client = cancelConnectTask() else {
            FloconLogger.log("connect(to:) ignored: the SDK is not started")
            return
        }
        client.setServer(url: url)
        await client.disconnect()
        connectionStateStore.set(.connecting)
        do {
            try await client.connect(onClosed: { [weak self] in
                self?.restartConnection(client: client)
            })
            connectionStateStore.set(.connected)
        } catch {
            FloconLogger.logError("Cannot connect to \(url)", error)
            connectionStateStore.set(.failed(error.localizedDescription))
            throw error
        }
    }

    /// Called from the WebSocket's `onClosed` callback, on another thread, hence the lock.
    private func restartConnection(client: FloconClient) {
        // connection lost: the messages are kept until the next connection
        connectionStateStore.set(.buffering)
        lock.lock(); defer { lock.unlock() }
        _connectTask = Task { [weak self] in
            await self?.start(client: client)
        }
    }

    /// Connects to the desktop app, retrying every 3 seconds until it succeeds.
    private func start(client: FloconClient) async {
        while !Task.isCancelled {
            do {
                connectionStateStore.set(.connecting)
                // once connected, the client says hello to the desktop and sends the queued messages
                try await client.connect(onClosed: { [weak self] in
                    // connection lost: start connecting again
                    self?.restartConnection(client: client)
                })
                connectionStateStore.set(.connected)
                return
            } catch {
                connectionStateStore.set(.failed(error.localizedDescription))
                FloconLogger.logError("Cannot connect, retrying in 3s", error)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
}
