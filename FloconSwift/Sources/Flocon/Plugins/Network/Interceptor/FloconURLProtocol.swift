import Foundation

// MARK: - URLProtocol

/// Équivalent de FloconOkhttpInterceptor.
/// URLSession n'a pas de chaîne d'interceptors : on utilise un URLProtocol qui rejoue la requête
/// dans une session interne, observe la réponse, puis la renvoie au client d'origine.
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
        // pas de boucle : les requêtes rejouées par la session interne sont marquées
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else { return false }
        guard let scheme = request.url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        // no-op si Flocon n'est pas initialisé (comme `floconNetworkPlugin == null` côté Kotlin)
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

        let startedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        startNanos = DispatchTime.now().uptimeNanoseconds

        // Le body d'un upload arrive souvent en stream : on le lit une fois pour pouvoir
        // à la fois le logger et le rejouer.
        let bodyData = Self.readBody(of: request)
        var forwarded = request
        if let bodyData {
            forwarded.httpBody = bodyData
            forwarded.httpBodyStream = nil
        }

        plugin.logRequest(
            FloconNetworkCallRequestRemote(
                floconCallId: callId,
                floconNetworkType: "http",
                url: request.url?.absoluteString ?? "",
                method: request.httpMethod ?? "GET",
                startTime: startedAtMs,
                requestHeaders: request.allHTTPHeaderFields ?? [:],
                requestBody: bodyData.flatMap { String(data: $0, encoding: .utf8) },
                requestSize: bodyData.map { Int64($0.count) },
                isMocked: false
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
        // didComplete sera appelé avec l'erreur d'annulation (et loggé)
        innerTask?.cancel()
    }

    // MARK: Callbacks de la session interne (via FloconInnerSessionRouter)

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
        // On logge la réponse 3xx, puis on laisse le client d'origine suivre la redirection :
        // elle repassera par ce protocol et sera loggée comme un appel à part.
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
            payload = FloconNetworkResponse(
                httpCode: nil,
                contentType: nil,
                body: nil,
                headers: [:],
                size: nil,
                grpcStatus: nil,
                error: error.localizedDescription,
                requestHeaders: nil,
                isImage: false
            )
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
                // on n'envoie pas les octets des images
                body: isImage ? nil : String(data: receivedData, encoding: .utf8),
                headers: headers,
                size: Int64(receivedData.count),
                grpcStatus: nil,
                error: nil,
                requestHeaders: requestHeaders,
                isImage: isImage
            )
        }

        plugin.logResponse(
            FloconNetworkCallResponseRemote(
                floconCallId: callId,
                durationMs: durationMs,
                floconNetworkType: "http",
                isMocked: false,
                response: payload
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
