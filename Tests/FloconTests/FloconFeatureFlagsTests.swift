import Foundation
import Testing
@testable import Flocon

private final class RecordingSender: FloconMessageSender, @unchecked Sendable {
    struct Message {
        let plugin: String
        let method: String
        let body: String
    }

    private let lock = NSLock()
    private var _messages: [Message] = []

    var messages: [Message] {
        lock.lock(); defer { lock.unlock() }
        return _messages
    }

    func send(plugin: String, method: String, body: String) {
        lock.lock(); defer { lock.unlock() }
        _messages.append(Message(plugin: plugin, method: method, body: body))
    }
}

private func sorted(_ json: String) throws -> String {
    let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    return try #require(String(data: data, encoding: .utf8))
}

@Suite struct FloconFeatureFlagsTests {
    @Test func encodesLikeTheAndroidSDK() throws {
        let sender = RecordingSender()
        let plugin = FloconFeatureFlagsPlugin(sender: sender)

        plugin.register(provider: "firebase", flags: [
            FloconFeatureFlag(name: "new_checkout", state: .custom, variant: "treatment", payload: #"{"color":"red"}"#),
            FloconFeatureFlag(name: "dark_mode", state: .on, variant: "on"),
        ])

        let message = try #require(sender.messages.single)
        #expect(message.plugin == "feature_flags")
        #expect(message.method == "register")
        #expect(try sorted(message.body) == #"{"flags":[{"name":"new_checkout","payload":"{\"color\":\"red\"}","state":"custom","variant":"treatment"},{"name":"dark_mode","state":"on","variant":"on"}],"provider":"firebase"}"#)
    }

    @Test func resendsEveryProviderOnConnection() throws {
        let sender = RecordingSender()
        let plugin = FloconFeatureFlagsPlugin(sender: sender)

        plugin.register(provider: "statsig", flags: [FloconFeatureFlag(name: "a", state: .off, variant: "control")])
        plugin.register(provider: "firebase", flags: [FloconFeatureFlag(name: "b", state: .on, variant: "on")])
        plugin.register(provider: "firebase", flags: [FloconFeatureFlag(name: "c", state: .off, variant: "off")])
        plugin.onConnectedToServer()

        let resent = sender.messages.dropFirst(3).map(\.body)
        #expect(resent.count == 2)
        #expect(try sorted(resent[0]) == #"{"flags":[{"name":"c","state":"off","variant":"off"}],"provider":"firebase"}"#)
        #expect(try sorted(resent[1]) == #"{"flags":[{"name":"a","state":"off","variant":"control"}],"provider":"statsig"}"#)
    }

    @Test func sendsNothingOnConnectionWhenNothingIsRegistered() {
        let sender = RecordingSender()
        let plugin = FloconFeatureFlagsPlugin(sender: sender)

        plugin.onConnectedToServer()

        #expect(sender.messages.isEmpty)
    }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
