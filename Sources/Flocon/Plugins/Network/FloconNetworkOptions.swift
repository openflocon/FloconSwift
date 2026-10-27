import Foundation

/// Options of the network interception, set when installing ``FloconFeature/network``.
///
/// ```swift
/// startFlocon { flocon in
///     flocon.install(.network) { options in
///         options.shouldLog = { request in request.url?.host != "analytics.example.com" }
///         options.isImage = { request, _ in request.url?.path.hasPrefix("/images/") == true }
///     }
/// }
/// ```
public struct FloconNetworkOptions: Sendable {
    /// Returns whether a request is sent to the desktop app. All requests are by default.
    public var shouldLog: @Sendable (URLRequest) -> Bool
    /// Returns whether a response is an image, in addition to the `Content-Type: image/*` check.
    ///
    /// The body of an image is not sent: the desktop app downloads the image from its URL.
    public var isImage: (@Sendable (URLRequest, HTTPURLResponse) -> Bool)?

    /// Creates network options.
    ///
    /// - Parameters:
    ///   - shouldLog: Returns whether a request is sent to the desktop app. Defaults to all requests.
    ///   - isImage: Returns whether a response is an image, in addition to the
    ///     `Content-Type: image/*` check. Defaults to `nil`.
    public init(
        shouldLog: @escaping @Sendable (URLRequest) -> Bool = { _ in true },
        isImage: (@Sendable (URLRequest, HTTPURLResponse) -> Bool)? = nil
    ) {
        self.shouldLog = shouldLog
        self.isImage = isImage
    }
}

private enum FloconNetworkState {
    static let lock = NSLock()
    nonisolated(unsafe) static var options = FloconNetworkOptions()
}

extension FloconNetworkOptions {
    static var current: FloconNetworkOptions {
        FloconNetworkState.lock.lock(); defer { FloconNetworkState.lock.unlock() }
        return FloconNetworkState.options
    }
}

// MARK: - Public API

extension Flocon {
    /// Sets the options of the network interception, used for the requests started after this call.
    ///
    /// - Parameter options: The options given to ``FloconBuilder/install(_:_:)`` for ``FloconFeature/network``.
    static func setNetworkOptions(_ options: FloconNetworkOptions) {
        FloconNetworkState.lock.lock(); defer { FloconNetworkState.lock.unlock() }
        FloconNetworkState.options = options
    }

    /// Sends the calls of `URLSession.shared` to the desktop app.
    ///
    /// Sessions created with their own configuration are not affected: create them with
    /// ``Foundation/URLSessionConfiguration/withFlocon()`` instead.
    public static func interceptSharedSession() {
        URLProtocol.registerClass(FloconURLProtocol.self)
    }
}

extension URLSessionConfiguration {
    /// Sends the calls of the sessions created with this configuration to the desktop app.
    ///
    /// ```swift
    /// let session = URLSession(configuration: .default.withFlocon())
    ///
    /// // Alamofire
    /// let session = Session(configuration: URLSessionConfiguration.default.withFlocon())
    ///
    /// // Kingfisher
    /// KingfisherManager.shared.downloader.sessionConfiguration = .default.withFlocon()
    /// ```
    ///
    /// - Returns: The same configuration, with the Flocon interceptor added to its protocol classes.
    public func withFlocon() -> URLSessionConfiguration {
        var classes = protocolClasses ?? []
        if !classes.contains(where: { $0 == FloconURLProtocol.self }) {
            classes.insert(FloconURLProtocol.self, at: 0)
        }
        protocolClasses = classes
        return self
    }
}
