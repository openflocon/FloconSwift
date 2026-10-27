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
