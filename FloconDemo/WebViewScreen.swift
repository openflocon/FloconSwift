import Flocon
import SwiftUI
import WebKit

struct WebViewScreen: View {
    var body: some View {
        SampleScreenContainer(screen: .webView) {
            SampleWebView()
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(SampleTheme.line))
            SampleInfoCard(
                text: "Console messages and uncaught errors are captured by attach. Page events and the calls to the app bridge are logged by the sample. See Flocon > WebView.",
                tint: SampleTheme.accent
            )
        }
    }
}

private struct SampleWebView: UIViewRepresentable {
    static let webViewId = "sample"

    private static let html = """
    <html>
    <head><meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
    body { font: -apple-system-body; background: #151515; color: #ECECEC; padding: 8px; }
    button { display: block; width: 100%; margin: 8px 0; padding: 10px; font: inherit; border-radius: 10px; border: 0; background: #F5B440; color: #1C1405; }
    </style></head>
    <body>
    <button onclick="console.log('Hello from the page', { cart: 2 })">console.log</button>
    <button onclick="console.warn('Slow render: 1200 ms')">console.warn</button>
    <button onclick="missingFunction()">Uncaught error</button>
    <button onclick="window.webkit.messageHandlers.app.postMessage({ method: 'share', text: 'Flocon' })">Bridge call</button>
    </body>
    </html>
    """

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isInspectable = true
        webView.navigationDelegate = context.coordinator
        webView.configuration.userContentController.add(context.coordinator, name: "app")
        Flocon.webViewPlugin.attach(webView, webViewId: Self.webViewId)
        webView.loadHTMLString(Self.html, baseURL: URL(string: "https://sample.flocon"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Flocon.webViewPlugin.logPageEvent(webViewId: webViewId, type: .pageStarted, url: webView.url?.absoluteString)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Flocon.webViewPlugin.logPageEvent(webViewId: webViewId, type: .pageFinished, url: webView.url?.absoluteString)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Flocon.webViewPlugin.logPageEvent(
                webViewId: webViewId,
                type: .error,
                url: webView.url?.absoluteString,
                message: error.localizedDescription
            )
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let body = message.body as? [String: Any]
            Flocon.webViewPlugin.logBridgeCall(
                webViewId: webViewId,
                interfaceName: message.name,
                method: body?["method"] as? String ?? "postMessage",
                arguments: body?["text"] as? String,
                url: message.frameInfo.request.url?.absoluteString
            )
        }

        private var webViewId: String { SampleWebView.webViewId }
    }
}
