import Foundation

/// A mock configured in the Flocon desktop app: the requests it matches receive its response,
/// without reaching the server.
public struct FloconNetworkMock: Sendable, Equatable {
    /// The requests a mock applies to.
    public struct Expectation: Sendable, Equatable {
        /// Regular expression the full URL of the request must match.
        public let urlPattern: String
        /// HTTP method of the request, or `"*"` for any method.
        public let method: String

        private let regex: FloconRegex?

        /// Creates an expectation.
        ///
        /// - Parameters:
        ///   - urlPattern: Regular expression the full URL of the request must match.
        ///   - method: HTTP method of the request, or `"*"` for any method.
        public init(urlPattern: String, method: String) {
            self.urlPattern = urlPattern
            self.method = method
            self.regex = FloconRegex(fullMatch: urlPattern)
        }

        /// Returns whether a request is matched.
        ///
        /// - Parameters:
        ///   - url: Full URL of the request.
        ///   - method: HTTP method of the request.
        /// - Returns: `true` when the whole URL matches ``urlPattern`` and the method matches ``method``.
        public func matches(url: String, method: String) -> Bool {
            guard self.method == "*" || self.method.caseInsensitiveCompare(method) == .orderedSame else { return false }
            return regex?.matches(url) ?? false
        }

        public static func == (lhs: Expectation, rhs: Expectation) -> Bool {
            lhs.urlPattern == rhs.urlPattern && lhs.method == rhs.method
        }
    }

    /// The requests this mock applies to.
    public let expectation: Expectation
    /// The response returned to the app.
    public let response: FloconNetworkMockResponse
    /// Delay before the response is returned, in milliseconds.
    public let delayMs: Int64

    /// Creates a mock.
    ///
    /// - Parameters:
    ///   - expectation: The requests this mock applies to.
    ///   - response: The response returned to the app.
    ///   - delayMs: Delay before the response is returned, in milliseconds. Defaults to `0`.
    public init(expectation: Expectation, response: FloconNetworkMockResponse, delayMs: Int64 = 0) {
        self.expectation = expectation
        self.response = response
        self.delayMs = delayMs
    }
}
