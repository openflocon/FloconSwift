import Foundation
import Testing
#if canImport(WebKit)
import WebKit
#endif
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

#if canImport(WebKit)
@Suite struct FloconWebViewConsoleTests {
    @Test func consoleMessageIsLoggedWithItsLevelAndPosition() throws {
        let sender = RecordingSender()
        let plugin = FloconWebViewPlugin(sender: sender)

        FloconWebViewConsoleHandler.log(
            ["level": "warn", "message": "slow render", "sourceId": "https://example.com/app.js", "lineNumber": 12],
            url: "https://example.com",
            webViewId: "checkout",
            to: plugin
        )

        let message = try #require(sender.messages.first)
        #expect(message.method == "add_console_logs")
        let item = try #require(try items(message.body).first)
        #expect(item["web_view_id"] as? String == "checkout")
        #expect(item["level"] as? String == "warn")
        #expect(item["message"] as? String == "slow render")
        #expect(item["source_id"] as? String == "https://example.com/app.js")
        #expect(item["line_number"] as? Int == 12)
        #expect(item["url"] as? String == "https://example.com")
    }

    @Test func unknownLevelIsLoggedAsLog() throws {
        let sender = RecordingSender()
        let plugin = FloconWebViewPlugin(sender: sender)

        FloconWebViewConsoleHandler.log(["level": "trace", "message": "m"], url: nil, webViewId: "w", to: plugin)

        let message = try #require(sender.messages.first)
        #expect(try items(message.body).first?["level"] as? String == "log")
    }

    @Test func bodyWithoutMessageIsIgnored() {
        let sender = RecordingSender()
        let plugin = FloconWebViewPlugin(sender: sender)

        FloconWebViewConsoleHandler.log("not a dictionary", url: nil, webViewId: "w", to: plugin)
        FloconWebViewConsoleHandler.log(["level": "log"], url: nil, webViewId: "w", to: plugin)

        #expect(sender.messages.isEmpty)
    }

    @MainActor
    @Test func attachedWebViewSendsConsoleMessagesAndErrors() async throws {
        let sender = RecordingSender()
        let plugin = FloconWebViewPlugin(sender: sender)
        let webView = WKWebView()
        plugin.attach(webView, webViewId: "checkout")
        plugin.attach(webView, webViewId: "checkout")

        webView.loadHTMLString(
            """
            <script>
            console.info("ready", {a: 1}, 2);
            console.error(new Error("boom"));
            undefinedFunction();
            </script>
            """,
            baseURL: URL(string: "https://example.com/page")
        )

        for _ in 0..<100 where sender.messages.count < 3 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let bodies = try sender.messages.compactMap { try items($0.body).first }
        #expect(bodies.count == 3)
        #expect(bodies.map { $0["level"] as? String } == ["info", "error", "error"])
        #expect(bodies.first?["message"] as? String == #"ready {"a":1} 2"#)
        #expect((bodies[1]["message"] as? String)?.contains("boom") == true)
        #expect((bodies[2]["message"] as? String)?.contains("undefinedFunction") == true)
        #expect(bodies[2]["line_number"] is Int)
        #expect(bodies.allSatisfy { $0["web_view_id"] as? String == "checkout" })
        #expect(bodies.allSatisfy { $0["url"] as? String == "https://example.com/page" })
    }

    @MainActor
    @Test func webViewsSharingAControllerKeepTheirOwnId() async throws {
        let sender = RecordingSender()
        let plugin = FloconWebViewPlugin(sender: sender)
        let configuration = WKWebViewConfiguration()
        let first = WKWebView(frame: .zero, configuration: configuration)
        let second = WKWebView(frame: .zero, configuration: configuration)
        #expect(first.configuration.userContentController === second.configuration.userContentController)
        plugin.attach(first, webViewId: "first")
        plugin.attach(second, webViewId: "second")

        first.loadHTMLString("<script>console.log('a')</script>", baseURL: nil)
        second.loadHTMLString("<script>console.log('b')</script>", baseURL: nil)

        for _ in 0..<100 where sender.messages.count < 2 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let ids = try sender.messages.compactMap { try items($0.body).first }
            .reduce(into: [String: String]()) { $0[$1["message"] as? String ?? ""] = $1["web_view_id"] as? String }
        #expect(ids == ["a": "first", "b": "second"])
        #expect(first.configuration.userContentController.userScripts.count == 1)
    }
}
#endif
