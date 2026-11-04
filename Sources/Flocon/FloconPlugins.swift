import Foundation

// MARK: - Plugins

extension Flocon {
    /// Logs network calls and WebSocket events, for the clients the SDK does not intercept itself.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/networkPlugin``.
    public var networkPlugin: FloconNetworkPlugin? { client?.networkPlugin }

    /// Sends analytics events.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/analyticsPlugin``.
    public var analyticsPlugin: FloconAnalyticsPlugin? { client?.analyticsPlugin }

    /// Sends the feature flags of the app.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/featureFlagsPlugin``.
    public var featureFlagsPlugin: FloconFeatureFlagsPlugin? { client?.featureFlagsPlugin }

    /// Sends table rows.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/tablePlugin``.
    public var tablePlugin: FloconTablePlugin? { client?.tablePlugin }

    /// Shows key-value stores, such as `UserDefaults`, the keychain or a store of your own.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/preferencesPlugin``.
    public var preferencesPlugin: FloconPreferencesPlugin? { client?.preferencesPlugin }

    /// Lists and queries the SQLite databases of the app.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/databasePlugin``.
    public var databasePlugin: FloconDatabasePlugin? { client?.databasePlugin }

    /// Lets the desktop app browse the files of the app.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/filesPlugin``.
    public var filesPlugin: FloconFilesPlugin? { client?.filesPlugin }

    /// Shows the dashboards of the app.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/dashboardPlugin``.
    public var dashboardPlugin: FloconDashboardPlugin? { client?.dashboardPlugin }

    /// Lists the deeplinks of the app.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/deeplinksPlugin``.
    public var deeplinksPlugin: FloconDeeplinksPlugin? { client?.deeplinksPlugin }

    /// Sends timeline logs.
    ///
    /// `nil` before ``initialize(config:)``. Prefer ``Flocon/timelinePlugin``.
    public var timelinePlugin: FloconTimelinePlugin? { client?.timelinePlugin }
}

// The static accessors never return `nil`: when Flocon is not initialized, or the plugin is not
// installed, they return a plugin that does nothing, so the calls can stay in the app unconditionally.
extension Flocon {
    /// Logs network calls and WebSocket events, for the clients the SDK does not intercept itself.
    ///
    /// ```swift
    /// Flocon.networkPlugin.logWebSocketEvent(FloconWebSocketEvent(websocketUrl: url, event: .open))
    /// ```
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var networkPlugin: FloconNetworkPlugin { shared.networkPlugin ?? FloconNoOpPlugins.network }

    /// Sends analytics events.
    ///
    /// ```swift
    /// Flocon.analyticsPlugin.sender("firebase").logEvents(AnalyticsEvent(eventName: "app_opened"))
    /// ```
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var analyticsPlugin: FloconAnalyticsPlugin { shared.analyticsPlugin ?? FloconNoOpPlugins.analytics }

    /// Sends the feature flags of the app.
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var featureFlagsPlugin: FloconFeatureFlagsPlugin {
        shared.featureFlagsPlugin ?? FloconNoOpPlugins.featureFlags
    }

    /// Sends table rows.
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var tablePlugin: FloconTablePlugin { shared.tablePlugin ?? FloconNoOpPlugins.table }

    /// Shows key-value stores, such as `UserDefaults`, the keychain or a store of your own.
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var preferencesPlugin: FloconPreferencesPlugin {
        shared.preferencesPlugin ?? FloconNoOpPlugins.preferences
    }

    /// Lists and queries the SQLite databases of the app.
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var databasePlugin: FloconDatabasePlugin { shared.databasePlugin ?? FloconNoOpPlugins.database }

    /// Lets the desktop app browse the files of the app.
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var filesPlugin: FloconFilesPlugin { shared.filesPlugin ?? FloconNoOpPlugins.files }

    /// Shows the dashboards of the app.
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var dashboardPlugin: FloconDashboardPlugin { shared.dashboardPlugin ?? FloconNoOpPlugins.dashboard }

    /// Lists the deeplinks of the app.
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var deeplinksPlugin: FloconDeeplinksPlugin { shared.deeplinksPlugin ?? FloconNoOpPlugins.deeplinks }

    /// Sends timeline logs: navigation, user actions, lifecycle and your own events.
    ///
    /// ```swift
    /// Flocon.timelinePlugin.logNavigation("CheckoutScreen", params: ["from": "CartScreen"])
    /// ```
    ///
    /// Does nothing before ``initialize(config:)``, or if the plugin is not installed.
    public static var timelinePlugin: FloconTimelinePlugin { shared.timelinePlugin ?? FloconNoOpPlugins.timeline }
}
