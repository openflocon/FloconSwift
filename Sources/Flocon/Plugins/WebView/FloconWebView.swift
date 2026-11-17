import Foundation

/// Level of a console message of a web view.
public enum WebViewConsoleLevel: String, Sendable, Hashable {
    case log
    case debug
    case info
    case warn
    case error
}

/// Type of a page event of a web view.
public enum WebViewPageEventType: String, Sendable, Hashable {
    /// A page started loading.
    case pageStarted = "page_started"
    /// A page finished loading.
    case pageFinished = "page_finished"
    /// The web view navigated to another url.
    case navigation
    /// The page could not be loaded, for example without network.
    case error
    /// The server answered with an HTTP error status.
    case httpError = "http_error"
    /// The TLS handshake failed, for example with an invalid certificate.
    case sslError = "ssl_error"
}
