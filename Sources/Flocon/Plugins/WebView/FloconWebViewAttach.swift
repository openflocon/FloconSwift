#if canImport(WebKit)
import Foundation
import WebKit

extension FloconWebViewPlugin {
    /// Sends the console messages, the uncaught errors and the page events of a web view.
    ///
    /// Call it once per web view, after starting Flocon, after setting your own `navigationDelegate`
    /// and before loading a page. Before Flocon is started, or if the plugin is not installed, the web
    /// view is left untouched.
    ///
    /// - Console: a user script and a script message handler are added to its `userContentController`.
    ///   Web views that share a `userContentController` keep their own id. The messages of every frame
    ///   are sent, with the URL of their frame. Web Inspector shows the added script as the caller of
    ///   the `console` functions.
    /// - Page events: the `navigationDelegate` is wrapped. Every call is forwarded to your delegate,
    ///   so the behavior of the web view does not change, and `navigationDelegate` now returns the
    ///   wrapper. A delegate set after `attach` replaces the wrapper, and the page events are no longer
    ///   sent. Navigations are only sent when your delegate decides the policy of navigation actions.
    ///
    /// ```swift
    /// let webView = WKWebView()
    /// Flocon.webViewPlugin.attach(webView, webViewId: "checkout")
    /// webView.load(URLRequest(url: url))
    /// ```
    ///
    /// - Parameters:
    ///   - webView: The web view.
    ///   - webViewId: Stable id of the web view, shown in the desktop app.
    @MainActor
    public func attach(_ webView: WKWebView, webViewId: String) {
        guard self !== FloconNoOpPlugins.webView else { return }
        FloconWebViewNavigationDelegate.wrap(webView, webViewId: webViewId, plugin: self)
        FloconWebViewConsoleHandler.handler(for: webView.configuration.userContentController, plugin: self)
            .webViewIds.setObject(webViewId as NSString, forKey: webView)
    }
}
#endif
