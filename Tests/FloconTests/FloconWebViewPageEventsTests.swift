#if canImport(WebKit)
import Foundation
import Network
import Testing
import WebKit
@testable import Flocon

private final class RecordingSender: FloconMessageSender, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [[String: Any]] = []

    var events: [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    var types: [String] { events.compactMap { $0["type"] as? String } }

    func send(plugin: String, method: String, body: String) {
        guard method == "add_page_events",
              let items = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [[String: Any]] else { return }
        lock.lock(); defer { lock.unlock() }
        _events.append(contentsOf: items)
    }
}

/// Answers 404 to every request on a local port: custom URL schemes cannot return an HTTP status to WebKit.
private final class NotFoundServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "NotFoundServer")

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [queue] connection in
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { _, _, _, _ in
                let response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }

    func start() async throws -> URL {
        listener.start(queue: queue)
        for _ in 0..<100 where (listener.port?.rawValue ?? 0) == 0 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let port = try #require(listener.port?.rawValue)
        return try #require(URL(string: "http://localhost:\(port)/missing"))
    }

    deinit {
        listener.cancel()
    }
}

/// Serves `flocon-test://` URLs: `/ok` and `/blocked` load a page, `/offline` and `/untrusted` fail.
private final class TestSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }
        switch url.path {
        case "/offline":
            urlSchemeTask.didFailWithError(URLError(.notConnectedToInternet))
        case "/untrusted":
            urlSchemeTask.didFailWithError(URLError(.serverCertificateUntrusted))
        default:
            guard let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/html"]
            ) else { return }
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(Data("<a id='next' href='flocon-test://host/ok'>next</a>".utf8))
            urlSchemeTask.didFinish()
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

private final class AppNavigationDelegate: NSObject, WKNavigationDelegate {
    var decidedPaths: [String] = []
    var committedCount = 0
    var finishedCount = 0

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        let path = navigationAction.request.url?.path ?? ""
        decidedPaths.append(path)
        decisionHandler(path == "/blocked" ? .cancel : .allow)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        committedCount += 1
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishedCount += 1
    }
}

/// Implements the action policy with preferences, in its `async` form.
private final class AsyncPreferencesDelegate: NSObject, WKNavigationDelegate {
    var decidedPaths: [String] = []

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        let path = navigationAction.request.url?.path ?? ""
        decidedPaths.append(path)
        return (path == "/blocked" ? .cancel : .allow, preferences)
    }
}

/// Only receives the commits: a method the wrapper forwards without implementing it.
private final class CommitOnlyDelegate: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {}
}

@MainActor
@Suite struct FloconWebViewPageEventsTests {
    private let sender = RecordingSender()
    private let schemeHandler = TestSchemeHandler()
    private let appDelegate = AppNavigationDelegate()

    private func makeWebView(delegate: WKNavigationDelegate? = nil) -> (WKWebView, FloconWebViewPlugin) {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: "flocon-test")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = delegate ?? appDelegate
        let plugin = FloconWebViewPlugin(sender: sender)
        plugin.attach(webView, webViewId: "checkout")
        return (webView, plugin)
    }

    private func load(_ webView: WKWebView, _ path: String) {
        webView.load(URLRequest(url: URL(string: "flocon-test://host\(path)")!))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @Test func loadSendsNavigationStartedAndFinished() async throws {
        let (webView, _) = makeWebView()

        load(webView, "/ok")
        try await waitUntil { sender.types.contains("page_finished") }

        #expect(sender.types == ["navigation", "page_started", "page_finished"])
        #expect(sender.events.allSatisfy { $0["url"] as? String == "flocon-test://host/ok" })
        #expect(sender.events.allSatisfy { $0["web_view_id"] as? String == "checkout" })
        #expect(appDelegate.decidedPaths == ["/ok"])
        #expect(appDelegate.committedCount == 1)
        #expect(appDelegate.finishedCount == 1)
    }

    @Test func linkTapSendsANavigation() async throws {
        let (webView, _) = makeWebView()
        load(webView, "/ok")
        try await waitUntil { appDelegate.finishedCount == 1 }

        _ = try await webView.evaluateJavaScript("document.getElementById('next').click()")
        try await waitUntil { appDelegate.finishedCount == 2 }

        #expect(sender.types.filter { $0 == "navigation" }.count == 2)
    }

    @Test func httpErrorSendsItsStatusCode() async throws {
        let server = try NotFoundServer()
        let url = try await server.start()
        let (webView, _) = makeWebView()

        webView.load(URLRequest(url: url))
        try await waitUntil { sender.types.contains("page_finished") }

        let event = try #require(sender.events.first { $0["type"] as? String == "http_error" })
        #expect(event["status_code"] as? Int == 404)
        #expect(event["url"] as? String == url.absoluteString)
        #expect(event["message"] == nil)
    }

    @Test func failedLoadSendsAnError() async throws {
        let (webView, _) = makeWebView()

        load(webView, "/offline")
        try await waitUntil { sender.types.contains("error") }

        let event = try #require(sender.events.first { $0["type"] as? String == "error" })
        #expect(event["url"] as? String == "flocon-test://host/offline")
        #expect(event["message"] as? String == URLError(.notConnectedToInternet).localizedDescription)
    }

    @Test func certificateErrorSendsAnSslError() async throws {
        let (webView, _) = makeWebView()

        load(webView, "/untrusted")
        try await waitUntil { sender.types.contains("ssl_error") }

        #expect(sender.types.contains("ssl_error"))
        #expect(!sender.types.contains("error"))
    }

    @Test func navigationCancelledByTheAppIsNotAnError() async throws {
        let (webView, _) = makeWebView()

        load(webView, "/blocked")
        try await waitUntil { appDelegate.decidedPaths == ["/blocked"] }
        load(webView, "/ok")
        try await waitUntil { sender.types.contains("page_finished") }

        #expect(appDelegate.decidedPaths == ["/blocked", "/ok"])
        #expect(!sender.types.contains("error"))
        #expect(sender.events.filter { $0["type"] as? String == "page_started" }.map { $0["url"] as? String } == ["flocon-test://host/ok"])
    }

    @Test func attachingTwiceKeepsOneWrapper() async throws {
        let (webView, plugin) = makeWebView()
        plugin.attach(webView, webViewId: "checkout")

        load(webView, "/ok")
        try await waitUntil { sender.types.contains("page_finished") }

        #expect(sender.types == ["navigation", "page_started", "page_finished"])
        #expect(appDelegate.finishedCount == 1)
        #expect(webView.navigationDelegate !== appDelegate)
    }

    @Test func webViewWithoutDelegateStillLoads() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: "flocon-test")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        FloconWebViewPlugin(sender: sender).attach(webView, webViewId: "checkout")
        let server = try NotFoundServer()

        webView.load(URLRequest(url: try await server.start()))
        try await waitUntil { sender.types.contains("page_finished") }

        #expect(sender.types == ["page_started", "http_error", "page_finished"])
    }

    @Test func asyncActionPolicyWithPreferencesIsForwarded() async throws {
        let delegate = AsyncPreferencesDelegate()
        let (webView, _) = makeWebView(delegate: delegate)

        load(webView, "/blocked")
        try await waitUntil { delegate.decidedPaths == ["/blocked"] }
        load(webView, "/ok")
        try await waitUntil { sender.types.contains("page_finished") }

        #expect(delegate.decidedPaths == ["/blocked", "/ok"])
        #expect(sender.types == ["navigation", "navigation", "page_started", "page_finished"])
    }

    @Test func delegateReleasedBeforeTheWebViewDoesNotCrash() async throws {
        let (webView, _) = autoreleasepool { makeWebView(delegate: CommitOnlyDelegate()) }

        load(webView, "/ok")
        try await waitUntil { sender.types.contains("page_finished") }

        #expect(sender.types == ["page_started", "page_finished"])
    }
}
#endif
