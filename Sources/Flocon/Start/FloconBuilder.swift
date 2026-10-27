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

    /// Starts the SDK without connecting to the desktop app.
    ///
    /// Use it when the address of the desktop app is not known yet. What the app logs is kept in
    /// memory, then sent when you call ``Flocon/connect(to:)``.
    ///
    /// ```swift
    /// startFlocon { flocon in
    ///     flocon.connectLater()
    ///     flocon.install(.network)
    /// }
    /// // later
    /// try await Flocon.connect(to: URL(string: "ws://192.168.1.20:9023")!)
    /// ```
    ///
    /// - Parameter bufferCapacity: Number of messages kept while not connected. Above it, the oldest
    ///   are dropped. Defaults to `5000`.
    public mutating func connectLater(bufferCapacity: Int = 5_000) {
        config.connectsAutomatically = false
        config.bufferCapacity = bufferCapacity
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
