import Foundation

/// A key-value store shown in the Preferences section of the Flocon desktop app.
///
/// `UserDefaults` and the keychain are supported by the SDK. Implement this protocol to show
/// another store of the app, then register it with ``Flocon.preferencesPlugin.register(_:)``:
///
/// ```swift
/// final class FeatureFlagsPreference: FloconPreference {
///     let name = "Feature flags"
///     let type = "Remote config"
///     func keys() -> [String] { FeatureFlags.all.map(\.key) }
///     func value(forKey key: String) -> FloconPreferenceValue? {
///         FloconPreferenceValue(booleanValue: FeatureFlags.isEnabled(key))
///     }
///     func setValue(_ value: FloconPreferenceValue, forKey key: String) {
///         if let isEnabled = value.booleanValue { FeatureFlags.set(key, isEnabled) }
///     }
/// }
/// ```
///
/// The methods are called from a background thread.
public protocol FloconPreference: AnyObject, Sendable {
    /// Name of the store in the desktop app. Must be unique.
    var name: String { get }

    /// Storage of the store, shown next to its name in the desktop app.
    ///
    /// One of the ``FloconPreferenceType`` values or any other string. Defaults to ``FloconPreferenceType/custom``.
    var type: String { get }

    /// Returns the keys of the store.
    func keys() -> [String]

    /// Returns the value of a key, or `nil` if the key has no value the desktop can show.
    func value(forKey key: String) -> FloconPreferenceValue?

    /// Writes a value edited in the desktop app.
    ///
    /// Only write the value when its type matches the stored one.
    func setValue(_ value: FloconPreferenceValue, forKey key: String)

    /// Removes a key deleted in the desktop app.
    ///
    /// Does nothing by default: implement it to let the desktop delete keys of the store.
    func removeValue(forKey key: String)
}

public extension FloconPreference {
    var type: String { FloconPreferenceType.custom }

    func removeValue(forKey key: String) {}
}

/// A preference value, in one of the types the Flocon desktop app can show and edit.
///
/// Set exactly one property.
public struct FloconPreferenceValue: Sendable, Equatable {
    public var stringValue: String?
    public var intValue: Int32?
    public var longValue: Int64?
    public var floatValue: Float?
    public var booleanValue: Bool?
    /// A list of strings, shown and edited as a set.
    public var setStringValue: [String]?

    /// Creates a value. Set exactly one parameter.
    public init(
        stringValue: String? = nil,
        intValue: Int32? = nil,
        longValue: Int64? = nil,
        floatValue: Float? = nil,
        booleanValue: Bool? = nil,
        setStringValue: [String]? = nil
    ) {
        self.stringValue = stringValue
        self.intValue = intValue
        self.longValue = longValue
        self.floatValue = floatValue
        self.booleanValue = booleanValue
        self.setStringValue = setStringValue
    }
}
