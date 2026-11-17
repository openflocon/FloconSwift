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

private func items(_ body: String) throws -> [[String: Any]] {
    try #require(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [[String: Any]])
}

private func now() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}

@Suite struct FloconWebViewTests {
    private func makePlugin() -> (FloconWebViewPlugin, RecordingSender) {
        let sender = RecordingSender()
        return (FloconWebViewPlugin(sender: sender), sender)
    }

    @Test func consoleLogIsSentAsAnArrayWithTheProtocolKeys() throws {
        let (plugin, sender) = makePlugin()
        let before = now()

        plugin.logConsole(
            webViewId: "checkout",
            level: .error,
            message: "Uncaught TypeError: x is undefined",
            url: "https://example.com/pay",
            sourceId: "https://example.com/app.js",
            lineNumber: 42
        )

        let message = try #require(sender.messages.first)
        #expect(sender.messages.count == 1)
        #expect(message.plugin == "webview")
        #expect(message.method == "add_console_logs")
        let body = try items(message.body)
        #expect(body.count == 1)
        let item = body[0]
        #expect(UUID(uuidString: try #require(item["id"] as? String)) != nil)
        #expect(item["web_view_id"] as? String == "checkout")
        #expect(item["url"] as? String == "https://example.com/pay")
        #expect(item["level"] as? String == "error")
        #expect(item["message"] as? String == "Uncaught TypeError: x is undefined")
        #expect(item["source_id"] as? String == "https://example.com/app.js")
        #expect(item["line_number"] as? Int == 42)
        let createdAt = try #require(item["created_at"] as? Int64)
        #expect(createdAt >= before && createdAt <= now())
    }

    @Test func consoleLevelsUseTheWireNames() throws {
        let (plugin, sender) = makePlugin()

        for level in [WebViewConsoleLevel.log, .debug, .info, .warn, .error] {
            plugin.logConsole(webViewId: "w", level: level, message: "m")
        }

        let levels = try sender.messages.map { try items($0.body)[0]["level"] as? String }
        #expect(levels == ["log", "debug", "info", "warn", "error"])
    }

    @Test func pageEventIsSentWithTheProtocolKeys() throws {
        let (plugin, sender) = makePlugin()

        plugin.logPageEvent(
            webViewId: "checkout",
            type: .httpError,
            url: "https://example.com/pay",
            message: "Not Found",
            statusCode: 404
        )

        let message = try #require(sender.messages.first)
        #expect(message.plugin == "webview")
        #expect(message.method == "add_page_events")
        let item = try #require(try items(message.body).first)
        #expect(item["web_view_id"] as? String == "checkout")
        #expect(item["url"] as? String == "https://example.com/pay")
        #expect(item["type"] as? String == "http_error")
        #expect(item["message"] as? String == "Not Found")
        #expect(item["status_code"] as? Int == 404)
        #expect(item["created_at"] is Int64)
        #expect(item["id"] is String)
    }

    @Test func pageEventTypesUseTheWireNames() throws {
        let (plugin, sender) = makePlugin()
        let types: [WebViewPageEventType] = [.pageStarted, .pageFinished, .navigation, .error, .httpError, .sslError]

        for type in types {
            plugin.logPageEvent(webViewId: "w", type: type)
        }

        let names = try sender.messages.map { try items($0.body)[0]["type"] as? String }
        #expect(names == ["page_started", "page_finished", "navigation", "error", "http_error", "ssl_error"])
    }

    @Test func bridgeCallIsSentWithTheProtocolKeys() throws {
        let (plugin, sender) = makePlugin()

        plugin.logBridgeCall(
            webViewId: "checkout",
            interfaceName: "app",
            method: "share",
            arguments: #"{"text":"hello"}"#,
            result: "true",
            url: "https://example.com/pay"
        )

        let message = try #require(sender.messages.first)
        #expect(message.plugin == "webview")
        #expect(message.method == "add_bridge_calls")
        let item = try #require(try items(message.body).first)
        #expect(item["web_view_id"] as? String == "checkout")
        #expect(item["interface_name"] as? String == "app")
        #expect(item["method"] as? String == "share")
        #expect(item["arguments"] as? String == #"{"text":"hello"}"#)
        #expect(item["result"] as? String == "true")
        #expect(item["url"] as? String == "https://example.com/pay")
        #expect(item["created_at"] is Int64)
        #expect(item["id"] is String)
    }

    @Test func missingOptionalValuesAreOmitted() throws {
        let (plugin, sender) = makePlugin()

        plugin.logConsole(webViewId: "w", level: .log, message: "m")
        plugin.logPageEvent(webViewId: "w", type: .pageStarted)
        plugin.logBridgeCall(webViewId: "w", interfaceName: "app", method: "close")

        let bodies = try sender.messages.map { try items($0.body)[0] }
        #expect(Set(bodies[0].keys) == ["id", "web_view_id", "level", "message", "created_at"])
        #expect(Set(bodies[1].keys) == ["id", "web_view_id", "type", "created_at"])
        #expect(Set(bodies[2].keys) == ["id", "web_view_id", "interface_name", "method", "created_at"])
    }

    @Test func eachItemHasItsOwnId() throws {
        let (plugin, sender) = makePlugin()

        plugin.logConsole(webViewId: "w", level: .log, message: "a")
        plugin.logConsole(webViewId: "w", level: .log, message: "b")

        let ids = try sender.messages.map { try items($0.body)[0]["id"] as? String }
        #expect(ids.count == 2 && ids[0] != ids[1])
    }

    @Test func nothingIsSentOnConnection() {
        let (plugin, sender) = makePlugin()

        plugin.onConnectedToServer()

        #expect(sender.messages.isEmpty)
    }

    @Test func notInstalledPluginDoesNothing() {
        Flocon.webViewPlugin.logConsole(webViewId: "w", level: .error, message: "m")
        Flocon.webViewPlugin.logPageEvent(webViewId: "w", type: .pageFinished, url: "https://example.com")
        Flocon.webViewPlugin.logBridgeCall(webViewId: "w", interfaceName: "app", method: "close")
        #expect(Flocon.shared.webViewPlugin == nil)
    }

    @Test func webViewIsAFeatureKind() {
        #expect(FloconFeatureKind.allCases.contains(.webView))
        var builder = FloconBuilder()
        builder.install(.webView)
        #expect(builder.features.contains(.webView))
    }
}
