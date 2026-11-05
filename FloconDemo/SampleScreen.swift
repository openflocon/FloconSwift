import SwiftUI

/// One screen per plugin of the SDK.
enum SampleScreen: String, CaseIterable, Hashable {
    case network, database, analytics, featureFlags, preferences, files, dashboard, deeplinks, timeline, images, crash

    var title: String {
        switch self {
        case .network: "Network"
        case .database: "Database"
        case .analytics: "Analytics"
        case .featureFlags: "Feature flags"
        case .preferences: "Preferences"
        case .files: "Files"
        case .dashboard: "Dashboard & Tables"
        case .deeplinks: "Deeplinks"
        case .timeline: "Timeline"
        case .images: "Images"
        case .crash: "Crash reporter"
        }
    }

    var subtitle: String {
        switch self {
        case .network: "HTTP, WebSocket, GraphQL"
        case .database: "SQLite queries"
        case .analytics: "Events and properties"
        case .featureFlags: "Toggle and observe"
        case .preferences: "UserDefaults and Keychain"
        case .files: "Files the desktop can browse"
        case .dashboard: "Live values and table rows"
        case .deeplinks: "Open links from the desktop"
        case .timeline: "Navigation, actions and tagged logs"
        case .images: "Images loaded by Kingfisher"
        case .crash: "Crash the app on purpose"
        }
    }

    var category: SampleCategory {
        switch self {
        case .network: .network
        case .database: .database
        case .analytics: .analytics
        case .featureFlags: .featureFlags
        case .dashboard: .table
        case .deeplinks: .deeplink
        case .crash: .crash
        case .timeline: .timeline
        case .preferences, .files, .images: .neutral
        }
    }

    var systemImage: String {
        switch self {
        case .network: "arrow.up.arrow.down"
        case .database: "cylinder"
        case .analytics: "chart.bar"
        case .featureFlags: "flag"
        case .preferences: "tablecells"
        case .files: "folder"
        case .dashboard: "rectangle.split.1x2"
        case .deeplinks: "link"
        case .timeline: "clock"
        case .images: "photo"
        case .crash: "exclamationmark.triangle"
        }
    }

    /// The four plugins shown as tiles on the home, the others are listed under them.
    static let main: [SampleScreen] = [.network, .database, .analytics, .featureFlags]
    static let others: [SampleScreen] = allCases.filter { !main.contains($0) }
}
