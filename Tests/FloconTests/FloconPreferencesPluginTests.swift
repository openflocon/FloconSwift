import Foundation
import Testing
@testable import Flocon

private final class RecordingSender: FloconMessageSender, @unchecked Sendable {
    private let lock = NSLock()
    private var _bodies: [String] = []

    var bodies: [String] {
        lock.lock(); defer { lock.unlock() }
        return _bodies
    }

    func send(plugin: String, method: String, body: String) {
        lock.lock(); defer { lock.unlock() }
        _bodies.append(body)
    }
}

private final class InMemoryPreference: FloconPreference, @unchecked Sendable {
    let name: String
    init(name: String) { self.name = name }
    func keys() -> [String] { [] }
    func value(forKey key: String) -> FloconPreferenceValue? { nil }
    func setValue(_ value: FloconPreferenceValue, forKey key: String) {}
}

private final class DictionaryPreference: FloconPreference, @unchecked Sendable {
    let name = "dictionary"
    private let lock = NSLock()
    private var values = ["token": "abc", "age": "34"]
    func keys() -> [String] { lock.lock(); defer { lock.unlock() }; return values.keys.sorted() }
    func value(forKey key: String) -> FloconPreferenceValue? {
        lock.lock(); defer { lock.unlock() }
        return values[key].map { FloconPreferenceValue(stringValue: $0) }
    }
    func setValue(_ value: FloconPreferenceValue, forKey key: String) {}
    func removeValue(forKey key: String) { lock.lock(); values[key] = nil; lock.unlock() }
}

private final class RealmPreference: FloconPreference, @unchecked Sendable {
    let name = "realm"
    let type = "Realm"
    func keys() -> [String] { [] }
    func value(forKey key: String) -> FloconPreferenceValue? { nil }
    func setValue(_ value: FloconPreferenceValue, forKey key: String) {}
}

@Suite struct FloconPreferencesPluginTests {
    @Test func sendsTheTypeOfEachStore() throws {
        let sender = RecordingSender()
        let plugin = FloconPreferencesPlugin(sender: sender)
        let suiteName = "flocon.tests.\(UUID().uuidString)"

        plugin.register(InMemoryPreference(name: "memory"))
        plugin.register(RealmPreference())
        plugin.register(FloconUserDefaultsPreference(defaults: UserDefaults(suiteName: suiteName)!, name: suiteName, domainName: suiteName))

        let body = try #require(sender.bodies.last)
        let list = try #require(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [[String: String]])
        // the plugin may also hold UserDefaults.standard, depending on the test host
        let types = Dictionary(uniqueKeysWithValues: list.map { ($0["name"]!, $0["type"]!) })
        #expect(types["memory"] == FloconPreferenceType.custom)
        #expect(types["realm"] == "Realm")
        #expect(types[suiteName] == FloconPreferenceType.userDefaults)
    }

    @Test func removesAKeyAndSendsTheContent() throws {
        let sender = RecordingSender()
        let plugin = FloconPreferencesPlugin(sender: sender)
        let preference = DictionaryPreference()
        plugin.register(preference)

        plugin.onMessageReceived(FloconMessageFromServer(
            plugin: "shared_preferences",
            method: "remove_shared_preference_value",
            body: #"{"requestId":"1","sharedPreferenceName":"dictionary","key":"token"}"#
        ))

        #expect(preference.keys() == ["age"])
        let body = try #require(sender.bodies.last)
        #expect(body.contains(#""requestId":"1""#))
        #expect(body.contains(#""key":"age""#))
        #expect(!body.contains("token"))
    }

    @Test func theKeychainIsTyped() {
        #expect(FloconKeychainPreference(itemClass: .genericPassword, isEditable: false).type == FloconPreferenceType.keychain)
    }
}
