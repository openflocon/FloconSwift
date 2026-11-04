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

@Suite struct FloconDeviceHandlerTests {
    @Test func sendsTheIconAsABase64Body() async {
        let sender = RecordingSender()
        let handler = FloconDeviceHandler(sender: sender, icon: { "aWNvbg==" })

        await handler.sendAppIcon()

        #expect(sender.messages.count == 1)
        #expect(sender.messages.first?.plugin == "device")
        #expect(sender.messages.first?.method == "app_icon")
        #expect(sender.messages.first?.body == "aWNvbg==")
    }

    @Test func sendsNothingWithoutAnIcon() async {
        let sender = RecordingSender()
        let handler = FloconDeviceHandler(sender: sender, icon: { nil })

        await handler.sendAppIcon()

        #expect(sender.messages.isEmpty)
    }

    @Test func onlyHandlesTheIconRequest() {
        let sender = RecordingSender()
        let handler = FloconDeviceHandler(sender: sender, icon: { nil })

        #expect(handler.handle(FloconMessageFromServer(plugin: "device", method: "get_app_icon", body: "")))
        #expect(!handler.handle(FloconMessageFromServer(plugin: "device", method: "restart_app", body: "")))
        #expect(!handler.handle(FloconMessageFromServer(plugin: "network", method: "get_app_icon", body: "")))
    }
}
