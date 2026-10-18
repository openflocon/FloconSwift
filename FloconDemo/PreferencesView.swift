import SwiftUI
import Flocon

/// Sample values stored in `UserDefaults`, to inspect and edit from Flocon Desktop.
enum SamplePreferences {
    static let suiteName = "flocon.sample.settings"
    static let suite = UserDefaults(suiteName: suiteName)!

    /// Writes one value of each type, in `UserDefaults.standard` and in the sample suite.
    static func seed() {
        let standard = UserDefaults.standard
        standard.set("Florent", forKey: "user_name")
        standard.set(true, forKey: "onboarding_done")
        standard.set(standard.integer(forKey: "launch_count") + 1, forKey: "launch_count")
        standard.set(4.5, forKey: "rating")
        standard.set(Date(), forKey: "last_launch")
        standard.set(["swift", "ios", "flocon"], forKey: "tags")
        standard.set(["theme": "dark", "font_size": 14], forKey: "appearance")
        standard.set(Data("binary".utf8), forKey: "token_data")

        suite.set("https://api.example.com", forKey: "base_url")
        suite.set(false, forKey: "debug_logs")
        suite.set(30, forKey: "timeout_seconds")
    }

    /// Removes the sample values.
    static func reset() {
        for key in ["user_name", "onboarding_done", "launch_count", "rating", "last_launch", "tags", "appearance", "token_data"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        suite.removePersistentDomain(forName: suiteName)
    }
}

/// Shows the sample values, refreshed each time they change, from the app or from Flocon Desktop.
struct PreferencesView: View {
    @State private var standardValues: [(key: String, value: String)] = []
    @State private var suiteValues: [(key: String, value: String)] = []

    var body: some View {
        List {
            Section {
                Text("Edit these values in the Preferences section of Flocon Desktop: they update here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("UserDefaults.standard") {
                rows(standardValues)
            }

            Section(SamplePreferences.suiteName) {
                rows(suiteValues)
            }

            Section {
                Button("Write sample values") {
                    SamplePreferences.seed()
                    reload()
                }
                Button("Toggle debug_logs from the app") {
                    let suite = SamplePreferences.suite
                    suite.set(!suite.bool(forKey: "debug_logs"), forKey: "debug_logs")
                    reload()
                }
                Button("Remove sample values", role: .destructive) {
                    SamplePreferences.reset()
                    reload()
                }
            }
        }
        .navigationTitle("Preferences")
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            reload()
        }
    }

    private func rows(_ values: [(key: String, value: String)]) -> some View {
        ForEach(values, id: \.key) { item in
            LabeledContent(item.key) {
                Text(item.value)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func reload() {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        standardValues = Self.describe(UserDefaults.standard.persistentDomain(forName: bundleId))
        suiteValues = Self.describe(SamplePreferences.suite.persistentDomain(forName: SamplePreferences.suiteName))
    }

    private static func describe(_ domain: [String: Any]?) -> [(key: String, value: String)] {
        (domain ?? [:])
            .map { (key: $0.key, value: String(describing: $0.value)) }
            .sorted { $0.key < $1.key }
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
    }
}
