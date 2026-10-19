import Combine
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

/// Collects the dashboards produced by ``startDashboard(id:contents:register:)``.
private final class RegisteredDashboards: @unchecked Sendable {
    private let lock = NSLock()
    private var _configs: [FloconDashboardConfig] = []

    var configs: [FloconDashboardConfig] {
        lock.lock(); defer { lock.unlock() }
        return _configs
    }

    func append(_ config: FloconDashboardConfig) {
        lock.lock(); defer { lock.unlock() }
        _configs.append(config)
    }
}

private func encode(_ config: FloconDashboardConfig) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try #require(String(data: encoder.encode(DashboardRemote.make(config).remote), encoding: .utf8))
}

private func message(_ method: String, _ body: String) -> FloconMessageFromServer {
    let json = try! JSONSerialization.data(withJSONObject: ["plugin": "Dashboard", "method": method, "body": body])
    return try! JSONDecoder().decode(FloconMessageFromServer.self, from: json)
}

@Suite struct FloconDashboardTests {
    @Test func encodesLikeTheAndroidSDK() throws {
        let registered = RegisteredDashboards()
        startDashboard(
            id: "main",
            contents: [
                FloconSection("User") {
                    FloconText("name", "Florent", color: 0xFFFF0000)
                    FloconLabel("actions")
                    FloconButton("Log out", id: "logout") {}
                    FloconTextField(id: "rename", label: "Rename", placeholder: "name", value: "Florent")
                    FloconCheckBox(id: "dark", label: "Dark", value: true)
                    FloconPlainText("lorem", "ipsum")
                    FloconJSON("json", "{}")
                    FloconMarkdown("md", "# Title")
                    FloconHTML("html", "<b>bold</b>")
                }.content,
                FloconForm("Create", submitText: "Go", onSubmitted: { _ in }) {
                    FloconTextField(id: "input", label: "Input", value: "")
                }.content,
            ],
            register: registered.append
        ).cancel()

        let config = try #require(registered.configs.first)
        let expected = #"""
        {"containers":[\#
        {"containerConfig":{"containerType":"SECTION"},"elements":[\#
        {"text":{"color":-65536,"label":"name","value":"Florent"}},\#
        {"label":{"label":"actions"}},\#
        {"button":{"id":"main_logout","text":"Log out"}},\#
        {"textField":{"id":"main_rename","label":"Rename","placeHolder":"name","value":"Florent"}},\#
        {"checkBox":{"id":"main_dark","label":"Dark","value":true}},\#
        {"plainText":{"label":"lorem","type":"text","value":"ipsum"}},\#
        {"plainText":{"label":"json","type":"json","value":"{}"}},\#
        {"markdown":{"label":"md","value":"# Title"}},\#
        {"html":{"label":"html","value":"<b>bold</b>"}}],"name":"User"},\#
        {"containerConfig":{"containerType":"FORM","formId":"main_form_Create","submitText":"Go"},"elements":[\#
        {"textField":{"id":"main_input","label":"Input","value":""}}],"name":"Create"}],\#
        "dashboardId":"main"}
        """#
        #expect(try encode(config) == expected)
    }

    @Test func sendsTheDashboardAndResendsItOnConnection() throws {
        let sender = RecordingSender()
        let plugin = FloconDashboardPlugin(sender: sender)
        plugin.register(FloconDashboardConfig(id: "main", containers: []))
        plugin.onConnectedToServer()

        #expect(sender.messages.count == 2)
        #expect(sender.messages.allSatisfy { $0.plugin == "dashboard" && $0.method == "update" })
        let body = try #require(sender.messages.last?.body)
        let json = try #require(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
        #expect(json["dashboardId"] as? String == "main")
        #expect((json["containers"] as? [Any])?.isEmpty == true)
    }

    @Test func runsTheActionsSentByTheDesktop() async throws {
        let (events, continuation) = AsyncStream<String>.makeStream()
        let plugin = FloconDashboardPlugin(sender: RecordingSender())
        startDashboard(
            id: "main",
            contents: [
                FloconSection("User") {
                    FloconButton("Log out", id: "logout") { continuation.yield("clicked") }
                    FloconTextField(id: "rename", label: "Rename", value: "") { continuation.yield("text \($0)") }
                    FloconCheckBox(id: "dark", label: "Dark", value: false) { continuation.yield("check \($0)") }
                }.content,
                FloconForm("Create", onSubmitted: { values in
                    continuation.yield("form " + values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ","))
                }) {
                    FloconTextField(id: "input", label: "Input", value: "")
                    FloconCheckBox(id: "admin", label: "Admin", value: false)
                }.content,
            ],
            register: plugin.register
        ).cancel()

        var iterator = events.makeAsyncIterator()
        plugin.onMessageReceived(message("onClick", "main_logout"))
        #expect(await iterator.next() == "clicked")
        plugin.onMessageReceived(message("onTextFieldSubmitted", #"{"id":"main_rename","value":"Flo"}"#))
        #expect(await iterator.next() == "text Flo")
        plugin.onMessageReceived(message("onCheckBoxValueChanged", #"{"id":"main_dark","value":true}"#))
        #expect(await iterator.next() == "check true")
        plugin.onMessageReceived(message(
            "onFormSubmitted",
            #"{"id":"main_form_Create","values":{"main_input":"hello","main_admin":"true"}}"#
        ))
        #expect(await iterator.next() == "form admin=true,input=hello")
    }

    @Test func updatesTheDashboardWhenAPublisherEmits() throws {
        let registered = RegisteredDashboards()
        let user = CurrentValueSubject<String, Never>("Florent")
        let token = PassthroughSubject<String, Never>()

        let handle = startDashboard(
            id: "main",
            contents: [
                FloconSection("User", publisher: user) { FloconText("name", $0) }.content,
                FloconSection("Token", publisher: token) { FloconText("token", $0) }.content,
            ],
            register: registered.append
        )
        // waits for every section to have a value
        #expect(registered.configs.isEmpty)

        token.send("abc")
        user.send("David")
        #expect(registered.configs.count == 2)
        let last = try #require(registered.configs.last)
        #expect(try encode(last).contains(#""value":"David""#))
        #expect(try encode(last).contains(#""value":"abc""#))

        handle.cancel()
        user.send("Guillaume")
        #expect(registered.configs.count == 2)
    }
}
