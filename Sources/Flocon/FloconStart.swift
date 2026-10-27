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

// MARK: - Builder

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

// MARK: - Features

enum FloconFeatureKind: Hashable, CaseIterable {
    case network, analytics, featureFlags, tables, preferences, files, database, dashboard, deeplinks
    case crashReporter
    /// Always installed: the connection with the desktop app relies on it.
    case device
}

/// A plugin that can be installed with ``FloconBuilder/install(_:)``.
public struct FloconFeature<Options> {
    let kind: FloconFeatureKind
    let makeOptions: () -> Options
    let apply: (Options) -> Void
}

extension FloconFeature where Options == Void {
    init(_ kind: FloconFeatureKind) {
        self.init(kind: kind, makeOptions: { () }, apply: { _ in })
    }

    /// Sends analytics events. See ``floconAnalytics(_:)``.
    public static var analytics: FloconFeature<Void> { .init(.analytics) }
    /// Sends the feature flags of the app. See ``floconFeatureFlags(_:)``.
    public static var featureFlags: FloconFeature<Void> { .init(.featureFlags) }
    /// Sends table rows. See ``floconTable(_:)``.
    public static var tables: FloconFeature<Void> { .init(.tables) }
    /// Shows the dashboards of the app. See ``floconDashboard(id:_:)``.
    public static var dashboard: FloconFeature<Void> { .init(.dashboard) }
    /// Reports the crashes of the app on the next launch.
    ///
    /// The crash handlers keep the handlers already installed, by another crash reporter for example, and call them.
    public static var crashReporter: FloconFeature<Void> { .init(.crashReporter) }
}

extension FloconFeature where Options == FloconNetworkOptions {
    /// Sends the network calls to the desktop app, and intercepts `URLSession.shared`.
    ///
    /// The options are the ones of ``Flocon/setNetworkOptions(_:)``. For other sessions, see
    /// ``Foundation/URLSessionConfiguration/withFlocon()``.
    public static var network: FloconFeature<FloconNetworkOptions> {
        .init(
            kind: .network,
            makeOptions: { FloconNetworkOptions() },
            apply: { options in
                Flocon.setNetworkOptions(options)
                Flocon.interceptSharedSession()
            }
        )
    }
}

/// Options of the database plugin.
public struct FloconDatabaseOptions {
    fileprivate var databases: [FloconDatabase] = []

    /// Lists a SQLite database in the desktop app.
    public mutating func register(displayName: String, url: URL) {
        databases.append(FloconDatabase(displayName: displayName, url: url))
    }

    /// Lists a SQLite database in the desktop app.
    public mutating func register(_ database: FloconDatabase) {
        databases.append(database)
    }
}

extension FloconFeature where Options == FloconDatabaseOptions {
    /// Lists and queries the SQLite databases of the app. See ``floconLogDatabaseQuery(dbName:sqlQuery:bindArgs:)``.
    public static var database: FloconFeature<FloconDatabaseOptions> {
        .init(
            kind: .database,
            makeOptions: { FloconDatabaseOptions() },
            apply: { $0.databases.forEach(floconRegisterDatabase) }
        )
    }
}

/// Options of the preferences plugin.
public struct FloconPreferencesOptions {
    fileprivate var userDefaults: [(defaults: UserDefaults, suiteName: String)] = []
    fileprivate var preferences: [FloconPreference] = []
    fileprivate var keychain: Bool?

    /// Shows a `UserDefaults` suite. `UserDefaults.standard` is shown automatically.
    public mutating func userDefaults(_ defaults: UserDefaults, suiteName: String) {
        userDefaults.append((defaults, suiteName))
    }

    /// Shows a key-value store of your own.
    public mutating func preference(_ preference: FloconPreference) {
        preferences.append(preference)
    }

    /// Shows the keychain. It is opt-in and should only be shown in debug builds:
    /// its values are sent unencrypted to the Mac running Flocon.
    public mutating func keychain(isEditable: Bool = false) {
        keychain = isEditable
    }
}

extension FloconFeature where Options == FloconPreferencesOptions {
    /// Shows key-value stores, such as `UserDefaults`, the keychain or a store of your own.
    public static var preferences: FloconFeature<FloconPreferencesOptions> {
        .init(
            kind: .preferences,
            makeOptions: { FloconPreferencesOptions() },
            apply: { options in
                options.userDefaults.forEach { floconRegisterUserDefaults($0.defaults, suiteName: $0.suiteName) }
                options.preferences.forEach(floconRegisterPreference)
                if let isEditable = options.keychain {
                    floconRegisterKeychain(isEditable: isEditable)
                }
            }
        )
    }
}

/// Options of the files plugin.
public struct FloconFilesOptions {
    fileprivate var folders: [FloconFolder] = []
    fileprivate var appGroups: [String] = []

    /// Lists a folder in the desktop app. The usual folders of the app are shown automatically.
    public mutating func folder(displayName: String, url: URL) {
        folders.append(FloconFolder(displayName: displayName, url: url))
    }

    /// Lists the container of an App Group.
    public mutating func appGroup(_ identifier: String) {
        appGroups.append(identifier)
    }
}

extension FloconFeature where Options == FloconFilesOptions {
    /// Lets the desktop app browse the files of the app.
    public static var files: FloconFeature<FloconFilesOptions> {
        .init(
            kind: .files,
            makeOptions: { FloconFilesOptions() },
            apply: { options in
                options.folders.forEach(floconRegisterFolder)
                options.appGroups.forEach(floconRegisterAppGroup)
            }
        )
    }
}

/// Options of the deeplinks plugin.
public struct FloconDeeplinksOptions {
    fileprivate var deeplinks: [FloconDeeplink] = []
    fileprivate var variables: [FloconDeeplinkVariable] = []

    /// Lists deeplinks, and the variables they use, in the desktop app.
    public mutating func register(_ deeplinks: [FloconDeeplink], variables: [FloconDeeplinkVariable] = []) {
        self.deeplinks += deeplinks
        self.variables += variables
    }
}

extension FloconFeature where Options == FloconDeeplinksOptions {
    /// Lists the deeplinks of the app in the desktop app, which can open them.
    public static var deeplinks: FloconFeature<FloconDeeplinksOptions> {
        .init(
            kind: .deeplinks,
            makeOptions: { FloconDeeplinksOptions() },
            apply: { floconRegisterDeeplinks($0.deeplinks, variables: $0.variables) }
        )
    }
}
