import Foundation

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
