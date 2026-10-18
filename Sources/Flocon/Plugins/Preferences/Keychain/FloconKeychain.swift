import Foundation

/// Shows the passwords stored in the app keychain in the Preferences section of the Flocon desktop app.
///
/// The keychain is not shown by default: call this function to opt in, and only in debug builds.
/// The values are sent unencrypted to the Mac running Flocon, over the local network.
///
/// ```swift
/// #if DEBUG
/// floconRegisterKeychain()
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
/// Does nothing if ``Flocon/initialize(config:)`` has not been called.
///
/// - Parameter isEditable: Whether the values edited in the desktop app are written to the keychain.
///   Only existing items with a readable text value can be edited; items are never added or deleted.
///   Defaults to `false`.
public func floconRegisterKeychain(isEditable: Bool = false) {
    guard let plugin = Flocon.shared.client?.preferencesPlugin else { return }
    plugin.register(FloconKeychainPreference(itemClass: .genericPassword, isEditable: isEditable))
    plugin.registerAndNotify(FloconKeychainPreference(itemClass: .internetPassword, isEditable: isEditable))
}

extension Flocon {
    /// Shows the passwords stored in the app keychain in the Flocon desktop app.
    ///
    /// See ``floconRegisterKeychain(isEditable:)``.
    ///
    /// - Parameter isEditable: Whether the values edited in the desktop app are written to the keychain.
    public static func registerKeychain(isEditable: Bool = false) {
        floconRegisterKeychain(isEditable: isEditable)
    }
}
