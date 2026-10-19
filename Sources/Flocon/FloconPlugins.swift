import Foundation

// MARK: - Plugins

extension Flocon {
    /// Logs network calls and WebSocket events, for the clients the SDK does not intercept itself.
    ///
    /// `nil` before ``initialize(config:)``.
    public var networkPlugin: FloconNetworkPlugin? { client?.networkPlugin }

    /// Sends analytics events. Usually used through ``floconAnalytics(_:)``.
    ///
    /// `nil` before ``initialize(config:)``.
    public var analyticsPlugin: FloconAnalyticsPlugin? { client?.analyticsPlugin }

    /// Sends table rows. Usually used through ``floconTable(_:)``.
    ///
    /// `nil` before ``initialize(config:)``.
    public var tablePlugin: FloconTablePlugin? { client?.tablePlugin }

    /// Shows key-value stores, such as `UserDefaults`, the keychain or a store of your own.
    ///
    /// `nil` before ``initialize(config:)``.
    public var preferencesPlugin: FloconPreferencesPlugin? { client?.preferencesPlugin }

    /// Lists and queries the SQLite databases of the app. Usually used through
    /// ``floconRegisterDatabase(displayName:url:)`` and ``floconLogDatabaseQuery(dbName:sqlQuery:bindArgs:)``.
    ///
    /// `nil` before ``initialize(config:)``.
    public var databasePlugin: FloconDatabasePlugin? { client?.databasePlugin }

    /// Lets the desktop app browse the files of the app. Usually used through
    /// ``floconRegisterFolder(displayName:url:)`` and ``floconRegisterAppGroup(_:)``.
    ///
    /// `nil` before ``initialize(config:)``.
    public var filesPlugin: FloconFilesPlugin? { client?.filesPlugin }

    /// Shows the dashboards of the app. Usually used through ``floconDashboard(id:_:)``.
    ///
    /// `nil` before ``initialize(config:)``.
    public var dashboardPlugin: FloconDashboardPlugin? { client?.dashboardPlugin }

    /// Lists the deeplinks of the app. Usually used through ``floconRegisterDeeplinks(_:variables:)``.
    ///
    /// `nil` before ``initialize(config:)``.
    public var deeplinksPlugin: FloconDeeplinksPlugin? { client?.deeplinksPlugin }
}

/// Shows a key-value store of your own in the Preferences section of the Flocon desktop app.
///
/// See ``FloconPreference``. Registering a store with the same ``FloconPreference/name``
/// replaces the previous one. Does nothing if ``Flocon/initialize(config:)`` has not been called.
///
/// - Parameter preference: The store.
public func floconRegisterPreference(_ preference: FloconPreference) {
    Flocon.shared.preferencesPlugin?.register(preference)
}
