import Foundation
import Testing
@testable import Flocon

@Suite struct FloconUserDefaultsPreferenceTests {
    private let suiteName = "flocon.tests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let preference: FloconUserDefaultsPreference

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        preference = FloconUserDefaultsPreference(defaults: defaults, name: suiteName, domainName: suiteName)
    }

    @Test func readsEachSupportedType() {
        defaults.set("hello", forKey: "string")
        defaults.set(true, forKey: "bool")
        defaults.set(42, forKey: "int")
        defaults.set(Int64(1) << 40, forKey: "long")
        defaults.set(1.5, forKey: "double")
        defaults.set(["a", "b"], forKey: "strings")
        defaults.set(Date(timeIntervalSince1970: 0), forKey: "date")

        #expect(preference.keys() == ["bool", "date", "double", "int", "long", "string", "strings"])
        #expect(preference.value(forKey: "string") == FloconPreferenceValue(stringValue: "hello"))
        #expect(preference.value(forKey: "bool") == FloconPreferenceValue(booleanValue: true))
        #expect(preference.value(forKey: "int") == FloconPreferenceValue(intValue: 42))
        #expect(preference.value(forKey: "long") == FloconPreferenceValue(longValue: 1 << 40))
        #expect(preference.value(forKey: "double") == FloconPreferenceValue(floatValue: 1.5))
        #expect(preference.value(forKey: "strings") == FloconPreferenceValue(setStringValue: ["a", "b"]))
        #expect(preference.value(forKey: "date") == FloconPreferenceValue(stringValue: "1970-01-01T00:00:00.000Z"))
    }

    @Test func showsOtherTypesAsReadOnlyStrings() {
        defaults.set(["b": 2, "a": 1], forKey: "dictionary")
        defaults.set(Data([1, 2, 3]), forKey: "data")

        #expect(preference.value(forKey: "dictionary") == FloconPreferenceValue(stringValue: #"{"a":1,"b":2}"#))
        #expect(preference.value(forKey: "data") == FloconPreferenceValue(stringValue: "<3 bytes>"))

        preference.setValue(FloconPreferenceValue(stringValue: "{}"), forKey: "dictionary")
        #expect(preference.value(forKey: "dictionary") == FloconPreferenceValue(stringValue: #"{"a":1,"b":2}"#))
    }

    @Test func writesEditsOfTheSameType() {
        defaults.set("old", forKey: "string")
        defaults.set(false, forKey: "bool")
        defaults.set(1, forKey: "int")
        defaults.set(0.5, forKey: "double")
        defaults.set(Date(timeIntervalSince1970: 0), forKey: "date")

        preference.setValue(FloconPreferenceValue(stringValue: "new"), forKey: "string")
        preference.setValue(FloconPreferenceValue(booleanValue: true), forKey: "bool")
        preference.setValue(FloconPreferenceValue(intValue: 7), forKey: "int")
        preference.setValue(FloconPreferenceValue(floatValue: 2.25), forKey: "double")
        preference.setValue(FloconPreferenceValue(stringValue: "2026-10-18T12:00:00Z"), forKey: "date")

        #expect(defaults.string(forKey: "string") == "new")
        #expect(defaults.bool(forKey: "bool") == true)
        #expect(defaults.integer(forKey: "int") == 7)
        #expect(defaults.double(forKey: "double") == 2.25)
        #expect(defaults.object(forKey: "date") as? Date == Date(timeIntervalSince1970: 1_792_324_800))
    }

    @Test func ignoresEditsOfAnotherType() {
        defaults.set(true, forKey: "bool")

        preference.setValue(FloconPreferenceValue(stringValue: "not a bool"), forKey: "bool")
        preference.setValue(FloconPreferenceValue(stringValue: "new key"), forKey: "missing")

        #expect(defaults.object(forKey: "bool") as? Bool == true)
        #expect(defaults.object(forKey: "missing") == nil)
    }
}
