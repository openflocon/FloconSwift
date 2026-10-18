import Foundation

/// Exposes a `UserDefaults` store to the Flocon desktop app.
///
/// Only the values written by the app are shown, not the system and global defaults
/// that `dictionaryRepresentation()` also returns.
final class FloconUserDefaultsPreference: FloconPreference, @unchecked Sendable {
    let name: String
    private let defaults: UserDefaults
    /// Name of the persistent domain that holds the values of `defaults`.
    private let domainName: String?

    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Creates a preference for a `UserDefaults` store.
    ///
    /// - Parameters:
    ///   - defaults: The store.
    ///   - name: Name of the store in the desktop app.
    ///   - domainName: Name of its persistent domain: the bundle identifier for
    ///     `UserDefaults.standard`, the suite name otherwise.
    init(defaults: UserDefaults, name: String, domainName: String?) {
        self.defaults = defaults
        self.name = name
        self.domainName = domainName
    }

    private var storedValues: [String: Any] {
        guard let domainName else { return [:] }
        return defaults.persistentDomain(forName: domainName) ?? [:]
    }

    func keys() -> [String] {
        storedValues.keys.sorted()
    }

    func value(forKey key: String) -> FloconPreferenceValue? {
        guard let value = storedValues[key] else { return nil }
        return Self.preferenceValue(from: value)
    }

    func setValue(_ value: FloconPreferenceValue, forKey key: String) {
        guard let current = storedValues[key], let newValue = Self.storedValue(from: value, replacing: current) else {
            FloconLogger.log("Ignored edit of \(name).\(key): the type does not match the stored value")
            return
        }
        defaults.set(newValue, forKey: key)
    }

    // MARK: Conversions

    /// Converts a stored value to a value the desktop can show.
    private static func preferenceValue(from value: Any) -> FloconPreferenceValue {
        switch value {
        case let string as String:
            return FloconPreferenceValue(stringValue: string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return FloconPreferenceValue(booleanValue: number.boolValue)
            }
            if CFNumberIsFloatType(number) {
                return FloconPreferenceValue(floatValue: number.floatValue)
            }
            let integer = number.int64Value
            if let int32 = Int32(exactly: integer) {
                return FloconPreferenceValue(intValue: int32)
            }
            return FloconPreferenceValue(longValue: integer)
        case let date as Date:
            return FloconPreferenceValue(stringValue: dateStyle.format(date))
        case let strings as [String]:
            return FloconPreferenceValue(setStringValue: strings)
        case let data as Data:
            return FloconPreferenceValue(stringValue: "<\(data.count) bytes>")
        default:
            // dictionaries and mixed arrays: shown as JSON when possible, read-only
            if JSONSerialization.isValidJSONObject(value),
               let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
               let json = String(data: data, encoding: .utf8) {
                return FloconPreferenceValue(stringValue: json)
            }
            return FloconPreferenceValue(stringValue: String(describing: value))
        }
    }

    /// Converts an edited value to the type of the value it replaces.
    ///
    /// - Returns: The value to store, or `nil` if the edit does not match the stored type.
    private static func storedValue(from value: FloconPreferenceValue, replacing current: Any) -> Any? {
        switch current {
        case is String:
            return value.stringValue
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return value.booleanValue
            }
            if CFNumberIsFloatType(number) {
                return value.floatValue.map { Double($0) }
            }
            return value.longValue.map { Int($0) } ?? value.intValue.map { Int($0) }
        case is Date:
            return value.stringValue.flatMap { string in
                // with or without fractional seconds
                (try? dateStyle.parse(string)) ?? (try? Date.ISO8601FormatStyle().parse(string))
            }
        case is [String]:
            return value.setStringValue
        default:
            return nil
        }
    }
}
