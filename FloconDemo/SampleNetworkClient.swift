import Foundation
import Flocon

/// Network calls triggered by the sample screens.
///
/// The session is created with `.withFlocon()`: all its calls are sent to Flocon.
struct SampleNetworkClient: Sendable {
    private let session = URLSession(configuration: URLSessionConfiguration.default.withFlocon())

    /// Simple JSON GET.
    func simpleGet() async throws -> String {
        try await perform(URLRequest(url: URL(string: "https://jsonplaceholder.typicode.com/todos/1")!))
    }

    /// Compressed (gzip) response.
    func gzipGet() async throws -> String {
        try await perform(URLRequest(url: URL(string: "https://httpbin.org/gzip")!))
    }

    /// JSON POST with headers and body.
    func post() async throws -> String {
        var request = URLRequest(url: URL(string: "https://jsonplaceholder.typicode.com/posts")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer demo-token", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "title": "Flocon",
            "body": "Hello from URLSession",
            "userId": 1,
        ])
        return try await perform(request)
    }

    /// GraphQL request.
    func graphQL() async throws -> String {
        var request = URLRequest(url: URL(string: "https://countries.trevorblades.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": "{ country(code: \"FR\") { name capital currency } }",
        ])
        return try await perform(request)
    }

    /// Image: the body is not sent to Flocon (isImage).
    func image() async throws -> String {
        try await perform(URLRequest(url: URL(string: "https://picsum.photos/300/200")!))
    }

    /// Slow response (2 s) to see the duration.
    func slow() async throws -> String {
        try await perform(URLRequest(url: URL(string: "https://httpbin.org/delay/2")!))
    }

    /// HTTP 404 error.
    func notFound() async throws -> String {
        try await perform(URLRequest(url: URL(string: "https://httpbin.org/status/404")!))
    }

    /// Network error (unknown host): logged with `error`.
    func networkError() async throws -> String {
        try await perform(URLRequest(url: URL(string: "https://this-host-does-not-exist.invalid")!))
    }

    /// WebSocket echo, logged by hand in Flocon:
    /// each event of the connection is sent with `floconLogWebSocketEvent`.
    func websocketEcho() async throws -> String {
        let url = URL(string: "wss://ws.postman-echo.com/raw")!
        let urlString = url.absoluteString
        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        floconLogWebSocketEvent(FloconWebSocketEvent(websocketUrl: urlString, event: .open))

        do {
            let text = "Hello \(UUID().uuidString)"
            try await task.send(.string(text))
            floconLogWebSocketEvent(FloconWebSocketEvent(websocketUrl: urlString, event: .sendMessage, message: text))

            let received: String
            switch try await task.receive() {
            case .string(let value): received = value
            case .data(let data): received = "\(data.count) bytes"
            @unknown default: received = ""
            }
            floconLogWebSocketEvent(FloconWebSocketEvent(websocketUrl: urlString, event: .receiveMessage, message: received))

            task.cancel(with: .normalClosure, reason: nil)
            floconLogWebSocketEvent(FloconWebSocketEvent(websocketUrl: urlString, event: .closed))
            return "Echo: \(received)"
        } catch {
            floconLogWebSocketEvent(FloconWebSocketEvent(websocketUrl: urlString, event: .error, error: error))
            task.cancel(with: .abnormalClosure, reason: nil)
            throw error
        }
    }

    private func perform(_ request: URLRequest) async throws -> String {
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        return "HTTP \(code) — \(data.count) bytes"
    }
}
