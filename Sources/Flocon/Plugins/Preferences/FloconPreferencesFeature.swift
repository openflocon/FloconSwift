import Foundation

/// Options of the preferences plugin.
public struct FloconPreferencesOptions {
    var userDefaults: [(defaults: UserDefaults, suiteName: String)] = []
    var preferences: [FloconPreference] = []
    var keychain: Bool?

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
                options.userDefaults.forEach { Flocon.preferencesPlugin.registerUserDefaults($0.defaults, suiteName: $0.suiteName) }
                options.preferences.forEach(Flocon.preferencesPlugin.register)
                if let isEditable = options.keychain {
                    Flocon.preferencesPlugin.registerKeychain(isEditable: isEditable)
                }
            }
        )
    }
}
