#if canImport(WebKit)
import Foundation
import WebKit

/// Receives the console messages posted by the script added by ``FloconWebViewPlugin/attach(_:webViewId:)``,
/// one handler per `WKUserContentController`.
final class FloconWebViewConsoleHandler: NSObject, WKScriptMessageHandler {
    static let messageName = "floconConsole"

    @MainActor private static let handlers = NSMapTable<WKUserContentController, FloconWebViewConsoleHandler>.weakToWeakObjects()

    static let script = """
    (function () {
        if (window.__floconConsole) { return; }
        window.__floconConsole = true;
        var handler = window.webkit.messageHandlers.\(messageName);
        function text(value) {
            if (typeof value === "string") { return value; }
            if (value instanceof Error) { return value.stack ? value + "\\n" + value.stack : String(value); }
            try {
                var json = JSON.stringify(value);
                return json === undefined ? String(value) : json;
            } catch (e) {
                return String(value);
            }
        }
        function post(body) {
            try { handler.postMessage(body); } catch (e) {}
        }
        ["log", "debug", "info", "warn", "error"].forEach(function (level) {
            var original = console[level];
            console[level] = function () {
                post({ level: level, message: Array.prototype.map.call(arguments, text).join(" ") });
                return original.apply(console, arguments);
            };
        });
        window.addEventListener("error", function (event) {
            post({ level: "error", message: event.message, sourceId: event.filename, lineNumber: event.lineno });
        });
        window.addEventListener("unhandledrejection", function (event) {
            post({ level: "error", message: "Unhandled rejection: " + text(event.reason) });
        });
    })();
    """

    let webViewIds = NSMapTable<WKWebView, NSString>.weakToStrongObjects()
    private var plugin: FloconWebViewPlugin

    private init(plugin: FloconWebViewPlugin) {
        self.plugin = plugin
    }

    @MainActor
    static func handler(for controller: WKUserContentController, plugin: FloconWebViewPlugin) -> FloconWebViewConsoleHandler {
        if let handler = handlers.object(forKey: controller) {
            handler.plugin = plugin
            return handler
        }
        let handler = FloconWebViewConsoleHandler(plugin: plugin)
        controller.removeScriptMessageHandler(forName: messageName)
        controller.add(handler, name: messageName)
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        handlers.setObject(handler, forKey: controller)
        return handler
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView, let webViewId = webViewIds.object(forKey: webView) as String? else { return }
        let url = message.frameInfo.request.url?.absoluteString ?? webView.url?.absoluteString
        Self.log(message.body, url: url, webViewId: webViewId, to: plugin)
    }

    nonisolated static func log(_ body: Any, url: String?, webViewId: String, to plugin: FloconWebViewPlugin) {
        guard let body = body as? [String: Any], let message = body["message"] as? String else { return }
        let sourceId = (body["sourceId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let lineNumber = (body["lineNumber"] as? Int).flatMap { $0 > 0 ? $0 : nil }
        plugin.logConsole(
            webViewId: webViewId,
            level: (body["level"] as? String).flatMap(WebViewConsoleLevel.init(rawValue:)) ?? .log,
            message: message,
            url: url,
            sourceId: sourceId,
            lineNumber: lineNumber
        )
    }
}
#endif
