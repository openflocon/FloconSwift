import Foundation

// MARK: - Entry point

/// Starts the SDK, installing and configuring the plugins you need.
///
/// Call it once, as early as possible in the app lifecycle. Only the installed plugins are
/// registered: the accessor of a plugin that is not installed, such as
/// ``Flocon/analyticsPlugin``, stays `nil`.
///
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         startFlocon { flocon in
///             flocon.config(host: "192.168.1.20") // physical device only
///             flocon.install(.network)
///             flocon.install(.database) { $0.register(displayName: "App", url: databaseURL) }
///             flocon.install(.analytics)
///         }
///     }
///     // ...
/// }
/// ```
///
/// Calling it more than once, or after ``Flocon/initialize(config:)``, has no effect.
///
/// - Parameter configure: Installs the plugins. Runs synchronously, before the function returns.
public func startFlocon(_ configure: (inout FloconBuilder) -> Void) {
    Flocon.start(configure)
}

extension Flocon {
    /// Starts the SDK, installing and configuring the plugins you need.
    ///
    /// See ``startFlocon(_:)``.
    ///
    /// - Parameter configure: Installs the plugins. Runs synchronously, before the method returns.
    public static func start(_ configure: (inout FloconBuilder) -> Void) {
        var builder = FloconBuilder()
        configure(&builder)
        shared.start(builder)
    }

    fileprivate func start(_ builder: FloconBuilder) {
        var config = builder.config
        config.isCrashReporterEnabled = builder.features.contains(.crashReporter)
        guard initializeFlocon(config: config, features: builder.features) else { return }
        builder.applications.forEach { $0() }
    }
}
