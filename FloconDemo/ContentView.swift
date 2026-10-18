import SwiftUI
import Flocon

struct ContentView: View {
    private let client = SampleNetworkClient()

    @State private var status = "Tap a button, then check Flocon on your Mac."
    @State private var isLoading = false
    @State private var tableRowCount = 0
    @State private var path: [DeeplinkRoute] = []
    @State private var unknownDeeplink: URL?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Result") {
                    HStack {
                        Text(status)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }

                Section("HTTP") {
                    testButton("URLSession test") { try await client.simpleGet() }
                    testButton("URLSession gzip test") { try await client.gzipGet() }
                    testButton("POST JSON test") { try await client.post() }
                    testButton("GraphQL test") { try await client.graphQL() }
                    testButton("Image test (picsum)") { try await client.image() }
                    testButton("Slow call (2 s)") { try await client.slow() }
                }

                Section("Images (Kingfisher)") {
                    NavigationLink("Image list") {
                        ImageListView()
                    }
                }

                Section("WebSocket (manual)") {
                    testButton("WebSocket echo test") { try await client.websocketEcho() }
                }

                Section("Analytics") {
                    Button("Send analytics event") {
                        floconAnalytics("sample").logEvents(
                            AnalyticsEvent(
                                eventName: "button_tapped",
                                AnalyticsProperty("screen", "ContentView"),
                                AnalyticsProperty("id", UUID().uuidString)
                            )
                        )
                        status = "Analytics event sent"
                    }
                }

                Section("Preferences (UserDefaults)") {
                    NavigationLink("Preferences") {
                        PreferencesView()
                    }
                }

                Section("Files") {
                    Button("Write sample files") {
                        status = "\(SampleFiles.seed()) sample files written, browse them in Flocon"
                    }
                }

                Section("Tables") {
                    Button("Log table row") {
                        tableRowCount += 1
                        floconTable("sample_users").log(
                            TableColumnConfig("index", "\(tableRowCount)"),
                            TableColumnConfig("name", ["Alice", "Bob", "Charlie", "Dana"].randomElement()!),
                            TableColumnConfig("score", "\(Int.random(in: 0...100))")
                        )
                        status = "Table row #\(tableRowCount) logged"
                    }
                }

                Section("Errors") {
                    testButton("404 test") { try await client.notFound() }
                    testButton("Network error test") { try await client.networkError() }
                }
            }
            .navigationTitle("Flocon sample")
            .navigationDestination(for: DeeplinkRoute.self) { route in
                route.screen
            }
            .onOpenURL { url in
                status = "Deeplink opened: \(url.absoluteString)"
                switch DeeplinkRoute.destination(for: url) {
                case .home:
                    path = []
                case .route(let route):
                    // replace the stack, so that the deeplink screen is shown right above home
                    path = [route]
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

    private func testButton(
        _ title: String,
        action: @escaping @Sendable () async throws -> String
    ) -> some View {
        Button(title) {
            Task {
                isLoading = true
                status = "\(title)…"
                do {
                    status = "\(title) → \(try await action())"
                } catch {
                    status = "\(title) → error: \(error.localizedDescription)"
                }
                isLoading = false
            }
        }
        .disabled(isLoading)
    }
}

#Preview {
    ContentView()
}
