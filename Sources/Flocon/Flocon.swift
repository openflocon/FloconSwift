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
    /// Number of messages kept in memory while the SDK is not connected.
    ///
    /// Above it, the oldest messages are dropped.
    public var bufferCapacity: Int
    /// The IP address of another computer to also try when the SDK starts, next to ``host``.
    ///
    /// For example a computer with a fixed IP. No port nor scheme: the port is ``webSocketPort``.
    public var additionalAddress: String?
    /// Whether the last address the SDK connected to with ``Flocon/connect(address:)`` is kept in the
    /// `UserDefaults` of the app, and tried again at the next launch, next to ``host``.
    ///
    /// It wins over ``additionalAddress``. Defaults to `true`.
    public var rememberLastAddress: Bool

    /// Version of the SDK, reported to the desktop app.
    public static let sdkVersion = "0.3.0"

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - host: Host name or IP address of the Mac running Flocon. Defaults to `localhost`.
    ///   - webSocketPort: Port of the desktop WebSocket server. Defaults to `9023`.
    ///   - httpPort: Port of the desktop HTTP server. Defaults to `9024`.
    ///   - isCrashReporterEnabled: Whether the crashes are reported to the desktop app. Defaults to `true`.
    ///   - bufferCapacity: Number of messages kept while not connected. Defaults to `5000`.
    ///   - additionalAddress: The IP address of another computer to also try on start. Defaults to `nil`.
    ///   - rememberLastAddress: Whether the last address connected to is tried again at the next launch. Defaults to `true`.
    public init(
        host: String = "localhost",
        webSocketPort: Int = 9023,
        httpPort: Int = 9024,
        isCrashReporterEnabled: Bool = true,
        bufferCapacity: Int = 5_000,
        additionalAddress: String? = nil,
        rememberLastAddress: Bool = true
    ) {
        self.host = host
        self.webSocketPort = webSocketPort
        self.httpPort = httpPort
        self.isCrashReporterEnabled = isCrashReporterEnabled
        self.bufferCapacity = bufferCapacity
        self.additionalAddress = additionalAddress
        self.rememberLastAddress = rememberLastAddress
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
/// If the address of the desktop app is only known later, for example on a physical device,
/// call ``connect(address:)`` when you have it: the SDK keeps trying its default address and
/// also connects to this one.
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

    /// Connects to the desktop app at the given address, in addition to the default one.
    ///
    /// The SDK always keeps trying its default address (`localhost` on the simulator), so this is
    /// meant for what it cannot guess, such as the IP of the Mac from a physical device, typically
    /// typed in a debug menu. Opens the WebSocket, introduces the app to the desktop, then sends
    /// everything that was logged and not sent yet, in the order it was logged, and sends the next
    /// messages right away. If the connection is lost later, the messages are kept again and sent on
    /// reconnection, which is retried every 3 seconds. Calling it again replaces the address.
    ///
    /// The last address that worked is kept and tried again at the next launch, see
    /// ``FloconConfig/rememberLastAddress``.
    ///
    /// ```swift
    /// let result = await Flocon.connect(address: "192.168.1.20")
    /// ```
    ///
    /// - Parameter address: The IP address (or host) of the Mac running Flocon Desktop, such as
    ///   `192.168.1.20`. No port nor scheme: the port is always ``FloconConfig/webSocketPort`` (`9023`),
    ///   anything else is ``FloconConnectResult/invalidAddress(_:)``.
    /// - Returns: ``FloconConnectResult/connected``, or why it could not connect. The messages are
    ///   kept in every case, call it again to retry.
    @discardableResult
    public static func connect(address: String) async -> FloconConnectResult {
        guard let connections = shared.connections else { return .notStarted }
        return await connections.connect(address: address)
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
    private var _connections: FloconConnections?
    let connectionStateStore = FloconConnectionStateStore()

    private init() {}

    var client: FloconClient? {
        lock.lock(); defer { lock.unlock() }
        return _client
    }

    var connections: FloconConnections? {
        lock.lock(); defer { lock.unlock() }
        return _connections
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
        let newConnections = FloconConnections(
            client: newClient,
            states: connectionStateStore,
            config: config,
            addressStore: config.rememberLastAddress ? FloconUserDefaultsAddressStore() : nil
        )
        _connections = newConnections
        newConnections.start()
        lock.unlock()
        return true
    }
}
