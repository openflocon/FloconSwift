#if canImport(WebKit)
import Foundation
import ObjectiveC
import WebKit

/// Wraps the `navigationDelegate` of a web view to send its page events, and forwards every call to it.
///
/// The action policy is only answered when the app's delegate answers it, so the default behavior
/// of WebKit is kept otherwise. WebKit reads which methods a delegate answers when it is set: when
/// the app's delegate is released, the wrapper is set again so that WebKit stops calling its methods.
@MainActor
final class FloconWebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private static var associationKey: UInt8 = 0
    nonisolated private static let decideActionPolicyWithPreferences = NSSelectorFromString(
        "webView:decidePolicyForNavigationAction:preferences:decisionHandler:"
    )
    nonisolated private static let decideActionPolicy = NSSelectorFromString("webView:decidePolicyForNavigationAction:decisionHandler:")
    private static let decideResponsePolicy = NSSelectorFromString("webView:decidePolicyForNavigationResponse:decisionHandler:")
    private static let webKitErrorDomain = "WebKitErrorDomain"
    private static let frameLoadInterruptedByPolicyChange = 102

    nonisolated(unsafe) private weak var delegate: WKNavigationDelegate?
    private weak var webView: WKWebView?
    private var plugin: FloconWebViewPlugin
    private var webViewId: String
    private var provisionalURL: URL?

    private init(webView: WKWebView, plugin: FloconWebViewPlugin, webViewId: String) {
        self.webView = webView
        self.plugin = plugin
        self.webViewId = webViewId
    }

    static func wrap(_ webView: WKWebView, webViewId: String, plugin: FloconWebViewPlugin) {
        if let wrapper = webView.navigationDelegate as? FloconWebViewNavigationDelegate {
            wrapper.plugin = plugin
            wrapper.webViewId = webViewId
            return
        }
        let wrapper = FloconWebViewNavigationDelegate(webView: webView, plugin: plugin, webViewId: webViewId)
        objc_setAssociatedObject(webView, &associationKey, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if let delegate = webView.navigationDelegate {
            wrapper.delegate = delegate
            FloconReleaseObserver.observe(delegate, owner: wrapper) { [weak wrapper] in wrapper?.delegateWasReleased() }
        }
        webView.navigationDelegate = wrapper
    }

    private func delegateWasReleased() {
        guard let webView, webView.navigationDelegate === self else { return }
        webView.navigationDelegate = self
    }

    // MARK: Forwarding

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == Self.decideActionPolicyWithPreferences {
            return delegate?.responds(to: aSelector) == true || delegate?.responds(to: Self.decideActionPolicy) == true
        }
        return super.responds(to: aSelector) || delegate?.responds(to: aSelector) == true
    }

    nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
        delegate?.responds(to: aSelector) == true ? delegate : nil
    }

    // MARK: WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if navigationAction.targetFrame?.isMainFrame == true {
            log(.navigation, url: navigationAction.request.url)
        }
        guard let delegate else { return decisionHandler(.allow, preferences) }
        if delegate.responds(to: Self.decideActionPolicyWithPreferences) {
            delegate.webView?(webView, decidePolicyFor: navigationAction, preferences: preferences, decisionHandler: decisionHandler)
        } else {
            delegate.webView?(webView, decidePolicyFor: navigationAction) { decisionHandler($0, preferences) }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void
    ) {
        if let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            log(.httpError, url: response.url, statusCode: response.statusCode)
        }
        if let delegate, delegate.responds(to: Self.decideResponsePolicy) {
            delegate.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)
        } else {
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        provisionalURL = webView.url
        log(.pageStarted, url: webView.url)
        delegate?.webView?(webView, didStartProvisionalNavigation: navigation)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log(.pageFinished, url: webView.url)
        delegate?.webView?(webView, didFinish: navigation)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logError(error, webView: webView)
        delegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logError(error, webView: webView)
        delegate?.webView?(webView, didFail: navigation, withError: error)
    }

    // MARK: Private

    private func log(_ type: WebViewPageEventType, url: URL?, message: String? = nil, statusCode: Int? = nil) {
        plugin.logPageEvent(webViewId: webViewId, type: type, url: url?.absoluteString, message: message, statusCode: statusCode)
    }

    private func logError(_ error: Error, webView: WKWebView) {
        let error = error as NSError
        guard !Self.isCancellation(error) else { return }
        let url = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL ?? provisionalURL ?? webView.url
        log(Self.isCertificateError(error) ? .sslError : .error, url: url, message: error.localizedDescription)
    }

    private static func isCancellation(_ error: NSError) -> Bool {
        (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == webKitErrorDomain && error.code == frameLoadInterruptedByPolicyChange)
    }

    private static func isCertificateError(_ error: NSError) -> Bool {
        error.domain == NSURLErrorDomain
            && (NSURLErrorClientCertificateRequired...NSURLErrorSecureConnectionFailed).contains(error.code)
    }
}

/// Calls a closure on the main actor when an object is released.
private final class FloconReleaseObserver: @unchecked Sendable {
    private let onRelease: @MainActor @Sendable () -> Void

    private init(onRelease: @escaping @MainActor @Sendable () -> Void) {
        self.onRelease = onRelease
    }

    static func observe(_ object: AnyObject, owner: AnyObject, onRelease: @escaping @MainActor @Sendable () -> Void) {
        let key = UnsafeRawPointer(Unmanaged.passUnretained(owner).toOpaque())
        objc_setAssociatedObject(object, key, FloconReleaseObserver(onRelease: onRelease), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    deinit {
        let onRelease = onRelease
        if Thread.isMainThread {
            MainActor.assumeIsolated { onRelease() }
        } else {
            Task { @MainActor in onRelease() }
        }
    }
}
#endif
