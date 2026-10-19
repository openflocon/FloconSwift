import Foundation

// MARK: - API for extension libraries

// Used by the libraries that log network calls the SDK cannot intercept itself, such as
// FloconSwiftGrpc. Import it with `@_spi(FloconExtension) import Flocon`.

extension Flocon {
    /// Whether network calls can be logged: ``initialize(config:)`` has been called.
    ///
    /// Interceptors check it to do nothing before the SDK is started.
    @_spi(FloconExtension)
    public static var isNetworkLoggingEnabled: Bool {
        shared.client?.networkPlugin != nil
    }

    /// Logs the request of a network call.
    ///
    /// Log its response later with ``logNetworkResponse(callId:networkType:durationMs:httpCode:grpcStatus:contentType:body:headers:size:error:)``,
    /// using the same `callId`.
    ///
    /// - Parameters:
    ///   - callId: Unique identifier of the call, shared by its request and response.
    ///   - networkType: Kind of call shown in the desktop app, such as `"http"` or `"grpc"`.
    ///   - url: URL of the call; for gRPC, the authority of the server (`host:port`).
    ///   - method: HTTP method, or the full name of the gRPC method (`package.Service/Method`).
    ///   - startTime: When the call started.
    ///   - headers: Headers or metadata of the request.
    ///   - body: Body of the request, as text.
    ///   - size: Size of the request body, in bytes.
    @_spi(FloconExtension)
    public static func logNetworkRequest(
        callId: String,
        networkType: String,
        url: String,
        method: String,
        startTime: Date,
        headers: [String: String],
        body: String?,
        size: Int64?
    ) {
        shared.client?.networkPlugin?.logRequest(
            FloconNetworkCallRequestRemote(
                floconCallId: callId,
                floconNetworkType: networkType,
                url: url,
                method: method,
                startTime: Int64(startTime.timeIntervalSince1970 * 1000),
                requestHeaders: headers,
                requestBody: body,
                requestSize: size,
                isMocked: false
            )
        )
    }

    /// Logs the response of a network call whose request was logged with
    /// ``logNetworkRequest(callId:networkType:url:method:startTime:headers:body:size:)``.
    ///
    /// - Parameters:
    ///   - callId: Identifier given to the request.
    ///   - networkType: Kind of call, the same as for the request.
    ///   - durationMs: Duration of the call, in milliseconds.
    ///   - httpCode: HTTP status code, `nil` for gRPC.
    ///   - grpcStatus: Name of the gRPC status code (`OK`, `NOT_FOUND`…), `nil` for HTTP.
    ///   - contentType: Content type of the response.
    ///   - body: Body of the response, as text.
    ///   - headers: Headers or metadata of the response.
    ///   - size: Size of the response body, in bytes.
    ///   - error: Description of the error, when the call failed without a response.
    @_spi(FloconExtension)
    public static func logNetworkResponse(
        callId: String,
        networkType: String,
        durationMs: Double,
        httpCode: Int?,
        grpcStatus: String?,
        contentType: String?,
        body: String?,
        headers: [String: String],
        size: Int64?,
        error: String?
    ) {
        shared.client?.networkPlugin?.logResponse(
            FloconNetworkCallResponseRemote(
                floconCallId: callId,
                durationMs: durationMs,
                floconNetworkType: networkType,
                isMocked: false,
                response: FloconNetworkResponse(
                    httpCode: httpCode,
                    contentType: contentType,
                    body: body,
                    headers: headers,
                    size: size,
                    grpcStatus: grpcStatus,
                    error: error,
                    requestHeaders: nil,
                    isImage: false
                )
            )
        )
    }
}
