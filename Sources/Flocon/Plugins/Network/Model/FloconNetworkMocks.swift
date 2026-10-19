import Foundation

/// A fake response, returned to the app instead of the response of the server.
public enum FloconNetworkMockResponse: Sendable, Equatable {
    /// An HTTP response.
    ///
    /// - Parameters:
    ///   - httpCode: HTTP status code.
    ///   - body: Body, as text.
    ///   - mediaType: Content type of the body; empty when unknown.
    ///   - headers: Headers of the response.
    case body(httpCode: Int, body: String, mediaType: String, headers: [String: String])
    /// A failure, without a response.
    ///
    /// - Parameter exception: Name of the error set in the desktop app, such as
    ///   `"java.net.UnknownHostException"`. It is turned into the matching `URLError`.
    case error(exception: String)
}

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

/// A bad network simulated by the Flocon desktop app: latency and random errors added to the calls.
public struct FloconBadNetworkConfig: Sendable, Equatable {
    /// Latency added to the calls.
    public struct Latency: Sendable, Equatable {
        /// Probability, between 0 and 1, that a call is delayed.
        public let triggerProbability: Double
        /// Minimum added latency, in milliseconds.
        public let minLatencyMs: Int64
        /// Maximum added latency, in milliseconds.
        public let maxLatencyMs: Int64

        /// Creates a latency setting.
        ///
        /// - Parameters:
        ///   - triggerProbability: Probability, between 0 and 1, that a call is delayed.
        ///   - minLatencyMs: Minimum added latency, in milliseconds.
        ///   - maxLatencyMs: Maximum added latency, in milliseconds.
        public init(triggerProbability: Double, minLatencyMs: Int64, maxLatencyMs: Int64) {
            self.triggerProbability = triggerProbability
            self.minLatencyMs = minLatencyMs
            self.maxLatencyMs = maxLatencyMs
        }
    }

    /// An error returned instead of the response of the server.
    public struct Error: Sendable, Equatable {
        /// Weight of this error against the other ones: the higher, the more often it is picked.
        public let weight: Double
        /// The response returned to the app.
        public let response: FloconNetworkMockResponse

        /// Creates an error.
        ///
        /// - Parameters:
        ///   - weight: Weight of this error against the other ones.
        ///   - response: The response returned to the app.
        public init(weight: Double, response: FloconNetworkMockResponse) {
            self.weight = weight
            self.response = response
        }
    }

    /// Latency added to the calls.
    public let latency: Latency
    /// Probability, between 0 and 1, that a call fails with one of ``errors``.
    public let errorProbability: Double
    /// The possible errors, one is picked according to its ``Error/weight``.
    public let errors: [Error]

    /// Creates a bad network configuration.
    ///
    /// - Parameters:
    ///   - latency: Latency added to the calls.
    ///   - errorProbability: Probability, between 0 and 1, that a call fails.
    ///   - errors: The possible errors.
    public init(latency: Latency, errorProbability: Double, errors: [Error]) {
        self.latency = latency
        self.errorProbability = errorProbability
        self.errors = errors
    }

    /// Picks the latency to add to a call.
    ///
    /// - Parameter generator: Source of randomness.
    /// - Returns: The latency in milliseconds, or `0` when the call is not delayed.
    func randomLatencyMs<G: RandomNumberGenerator>(using generator: inout G) -> Int64 {
        guard latency.triggerProbability > 0,
              latency.triggerProbability >= 1 || Double.random(in: 0..<1, using: &generator) < latency.triggerProbability
        else { return 0 }
        let low = max(0, latency.minLatencyMs)
        return Int64.random(in: low...max(low, latency.maxLatencyMs), using: &generator)
    }

    /// Picks the error a call fails with, if it fails.
    ///
    /// - Parameter generator: Source of randomness.
    /// - Returns: The error, or `nil` when the call does not fail.
    func randomError<G: RandomNumberGenerator>(using generator: inout G) -> Error? {
        guard errorProbability > 0, !errors.isEmpty,
              Double.random(in: 0..<1, using: &generator) < errorProbability
        else { return nil }
        let totalWeight = errors.reduce(0) { $0 + max(0, $1.weight) }
        guard totalWeight > 0 else { return errors[0] }
        var remaining = Double.random(in: 0..<totalWeight, using: &generator)
        for error in errors {
            remaining -= max(0, error.weight)
            if remaining < 0 { return error }
        }
        return errors[errors.count - 1]
    }
}

extension FloconNetworkMockResponse {
    /// The `URLError` matching the name of an error set in the desktop app.
    ///
    /// The desktop app offers JVM exception names; the closest `URLError` code is used,
    /// and the name is kept as the description of the error.
    static func urlError(forException exception: String) -> URLError {
        let name = exception.split(separator: ".").last.map(String.init) ?? exception
        let code: URLError.Code
        switch name {
        case "UnknownHostException":
            code = .cannotFindHost
        case "ConnectException", "NoRouteToHostException":
            code = .cannotConnectToHost
        case _ where name.contains("Timeout"):
            code = .timedOut
        case _ where name.hasPrefix("SSL"):
            code = .secureConnectionFailed
        default:
            code = .networkConnectionLost
        }
        return URLError(code, userInfo: [NSLocalizedDescriptionKey: exception])
    }
}

/// A compiled regular expression that must match the whole text.
private final class FloconRegex: @unchecked Sendable {
    // NSRegularExpression is immutable and safe to share between threads.
    private let expression: NSRegularExpression

    init?(fullMatch pattern: String) {
        guard let expression = try? NSRegularExpression(pattern: "^(?:\(pattern))$") else {
            FloconLogger.log("Invalid mock url pattern: \(pattern)")
            return nil
        }
        self.expression = expression
    }

    func matches(_ text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
