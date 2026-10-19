import Foundation

/// Intercepts the HTTP calls of a session and sends them to the desktop app.
///
/// URLSession has no interceptor chain: this URLProtocol performs the request again in
/// ``FloconInnerSessionRouter``'s session, records the response, and forwards it to the
/// original client.
final class FloconURLProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "FloconURLProtocolHandled"

    private var innerTask: URLSessionDataTask?

    private let callId = UUID().uuidString
    private var startNanos: UInt64 = 0
    private var originalRequest: URLRequest?
    private var plugin: FloconNetworkPlugin?

    private var response: HTTPURLResponse?
    private var receivedData = Data()
    private var reported = false
    private var redirected = false
    private var stopped = false

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {
        // no loop: the requests performed by the inner session are marked
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else { return false }
        guard let scheme = request.url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        // nothing to do before Flocon.initialize()
        guard Flocon.shared.client?.networkPlugin != nil else { return false }
        return FloconNetworkOptions.current.shouldLog(request)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let plugin = Flocon.shared.client?.networkPlugin else {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            return
        }
        self.plugin = plugin
        originalRequest = request

        let startTime = Date()
        startNanos = DispatchTime.now().uptimeNanoseconds

        // The body of an upload is often a stream: read it once, to both log it and send it.
        let bodyData = Self.readBody(of: request)
        var forwarded = request
        if let bodyData {
            forwarded.httpBody = bodyData
            forwarded.httpBodyStream = nil
        }

        plugin.logRequest(
            FloconNetworkCallRequest(
                callId: callId,
                networkType: "http",
                request: FloconNetworkRequest(
                    url: request.url?.absoluteString ?? "",
                    method: request.httpMethod ?? "GET",
                    startTime: startTime,
                    headers: request.allHTTPHeaderFields ?? [:],
                    body: bodyData.flatMap { String(data: $0, encoding: .utf8) },
                    size: bodyData.map { Int64($0.count) }
                )
            )
        )

        let marked = (forwarded as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: marked)

        let task = FloconInnerSessionRouter.shared.makeTask(with: marked as URLRequest, handler: self)
        innerTask = task
        task.resume()
    }

    override func stopLoading() {
        stopped = true
        // didComplete is then called with the cancellation error, which is logged
        innerTask?.cancel()
    }

    // MARK: Inner session callbacks (through FloconInnerSessionRouter)

    func didReceive(
        response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        self.response = response as? HTTPURLResponse
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func didReceive(data: Data) {
        receivedData.append(data)
        client?.urlProtocol(self, didLoad: data)
    }

    func willRedirect(
        task: URLSessionTask,
        response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Log the 3xx response, then let the original client follow the redirect:
        // the new request goes through this protocol again and is logged as a separate call.
        self.response = response
        reportResponse(task: task, error: nil)
        redirected = true

        let next = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.removeProperty(forKey: Self.handledKey, in: next)
        client?.urlProtocol(self, wasRedirectedTo: next as URLRequest, redirectResponse: response)

        completionHandler(nil)
        task.cancel()
    }

    func didComplete(task: URLSessionTask, error: Error?) {
        if redirected { return }

        reportResponse(task: task, error: error)
        guard !stopped else { return }

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    // MARK: Logging

    private func reportResponse(task: URLSessionTask, error: Error?) {
        guard !reported, let plugin else { return }
        reported = true

        let durationMs = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000

        let payload: FloconNetworkResponse
        if let error {
            payload = FloconNetworkResponse(error: error.localizedDescription)
        } else {
            let contentType = response?.value(forHTTPHeaderField: "Content-Type")
            var isImage = contentType?.lowercased().hasPrefix("image/") == true
            if !isImage, let custom = FloconNetworkOptions.current.isImage,
               let originalRequest, let response {
                isImage = custom(originalRequest, response)
            }
            let headers = Self.headersMap(response?.allHeaderFields)
            let requestHeaders = task.currentRequest?.allHTTPHeaderFields

            payload = FloconNetworkResponse(
                httpCode: response?.statusCode,
                contentType: contentType,
                // image bytes are not sent
                body: isImage ? nil : String(data: receivedData, encoding: .utf8),
                size: Int64(receivedData.count),
                headers: headers,
                requestHeaders: requestHeaders,
                isImage: isImage
            )
        }

        plugin.logResponse(
            FloconNetworkCallResponse(callId: callId, networkType: "http", durationMs: durationMs, response: payload)
        )
    }

    // MARK: Helpers

    private static func headersMap(_ fields: [AnyHashable: Any]?) -> [String: String] {
        var result: [String: String] = [:]
        fields?.forEach { key, value in
            result[String(describing: key)] = String(describing: value)
        }
        return result
    }

    private static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var result = Data()
        let chunkSize = 16 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: chunkSize)
            if count <= 0 { break }
            result.append(buffer, count: count)
        }
        return result
    }
}
