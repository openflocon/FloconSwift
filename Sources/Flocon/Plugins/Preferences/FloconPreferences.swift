import Foundation

/// Shows a `UserDefaults` store in the Preferences section of the Flocon desktop app.
///
/// `UserDefaults.standard` is shown automatically. Register the other stores of the app,
/// such as the ones shared with an App Group, so that you can inspect and edit them too:
///
/// ```swift
/// if let shared = UserDefaults(suiteName: "group.com.example.app") {
///     floconRegisterUserDefaults(shared, suiteName: "group.com.example.app")
/// }
/// ```
///
/// Values of type `String`, `Bool`, number, `Date` and `[String]` can be edited from the desktop.
/// Other values (`Data`, dictionaries, mixed arrays) are shown read-only.
///
/// Does nothing if ``Flocon/initialize(config:)`` has not been called.
///
/// - Parameters:
///   - defaults: The store, created with `UserDefaults(suiteName:)`.
///   - suiteName: The suite name used to create `defaults`. It is also the name of the store
///     in the desktop app.
public func floconRegisterUserDefaults(_ defaults: UserDefaults, suiteName: String) {
    Flocon.shared.preferencesPlugin?.register(
        FloconUserDefaultsPreference(defaults: defaults, name: suiteName, domainName: suiteName)
    )
}

extension Flocon {
    /// Shows a `UserDefaults` store in the Preferences section of the Flocon desktop app.
    ///
    /// See ``floconRegisterUserDefaults(_:suiteName:)``.
    ///
    /// - Parameters:
    ///   - defaults: The store, created with `UserDefaults(suiteName:)`.
    ///   - suiteName: The suite name used to create `defaults`.
    public static func registerUserDefaults(_ defaults: UserDefaults, suiteName: String) {
        floconRegisterUserDefaults(defaults, suiteName: suiteName)
    }
}
