import Foundation

/// Suggested values for ``FloconPreference/type``, the storage shown next to the store name in the desktop app.
///
/// Any other string is accepted, for example `"Realm"` or `"In memory"`.
public enum FloconPreferenceType {
    /// A `UserDefaults` store.
    public static let userDefaults = "UserDefaults"
    /// Items of the keychain.
    public static let keychain = "Keychain"
    /// A store of your own, the default value.
    public static let custom = "Custom"
}
