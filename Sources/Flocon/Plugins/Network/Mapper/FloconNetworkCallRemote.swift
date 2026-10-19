import Foundation

/// JSON format of a request sent to the desktop app.
///
/// Optional values are encoded as an explicit `null`, not omitted.
struct FloconNetworkCallRequestRemote: Encodable {
    let floconCallId: String?
    let floconNetworkType: String?

    let url: String?
    let method: String?
    let startTime: Int64?
    let requestHeaders: [String: String]?
    let requestBody: String?
    let requestSize: Int64?
    let isMocked: Bool?

    enum CodingKeys: String, CodingKey {
        case floconCallId, floconNetworkType, url, method, startTime
        case requestHeaders, requestBody, requestSize, isMocked
    }

    init(_ call: FloconNetworkCallRequest) {
        floconCallId = call.callId
        floconNetworkType = call.networkType
        url = call.request.url
        method = call.request.method
        startTime = Int64(call.request.startTime.timeIntervalSince1970 * 1000)
        requestHeaders = call.request.headers
        requestBody = call.request.body
        requestSize = call.request.size
        isMocked = call.isMocked
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(floconCallId, forKey: .floconCallId)
        try c.encode(floconNetworkType, forKey: .floconNetworkType)
        try c.encode(url, forKey: .url)
        try c.encode(method, forKey: .method)
        try c.encode(startTime, forKey: .startTime)
        try c.encode(requestHeaders, forKey: .requestHeaders)
        try c.encode(requestBody, forKey: .requestBody)
        try c.encode(requestSize, forKey: .requestSize)
        try c.encode(isMocked, forKey: .isMocked)
    }
}

/// JSON format of a response sent to the desktop app: a flat object, matched with its
/// request by `floconCallId`.
struct FloconNetworkCallResponseRemote: Encodable {
    let floconCallId: String
    let durationMs: Double
    let floconNetworkType: String
    let isMocked: Bool
    let response: FloconNetworkResponse

    init(_ call: FloconNetworkCallResponse) {
        floconCallId = call.callId
        durationMs = call.durationMs
        floconNetworkType = call.networkType
        isMocked = call.isMocked
        response = call.response
    }

    enum CodingKeys: String, CodingKey {
        case floconCallId, floconNetworkType, isMocked, durationMs, isImage
        case requestHeaders
        case responseHttpCode, responseContentType, responseBody
        case responseHeaders, responseSize, responseGrpcStatus, responseError
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(floconCallId, forKey: .floconCallId)
        try c.encode(floconNetworkType, forKey: .floconNetworkType)
        try c.encode(isMocked, forKey: .isMocked)
        try c.encode(durationMs, forKey: .durationMs)
        try c.encode(response.isImage, forKey: .isImage)
        try c.encode(response.requestHeaders, forKey: .requestHeaders)
        try c.encode(response.httpCode, forKey: .responseHttpCode)
        try c.encode(response.contentType, forKey: .responseContentType)
        try c.encode(response.body, forKey: .responseBody)
        try c.encode(response.headers, forKey: .responseHeaders)
        try c.encode(response.size, forKey: .responseSize)
        try c.encode(response.grpcStatus, forKey: .responseGrpcStatus)
        try c.encode(response.error, forKey: .responseError)
    }
}
