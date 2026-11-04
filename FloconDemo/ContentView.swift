import SwiftUI
import Flocon

/// The sample: a home listing the plugins, and one screen per plugin.
struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var unknownDeeplink: URL?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .logsNavigation("Home")
                .navigationDestination(for: SampleScreen.self) { screen in
                    screen.destination
                        .logsNavigation(screen.title)
                }
                .navigationDestination(for: SampleConnectionRoute.self) { _ in
                    ConnectionScreen()
                        .logsNavigation("Connection")
                }
                .navigationDestination(for: DeeplinkRoute.self) { route in
                    route.screen
                        .logsNavigation(route.screenName)
                }
        }
        .tint(SampleTheme.accent)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active: Flocon.timelinePlugin.logLifecycle("active")
            case .inactive: Flocon.timelinePlugin.logLifecycle("inactive")
            case .background: Flocon.timelinePlugin.logLifecycle("background")
            @unknown default: break
            }
        }
        .onOpenURL { url in
            switch DeeplinkRoute.destination(for: url) {
            case .home:
                path = NavigationPath()
            case .route(let route):
                // replace the stack, so that the deeplink screen is shown right above home
                path = NavigationPath([route])
            case nil:
                unknownDeeplink = url
            }
        }
        .alert(
            "Unknown deeplink",
            isPresented: Binding(get: { unknownDeeplink != nil }, set: { if !$0 { unknownDeeplink = nil } }),
            presenting: unknownDeeplink
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { url in
            Text("The sample has no screen for \(url.absoluteString).")
        }
    }
}

extension SampleScreen {
    @ViewBuilder
    var destination: some View {
        switch self {
        case .network: NetworkScreen()
        case .database: DatabaseScreen()
        case .analytics: AnalyticsScreen()
        case .featureFlags: FeatureFlagsScreen()
        case .preferences: PreferencesView()
        case .files: FilesScreen()
        case .dashboard: DashboardScreen()
        case .deeplinks: DeeplinksScreen()
        case .timeline: TimelineScreen()
        case .images: ImageListView()
        case .crash: CrashScreen()
        }
    }
}

#Preview {
    ContentView()
}
