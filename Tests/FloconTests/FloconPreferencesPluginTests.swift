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

    @Test func theKeychainIsTyped() {
        #expect(FloconKeychainPreference(itemClass: .genericPassword, isEditable: false).type == FloconPreferenceType.keychain)
    }
}
