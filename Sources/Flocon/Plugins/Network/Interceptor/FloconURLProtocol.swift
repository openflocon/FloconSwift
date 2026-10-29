import Foundation

/// Intercepts the HTTP calls of a session and sends them to the desktop app.
///
/// URLSession has no interceptor chain: this URLProtocol performs the request again in
/// ``FloconInnerSessionRouter``'s session, records the response, and forwards it to the
/// original client.
///
/// A request matched by a mock, or failed by the bad network simulation, is answered here,
/// without reaching the server.
///
/// Its callbacks come from several threads: the loading thread (`startLoading`, `stopLoading`),
/// the delegate queue of the inner session, and the queue of the simulated delays. The mutable
/// state is therefore kept behind a lock.
final class FloconURLProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "FloconURLProtocolHandled"

    // Set in startLoading, before any other callback can run, then only read.
    private let callId = UUID().uuidString
    private var startNanos: UInt64 = 0
    private var originalRequest: URLRequest?
    private var plugin: FloconNetworkPlugin?
    private var options = FloconNetworkOptions()
    private var isMocked = false

    private struct State {
        var innerTask: URLSessionDataTask?
        var response: HTTPURLResponse?
        var body = FloconBody()
        var isImage = false
        var reported = false
        var redirected = false
        var stopped = false
    }

    private let lock = NSLock()
    private var state = State()

    private func withState<T>(_ body: (inout State) -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body(&state)
    }

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
        options = FloconNetworkOptions.current
        originalRequest = request

        let startTime = Date()
        startNanos = DispatchTime.now().uptimeNanoseconds

        // The body of an upload is often a stream: read it once, to both log it and send it.
        let bodyData = Self.readBody(of: request)
        let forwarded = Self.forwardedRequest(request, body: bodyData)

        let url = request.url?.absoluteString ?? ""
        let method = request.httpMethod ?? "GET"
        let mock = plugin.mock(url: url, method: method)
        isMocked = mock != nil

        plugin.logRequest(
            FloconNetworkCallRequest(
                callId: callId,
                networkType: "http",
                isMocked: isMocked,
                request: FloconNetworkRequest(
                    url: url,
                    method: method,
                    startTime: startTime,
                    headers: request.allHTTPHeaderFields ?? [:],
                    body: bodyData.flatMap { String(data: $0, encoding: .utf8) },
                    size: bodyData.map { Int64($0.count) }
                )
            )
        )

        if let mock {
            after(delayMs: mock.delayMs) { $0.deliver(mock.response) }
            return
        }

        var latencyMs: Int64 = 0
        if let config = plugin.badNetworkConfig {
            var generator = SystemRandomNumberGenerator()
            latencyMs = config.randomLatencyMs(using: &generator)
            if let error = config.randomError(using: &generator) {
                after(delayMs: latencyMs) { $0.deliver(error.response) }
                return
            }
        }

        // swiftlint:disable:next force_cast
        let marked = (forwarded as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: marked)
        let next = marked as URLRequest
        after(delayMs: latencyMs) { $0.startInnerTask(next) }
    }

    override func stopLoading() {
        let task = withState { state -> URLSessionDataTask? in
            state.stopped = true
            return state.innerTask
        }
        // didComplete is then called with the cancellation error, which is logged
        task?.cancel()
    }

    private func startInnerTask(_ request: URLRequest) {
        // under the lock, so that a stopLoading() called meanwhile cancels this task
        lock.lock()
        if state.stopped {
            lock.unlock()
            reportResponse(requestHeaders: nil, error: URLError(.cancelled))
            return
        }
        let task = FloconInnerSessionRouter.shared.makeTask(with: request, handler: self)
        state.innerTask = task
        lock.unlock()
        task.resume()
    }

    /// Runs `work` after a delay, unless the loading is stopped in the meantime.
    private func after(delayMs: Int64, _ work: @escaping @Sendable (FloconURLProtocol) -> Void) {
        let run: @Sendable () -> Void = { [self] in
            if withState({ $0.stopped }) {
                reportResponse(requestHeaders: nil, error: URLError(.cancelled))
            } else {
                work(self)
            }
        }
        if delayMs > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(delayMs)), execute: run)
        } else {
            run()
        }
    }

    // MARK: Mocked responses

    /// Answers the request with a mocked response, without calling the server.
    private func deliver(_ mocked: FloconNetworkMockResponse) {
        switch mocked {
        case let .body(httpCode, body, mediaType, headers):
            var fields = headers
            if !mediaType.isEmpty, !fields.keys.contains(where: { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }) {
                fields["Content-Type"] = mediaType
            }
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: httpCode, httpVersion: "HTTP/1.1", headerFields: fields)
            else {
                return fail(with: URLError(.badServerResponse))
            }
            let data = Data(body.utf8)
            withState {
                $0.response = response
                $0.body.append(data)
            }
            reportResponse(requestHeaders: nil, error: nil)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .error(exception):
            fail(with: FloconNetworkMockResponse.urlError(forException: exception))
        }
    }

    private func fail(with error: URLError) {
        reportResponse(requestHeaders: nil, error: error)
        client?.urlProtocol(self, didFailWithError: error)
    }

    // MARK: Inner session callbacks (through FloconInnerSessionRouter)

    func didReceive(
        response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let http = response as? HTTPURLResponse
        // known before the first byte: the bytes of an image are counted, not kept
        let isImage = http.map(looksLikeImage) ?? false
        withState {
            $0.response = http
            $0.isImage = isImage
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func didReceive(data: Data) {
        withState { state in
            if state.isImage {
                state.body.count(data.count)
            } else {
                state.body.append(data)
            }
        }
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
        withState { $0.response = response }
        reportResponse(requestHeaders: task.currentRequest?.allHTTPHeaderFields, error: nil)
        withState { $0.redirected = true }

        // swiftlint:disable:next force_cast
        let next = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.removeProperty(forKey: Self.handledKey, in: next)
        client?.urlProtocol(self, wasRedirectedTo: next as URLRequest, redirectResponse: response)

        completionHandler(nil)
        task.cancel()
    }

    func didComplete(task: URLSessionTask, error: Error?) {
        let (redirected, stopped) = withState { ($0.redirected, $0.stopped) }
        if redirected { return }

        reportResponse(requestHeaders: task.currentRequest?.allHTTPHeaderFields, error: error)
        guard !stopped else { return }

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    // MARK: Logging

    private func looksLikeImage(_ response: HTTPURLResponse) -> Bool {
        if response.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("image/") == true {
            return true
        }
        guard let custom = options.isImage, let originalRequest else { return false }
        return custom(originalRequest, response)
    }

    private func reportResponse(requestHeaders: [String: String]?, error: Error?) {
        // reported once, whichever callback comes first
        let snapshot = withState { state -> (HTTPURLResponse?, FloconBody, Bool)? in
            guard !state.reported else { return nil }
            state.reported = true
            return (state.response, state.body, state.isImage)
        }
        guard let snapshot, let plugin else { return }
        let (response, body, knownImage) = snapshot

        let durationMs = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000

        let payload: FloconNetworkResponse
        if let error {
            payload = FloconNetworkResponse(error: error.localizedDescription)
        } else {
            // mocked responses do not go through didReceive(response:)
            let isImage = knownImage || response.map(looksLikeImage) == true
            payload = FloconNetworkResponse(
                httpCode: response?.statusCode,
                contentType: response?.value(forHTTPHeaderField: "Content-Type"),
                // image bytes are not sent
                body: isImage ? nil : body.text,
                size: body.totalSize,
                headers: Self.headersMap(response?.allHeaderFields),
                requestHeaders: requestHeaders,
                isImage: isImage
            )
        }

        plugin.logResponse(
            FloconNetworkCallResponse(
                callId: callId, networkType: "http", durationMs: durationMs, isMocked: isMocked, response: payload
            )
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

    /// The request to perform in the inner session, with the body already read from its stream.
    static func forwardedRequest(_ request: URLRequest, body: Data?) -> URLRequest {
        var forwarded = request
        if let body {
            // also removes the stream: setting `httpBodyStream` to nil afterwards would remove the body
            forwarded.httpBody = body
        }
        return forwarded
    }

    static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var result = Data()
        let chunkSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: chunkSize)
            if count <= 0 { break }
            result.append(buffer, count: count)
        }
        return result
    }
}
