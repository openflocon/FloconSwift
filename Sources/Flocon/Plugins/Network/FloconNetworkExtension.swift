import Foundation

// MARK: - Extension API of 0.2.0

// Kept for the libraries built against FloconSwift 0.2.0, such as FloconSwiftGrpc.
// Use the public API of ``FloconNetworkPlugin`` instead.

extension Flocon {
    /// Whether network calls can be logged: ``initialize(config:)`` has been called.
    @_spi(FloconExtension)
    @available(*, deprecated, message: "Check that Flocon.shared.networkPlugin is not nil")
    public static var isNetworkLoggingEnabled: Bool {
        shared.networkPlugin != nil
    }

    /// Logs the request of a network call.
    @_spi(FloconExtension)
    @available(*, deprecated, message: "Use Flocon.shared.networkPlugin?.logRequest(_:)")
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
        shared.networkPlugin?.logRequest(
            FloconNetworkCallRequest(
                callId: callId,
                networkType: networkType,
                request: FloconNetworkRequest(url: url, method: method, startTime: startTime, headers: headers, body: body, size: size)
            )
        )
    }

    /// Logs the response of a network call.
    @_spi(FloconExtension)
    @available(*, deprecated, message: "Use Flocon.shared.networkPlugin?.logResponse(_:)")
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
        shared.networkPlugin?.logResponse(
            FloconNetworkCallResponse(
                callId: callId,
                networkType: networkType,
                durationMs: durationMs,
                response: FloconNetworkResponse(
                    httpCode: httpCode,
                    grpcStatus: grpcStatus,
                    contentType: contentType,
                    body: body,
                    size: size,
                    headers: headers,
                    error: error
                )
            )
        )
    }
}
