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

private func json(_ body: String) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
}

@Suite struct FloconTimelineTests {
    private func makePlugin() -> (FloconTimelinePlugin, RecordingSender) {
        let sender = RecordingSender()
        return (FloconTimelinePlugin(sender: sender), sender)
    }

    @Test func typedLogSendsTheTypeNameAndNoLevel() throws {
        let (plugin, sender) = makePlugin()
        let before = Int64(Date().timeIntervalSince1970 * 1000)

        plugin.log(type: .navigation, value: "CheckoutScreen", params: ["from": "CartScreen"])

        let message = try #require(sender.messages.first)
        #expect(sender.messages.count == 1)
        #expect(message.plugin == "timeline")
        #expect(message.method == "log")
        let body = try json(message.body)
        #expect(body["type"] as? String == "navigation")
        #expect(body["value"] as? String == "CheckoutScreen")
        #expect(body["params"] as? [String: String] == ["from": "CartScreen"])
        #expect(body["level"] == nil)
        let timestamp = try #require(body["timestamp"] as? Int64)
        #expect(timestamp >= before && timestamp <= Int64(Date().timeIntervalSince1970 * 1000))
    }

    @Test func shortcutsSendTheReservedTypes() throws {
        let (plugin, sender) = makePlugin()

        plugin.logNavigation("Home")
        plugin.logUserAction("tap_buy", params: ["sku": "a"])
        plugin.logLifecycle("didBecomeActive")

        let bodies = try sender.messages.map { try json($0.body) }
        #expect(bodies.map { $0["type"] as? String } == ["navigation", "userAction", "lifecycle"])
        #expect(bodies.map { $0["value"] as? String } == ["Home", "tap_buy", "didBecomeActive"])
        #expect(bodies.allSatisfy { $0["level"] == nil })
        #expect(bodies[1]["params"] as? [String: String] == ["sku": "a"])
    }

    @Test func customTypeSendsItsName() throws {
        let (plugin, sender) = makePlugin()

        plugin.log(type: TimelineType("billing"), value: "Purchase started")

        let body = try json(try #require(sender.messages.first).body)
        #expect(body["type"] as? String == "billing")
        #expect(body["level"] == nil)
    }

    @Test func taggedLogSendsTheTagAndTheLevel() throws {
        let (plugin, sender) = makePlugin()

        plugin.log(tag: "billing", value: "Purchase failed", params: ["sku": "premium"], level: .error)
        plugin.log(tag: "billing", value: "a", level: .debug)
        plugin.log(tag: "billing", value: "b", level: .warning)

        let bodies = try sender.messages.map { try json($0.body) }
        #expect(bodies.map { $0["type"] as? String } == ["billing", "billing", "billing"])
        #expect(bodies.map { $0["level"] as? String } == ["error", "debug", "warning"])
        #expect(bodies[0]["params"] as? [String: String] == ["sku": "premium"])
    }

    @Test func taggedLogDefaultsToInfo() throws {
        let (plugin, sender) = makePlugin()

        plugin.log(tag: "network", value: "Retrying")

        let body = try json(try #require(sender.messages.first).body)
        #expect(body["level"] as? String == "info")
    }

    @Test func emptyParamsAreOmitted() throws {
        let (plugin, sender) = makePlugin()

        plugin.logNavigation("Home")
        plugin.log(tag: "t", value: "v", params: [:])

        let bodies = try sender.messages.map { try json($0.body) }
        #expect(bodies.count == 2)
        #expect(bodies.allSatisfy { $0["params"] == nil })
    }

    @Test func typeNamesOfTheReservedTypes() {
        #expect(TimelineType.navigation.name == "navigation")
        #expect(TimelineType.userAction.name == "userAction")
        #expect(TimelineType.lifecycle.name == "lifecycle")
        #expect(TimelineType("billing") == TimelineType("billing"))
    }

    @Test func nothingIsSentOnConnection() {
        let (plugin, sender) = makePlugin()

        plugin.onConnectedToServer()

        #expect(sender.messages.isEmpty)
    }

    @Test func notInstalledPluginDoesNothing() {
        // not installed, and Flocon is never started in tests: the static accessor is the no-op plugin
        Flocon.timelinePlugin.logNavigation("Home")
        Flocon.timelinePlugin.log(type: TimelineType("billing"), value: "v", params: ["a": "b"])
        Flocon.timelinePlugin.log(tag: "t", value: "v", level: .error)
        #expect(Flocon.shared.timelinePlugin == nil)
    }

    @Test func timelineIsAFeatureKind() {
        #expect(FloconFeatureKind.allCases.contains(.timeline))
        var builder = FloconBuilder()
        builder.install(.timeline)
        #expect(builder.features.contains(.timeline))
    }
}
