import Foundation

/// WebSocket client based on `URLSessionWebSocketTask`.
///
/// An actor, so that the connection state and the message queue are safe to use from any thread.
actor FloconWebSocketClientImpl: FloconWebSocketClient {
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?

    // Messages sent while disconnected; only the most recent ones are kept.
    private let queueCapacity = 200
    private var queue: [String] = []

    func connect(
        address: String,
        port: Int,
        onMessageReceived: @escaping @Sendable (String) -> Void,
        onClosed: @escaping @Sendable () -> Void
    ) async throws {
        // already connected
        if task != nil { return }

        guard let url = URL(string: "ws://\(address):\(port)") else {
            throw URLError(.badURL)
        }

        let delegate = ConnectionDelegate()
        let newSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.setValue("Flocon", forHTTPHeaderField: "User-Agent")
        let newTask = newSession.webSocketTask(with: request)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                delegate.setOpenContinuation(continuation)
                newTask.resume()
            }
        } onCancel: {
            FloconLogger.log("Task cancelled, closing the WebSocket.")
            newTask.cancel(with: .goingAway, reason: nil)
        }

        FloconLogger.log("✅ WebSocket Connection Opened!")
        session = newSession
        task = newTask

        delegate.setOnClosed { [weak self] in
            Task { await self?.handleEnded(newTask, onClosed: onClosed) }
        }
        receiveLoop(newTask, onMessageReceived: onMessageReceived, onClosed: onClosed)
    }

    private func receiveLoop(
        _ socket: URLSessionWebSocketTask,
        onMessageReceived: @escaping @Sendable (String) -> Void,
        onClosed: @escaping @Sendable () -> Void
    ) {
        Task { [weak self] in
            while true {
                do {
                    let message = try await socket.receive()
                    switch message {
                    case .string(let text):
                        FloconLogger.log(payload: text, "WEBSOCKET <----- Receiving")
                        onMessageReceived(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            onMessageReceived(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    FloconLogger.logError("❌ WebSocket Connection Failed", error)
                    await self?.handleEnded(socket, onClosed: onClosed)
                    return
                }
            }
        }
    }

    /// Called when the server closes the connection or the connection drops.
    ///
    /// The `===` check avoids notifying twice, or after an explicit `disconnect()`.
    private func handleEnded(_ socket: URLSessionWebSocketTask, onClosed: @Sendable () -> Void) {
        guard task === socket else { return }
        task = nil
        session?.invalidateAndCancel()
        session = nil
        onClosed()
    }

    func sendMessage(_ message: String) async -> Bool {
        guard let task else {
            // not connected yet: queue the message
            queue.append(message)
            if queue.count > queueCapacity { queue.removeFirst(queue.count - queueCapacity) }
            return false
        }
        FloconLogger.log(payload: message, "WEBSOCKET ----> send")
        do {
            try await task.send(.string(message))
            return true
        } catch {
            FloconLogger.logError("send failed", error)
            return false
        }
    }

    func sendPendingMessages() async {
        guard task != nil else { return }
        let pending = queue
        queue.removeAll()
        for message in pending {
            _ = await sendMessage(message)
        }
    }

    func disconnect() async {
        let socket = task
        task = nil // before closing, so that onClosed is not triggered
        socket?.cancel(with: .normalClosure, reason: Data("Client disconnecting".utf8))
        session?.invalidateAndCancel()
        session = nil
    }
}
