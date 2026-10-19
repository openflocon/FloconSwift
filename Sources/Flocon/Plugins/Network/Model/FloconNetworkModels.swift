import Foundation

/// A request sent by the app, as shown in the Network section of the Flocon desktop app.
public struct FloconNetworkRequest: Sendable, Equatable {
    /// URL of the request; for gRPC, the server (`host:port`).
    public var url: String
    /// HTTP method, or the full name of a gRPC method (`package.Service/Method`).
    public var method: String
    /// When the request started.
    public var startTime: Date
    /// Headers, or gRPC metadata.
    public var headers: [String: String]
    /// Body, as text.
    public var body: String?
    /// Size of the body, in bytes.
    public var size: Int64?

    /// Creates a request.
    ///
    /// - Parameters:
    ///   - url: URL of the request; for gRPC, the server (`host:port`).
    ///   - method: HTTP method, or the full name of a gRPC method.
    ///   - startTime: When the request started. Defaults to now.
    ///   - headers: Headers, or gRPC metadata.
    ///   - body: Body, as text.
    ///   - size: Size of the body, in bytes.
    public init(
        url: String,
        method: String,
        startTime: Date = Date(),
        headers: [String: String] = [:],
        body: String? = nil,
        size: Int64? = nil
    ) {
        self.url = url
        self.method = method
        self.startTime = startTime
        self.headers = headers
        self.body = body
        self.size = size
    }
}

/// A request to log with ``FloconNetworkPlugin/logRequest(_:)``.
public struct FloconNetworkCallRequest: Sendable, Equatable {
    /// Identifier of the call, shared by its request and its response.
    public var callId: String
    /// Kind of call: `"http"`, `"grpc"`…
    public var networkType: String
    /// Whether the response is a mock, not the response of the server.
    public var isMocked: Bool
    /// The request.
    public var request: FloconNetworkRequest

    /// Creates a request to log.
    ///
    /// - Parameters:
    ///   - callId: Identifier of the call, given to its response too. Defaults to a random UUID.
    ///   - networkType: Kind of call, such as `"http"` or `"grpc"`.
    ///   - isMocked: Whether the response is a mock. Defaults to `false`.
    ///   - request: The request.
    public init(callId: String = UUID().uuidString, networkType: String, isMocked: Bool = false, request: FloconNetworkRequest) {
        self.callId = callId
        self.networkType = networkType
        self.isMocked = isMocked
        self.request = request
    }
}

/// A response received by the app, as shown in the Network section of the Flocon desktop app.
public struct FloconNetworkResponse: Sendable, Equatable {
    /// HTTP status code; `nil` for gRPC, or when the call failed without a response.
    public var httpCode: Int?
    /// Name of the gRPC status code (`OK`, `NOT_FOUND`…); `nil` for HTTP.
    public var grpcStatus: String?
    /// Content type of the response.
    public var contentType: String?
    /// Body, as text.
    public var body: String?
    /// Size of the body, in bytes.
    public var size: Int64?
    /// Headers, or gRPC metadata.
    public var headers: [String: String]
    /// Headers of the request, when they are only known once the response is received.
    public var requestHeaders: [String: String]?
    /// Description of the error, when the call failed.
    public var error: String?
    /// Whether the body is an image: the desktop app then downloads it from the URL of the request.
    public var isImage: Bool

    /// Creates a response.
    ///
    /// - Parameters:
    ///   - httpCode: HTTP status code; `nil` for gRPC, or when the call failed without a response.
    ///   - grpcStatus: Name of the gRPC status code; `nil` for HTTP.
    ///   - contentType: Content type of the response.
    ///   - body: Body, as text.
    ///   - size: Size of the body, in bytes.
    ///   - headers: Headers, or gRPC metadata.
    ///   - requestHeaders: Headers of the request, when they are only known now.
    ///   - error: Description of the error, when the call failed.
    ///   - isImage: Whether the body is an image. Defaults to `false`.
    public init(
        httpCode: Int? = nil,
        grpcStatus: String? = nil,
        contentType: String? = nil,
        body: String? = nil,
        size: Int64? = nil,
        headers: [String: String] = [:],
        requestHeaders: [String: String]? = nil,
        error: String? = nil,
        isImage: Bool = false
    ) {
        self.httpCode = httpCode
        self.grpcStatus = grpcStatus
        self.contentType = contentType
        self.body = body
        self.size = size
        self.headers = headers
        self.requestHeaders = requestHeaders
        self.error = error
        self.isImage = isImage
    }
}

/// A response to log with ``FloconNetworkPlugin/logResponse(_:)``.
public struct FloconNetworkCallResponse: Sendable, Equatable {
    /// Identifier of the call, given to its request.
    public var callId: String
    /// Kind of call, the same as for the request.
    public var networkType: String
    /// Duration of the call, in milliseconds.
    public var durationMs: Double
    /// Whether the response is a mock, not the response of the server.
    public var isMocked: Bool
    /// The response.
    public var response: FloconNetworkResponse

    /// Creates a response to log.
    ///
    /// - Parameters:
    ///   - callId: Identifier given to the request.
    ///   - networkType: Kind of call, the same as for the request.
    ///   - durationMs: Duration of the call, in milliseconds.
    ///   - isMocked: Whether the response is a mock. Defaults to `false`.
    ///   - response: The response.
    public init(callId: String, networkType: String, durationMs: Double, isMocked: Bool = false, response: FloconNetworkResponse) {
        self.callId = callId
        self.networkType = networkType
        self.durationMs = durationMs
        self.isMocked = isMocked
        self.response = response
    }
}
