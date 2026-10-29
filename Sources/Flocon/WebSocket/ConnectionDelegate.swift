import Foundation

/// Tells when the WebSocket is actually open, or why it could not open:
/// `URLSessionWebSocketTask.resume()` does not report it by itself.
final class ConnectionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var openContinuation: CheckedContinuation<Void, Error>?
    private var onClosed: (@Sendable () -> Void)?

    func setOpenContinuation(_ c: CheckedContinuation<Void, Error>) {
        lock.lock(); openContinuation = c; lock.unlock()
    }

    func setOnClosed(_ handler: @escaping @Sendable () -> Void) {
        lock.lock(); onClosed = handler; lock.unlock()
    }

    private func finish(error: Error?) {
        lock.lock()
        let pending = openContinuation
        openContinuation = nil
        let closed = onClosed
        lock.unlock()

        if let pending {
            // never opened: the connection failed
            pending.resume(throwing: error ?? URLError(.cannotConnectToHost))
        } else {
            closed?()
        }
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let (disposition, credential) = floconServerTrustResponse(for: challenge)
        completionHandler(disposition, credential)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol _: String?) {
        lock.lock()
        let pending = openContinuation
        openContinuation = nil
        lock.unlock()
        pending?.resume()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        finish(error: nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish(error: error)
    }
}
