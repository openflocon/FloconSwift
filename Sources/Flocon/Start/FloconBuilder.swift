import Foundation

/// Collects the configuration and the plugins installed in ``startFlocon(_:)``.
public struct FloconBuilder {
    var config = FloconConfig()
    var features: Set<FloconFeatureKind> = [.device]
    var applications: [() -> Void] = []

    /// Sets where to find the Flocon desktop app.
    ///
    /// The defaults work from the iOS Simulator. On a physical device, use the local IP address of the Mac.
    ///
    /// - Parameters:
    ///   - host: Host name or IP address of the Mac running Flocon. Defaults to `localhost`.
    ///   - webSocketPort: Port of the desktop WebSocket server. Defaults to `9023`.
    ///   - httpPort: Port of the desktop HTTP server. Defaults to `9024`.
    public mutating func config(host: String = "localhost", webSocketPort: Int = 9023, httpPort: Int = 9024) {
        config.host = host
        config.webSocketPort = webSocketPort
        config.httpPort = httpPort
    }

    /// Sets the options of the connection to the desktop app.
    ///
    /// The SDK always tries ``FloconConfig/host`` (`localhost` by default, which works from the
    /// simulator). Use it when the address of the Mac can only be known later or is fixed:
    /// what the app logs is kept in memory until a desktop is reachable.
    ///
    /// ```swift
    /// startFlocon { flocon in
    ///     flocon.connect {
    ///         $0.address = "192.168.1.20" // also tried at start, next to localhost
    ///     }
    ///     flocon.install(.network)
    /// }
    /// // later, from a debug menu for example
    /// await Flocon.connect(address: "192.168.1.20")
    /// ```
    ///
    /// - Parameter configure: Edits the options, see ``FloconConnectOptions``.
    public mutating func connect(_ configure: (inout FloconConnectOptions) -> Void = { _ in }) {
        var options = FloconConnectOptions()
        configure(&options)
        config.bufferCapacity = options.bufferCapacity
        config.additionalAddress = options.address
        config.rememberLastAddress = options.rememberLastAddress
    }

    /// Installs a plugin with its default options.
    ///
    /// - Parameter feature: The plugin, such as ``FloconFeature/analytics``.
    public mutating func install<Options>(_ feature: FloconFeature<Options>) {
        install(feature) { _ in }
    }

    /// Installs a plugin and configures it.
    ///
    /// - Parameters:
    ///   - feature: The plugin, such as ``FloconFeature/database``.
    ///   - configure: Edits the options of the plugin. It is applied once the SDK is started.
    public mutating func install<Options>(
        _ feature: FloconFeature<Options>,
        _ configure: (inout Options) -> Void
    ) {
        var options = feature.makeOptions()
        configure(&options)
        features.insert(feature.kind)
        let apply = feature.apply
        applications.append { apply(options) }
    }
}

/// Options of ``FloconBuilder/connect(_:)``.
public struct FloconConnectOptions: Sendable {
    /// Number of messages kept while not connected. Above it, the oldest are dropped. Defaults to `5000`.
    public var bufferCapacity = 5_000

    /// The IP address of a computer to also try when the SDK starts, for example one with a fixed IP.
    /// No port nor scheme: the port is always `9023`.
    public var address: String?

    /// Keeps the last address the SDK connected to (given as ``address`` or to ``Flocon/connect(address:)``)
    /// in the `UserDefaults` of the app, and tries it again at the next launch. It wins over ``address``.
    /// Defaults to `true`.
    public var rememberLastAddress = true
}
