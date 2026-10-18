import Combine
import SwiftUI
import Flocon
import LocalAuthentication
import Security

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

/// Sample keychain items, to inspect and edit from Flocon Desktop.
enum SampleKeychain {
    static let service = "com.flocon.sample"

    /// Adds one item of each case: text, binary, internet password, and an item protected by
    /// Face ID / Touch ID / passcode, which Flocon shows as `<protected>`.
    static func seed() {
        addGenericPassword(account: "user@example.com", value: Data("sk_test_4eC39HqLyjWDarjtT1zdp7dc".utf8))
        addGenericPassword(account: "device_key", value: Data([0x00, 0xFF, 0x10, 0x80]))
        addGenericPassword(
            account: "biometric_secret",
            value: Data("only with Face ID".utf8),
            accessControl: SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, nil)
        )
        add([
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: "api.example.com",
            kSecAttrAccount as String: "florent",
            kSecValueData as String: Data("hunter2".utf8),
        ])
    }

    /// Removes the sample items: generic passwords of the sample service, and the sample internet password.
    static func reset() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
        SecItemDelete([
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: "api.example.com",
            kSecAttrAccount as String: "florent",
        ] as CFDictionary)
    }

    /// Current value of the sample text item, or `nil` if it does not exist.
    static func apiToken() -> String? {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "user@example.com",
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func addGenericPassword(account: String, value: Data, accessControl: SecAccessControl? = nil) {
        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: value,
        ]
        if let accessControl {
            attributes[kSecAttrAccessControl as String] = accessControl
        }
        add(attributes)
    }

    /// Adds an item, keeping the existing one if any, so that edits made in Flocon survive relaunches.
    private static func add(_ attributes: [String: Any]) {
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess && status != errSecDuplicateItem {
            print("[FloconDemo] keychain add failed: \(status)")
        }
    }
}

/// Shows the sample values, refreshed each time they change, from the app or from Flocon Desktop.
struct PreferencesView: View {
    @State private var standardValues: [(key: String, value: String)] = []
    @State private var suiteValues: [(key: String, value: String)] = []
    @State private var apiToken: String?
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

            Section("Keychain") {
                LabeledContent("\(SampleKeychain.service) / user@example.com") {
                    Text(apiToken ?? "missing")
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                Text("Flocon also shows device_key (binary), biometric_secret (<protected>) and the api.example.com internet password.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Write sample values") {
                    SamplePreferences.seed()
                    SampleKeychain.seed()
                    reload()
                }
                Button("Toggle debug_logs from the app") {
                    let suite = SamplePreferences.suite
                    suite.set(!suite.bool(forKey: "debug_logs"), forKey: "debug_logs")
                    reload()
                }
                Button("Remove sample values", role: .destructive) {
                    SamplePreferences.reset()
                    SampleKeychain.reset()
                    reload()
                }
            }
        }
        .navigationTitle("Preferences")
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            reload()
        }
        // the keychain posts no change notification: poll it while the screen is shown
        .onReceive(refreshTimer) { _ in
            apiToken = SampleKeychain.apiToken()
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
        apiToken = SampleKeychain.apiToken()
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
