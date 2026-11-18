import Foundation

extension FloconFeature where Options == Void {
    /// Sends what happens in the web views of the app: console messages, page events and bridge calls.
    /// See ``FloconWebViewPlugin``.
    public static var webView: FloconFeature<Void> { .init(.webView) }
}
