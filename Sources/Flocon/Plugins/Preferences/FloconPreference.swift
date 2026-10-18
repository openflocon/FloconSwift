import Foundation

/// A key-value store shown in the Preferences section of the Flocon desktop app.
///
/// Each store appears as one entry of the desktop list, under its ``name``.
protocol FloconPreference: AnyObject, Sendable {
    /// Name of the store in the desktop app. Must be unique.
    var name: String { get }

    /// Returns the keys of the store.
    func keys() -> [String]

    /// Returns the value of a key, or `nil` if the key has no value the desktop can show.
    func value(forKey key: String) -> FloconPreferenceValue?

    /// Writes a value edited in the desktop app.
    ///
    /// Implementations only write the value when its type matches the stored one.
    func setValue(_ value: FloconPreferenceValue, forKey key: String)
}

/// A preference value, in one of the types the Flocon desktop app can show and edit.
///
/// Exactly one property is set.
struct FloconPreferenceValue: Sendable, Equatable {
    var stringValue: String?
    var intValue: Int32?
    var longValue: Int64?
    var floatValue: Float?
    var booleanValue: Bool?
    var setStringValue: [String]?
}
