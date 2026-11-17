import Foundation

/// Sends what happens in the web views of the app to the Flocon desktop app: console messages,
/// page events and calls from the page to native code.
///
/// Each call takes a `webViewId`, a stable id you choose for each web view, so the desktop app can
/// tell several web views apart.
public final class FloconWebViewPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "webview"
    private static let methodAddConsoleLogs = "add_console_logs"
    private static let methodAddPageEvents = "add_page_events"
    private static let methodAddBridgeCalls = "add_bridge_calls"

    public let pluginName = FloconWebViewPlugin.name
    private weak var sender: FloconMessageSender?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    /// Logs a console message of a page.
    ///
    /// - Parameters:
    ///   - webViewId: Id of the web view.
    ///   - level: Level of the message.
    ///   - message: The message.
    ///   - url: Url of the page when the message was emitted.
    ///   - sourceId: Script that emitted the message.
    ///   - lineNumber: Line in `sourceId`.
    public func logConsole(
        webViewId: String,
        level: WebViewConsoleLevel,
        message: String,
        url: String? = nil,
        sourceId: String? = nil,
        lineNumber: Int? = nil
    ) {
        let item = FloconWebViewConsoleLogRemote(
            id: UUID().uuidString,
            webViewId: webViewId,
            url: url,
            level: level.rawValue,
            message: message,
            sourceId: sourceId,
            lineNumber: lineNumber,
            createdAt: Self.now()
        )
        sender?.send(plugin: pluginName, method: Self.methodAddConsoleLogs, value: [item])
    }

    /// Logs a page event: a page load, a navigation or an error.
    ///
    /// Call it from your `WKNavigationDelegate`, for example ``WebViewPageEventType/pageFinished``
    /// in `webView(_:didFinish:)`.
    ///
    /// - Parameters:
    ///   - webViewId: Id of the web view.
    ///   - type: Type of the event.
    ///   - url: Url concerned by the event.
    ///   - message: Description of the error.
    ///   - statusCode: HTTP status, for ``WebViewPageEventType/httpError``.
    public func logPageEvent(
        webViewId: String,
        type: WebViewPageEventType,
        url: String? = nil,
        message: String? = nil,
        statusCode: Int? = nil
    ) {
        let item = FloconWebViewPageEventRemote(
            id: UUID().uuidString,
            webViewId: webViewId,
            url: url,
            type: type.rawValue,
            message: message,
            statusCode: statusCode,
            createdAt: Self.now()
        )
        sender?.send(plugin: pluginName, method: Self.methodAddPageEvents, value: [item])
    }

    /// Logs a call from the page to native code, for example a message received by a
    /// `WKScriptMessageHandler`.
    ///
    /// - Parameters:
    ///   - webViewId: Id of the web view.
    ///   - interfaceName: Name of the object exposed to the page, for example the name of the message handler.
    ///   - method: Called method.
    ///   - arguments: Arguments, as text.
    ///   - result: Returned value, as text.
    ///   - url: Url of the page.
    public func logBridgeCall(
        webViewId: String,
        interfaceName: String,
        method: String,
        arguments: String? = nil,
        result: String? = nil,
        url: String? = nil
    ) {
        let item = FloconWebViewBridgeCallRemote(
            id: UUID().uuidString,
            webViewId: webViewId,
            url: url,
            interfaceName: interfaceName,
            method: method,
            arguments: arguments,
            result: result,
            createdAt: Self.now()
        )
        sender?.send(plugin: pluginName, method: Self.methodAddBridgeCalls, value: [item])
    }

    /// Nothing is kept: the events are sent when they are logged, then queued by the SDK.
    public func onConnectedToServer() {}

    /// The desktop app is read only: it sends nothing to this plugin.
    public func onMessageReceived(_ message: FloconMessageFromServer) {}

    private static func now() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
