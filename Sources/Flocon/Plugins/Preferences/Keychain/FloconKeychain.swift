import Foundation

extension FloconPreferencesPlugin {
    /// Shows the passwords stored in the app keychain in the Preferences section of the Flocon desktop app.
    ///
    /// The keychain is not shown by default: call this method to opt in, and only in debug builds.
    /// The values are sent unencrypted to the Mac running Flocon, over the local network.
    ///
    /// ```swift
    /// #if DEBUG
    /// Flocon.preferencesPlugin.registerKeychain()
    /// #endif
    /// ```
    ///
    /// Generic and internet passwords appear as two stores, with one key per item:
    /// `service / account` and `server / account`. Values are shown as text when they are UTF-8,
    /// and as their size otherwise.
    ///
    /// Items protected by Face ID, Touch ID or the passcode, or unreadable while the device is
    /// locked, are shown as `<protected>`: reading them never shows an authentication prompt.
    ///
    /// - Parameter isEditable: Whether the values edited, and the items deleted, in the desktop app are applied
    ///   to the keychain. Only existing items with a readable text value can be edited; items are never added.
    ///   Defaults to `false`.
    public func registerKeychain(isEditable: Bool = false) {
        add(FloconKeychainPreference(itemClass: .genericPassword, isEditable: isEditable))
        register(FloconKeychainPreference(itemClass: .internetPassword, isEditable: isEditable))
    }
}
