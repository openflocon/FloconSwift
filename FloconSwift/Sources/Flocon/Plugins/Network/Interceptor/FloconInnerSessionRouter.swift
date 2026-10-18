import Foundation

// MARK: - Session interne partagée

/// Une seule URLSession pour toutes les requêtes rejouées (au lieu d'une par requête) :
/// son delegate route chaque callback vers le FloconURLProtocol qui possède la tâche.
final class FloconInnerSessionRouter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    static let shared = FloconInnerSessionRouter()

    private let lock = NSLock()
    private var handlers: [Int: FloconURLProtocol] = [:]

    /// Créée une seule fois, dans l'init (thread-safe) de `shared`.
    /// La session garde son delegate (le routeur) en vie.
    private var session: URLSession!

    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func makeTask(with request: URLRequest, handler: FloconURLProtocol) -> URLSessionDataTask {
        let task = session.dataTask(with: request)
        lock.lock(); handlers[task.taskIdentifier] = handler; lock.unlock()
        return task
    }

    private func handler(for task: URLSessionTask) -> FloconURLProtocol? {
        lock.lock(); defer { lock.unlock() }
        return handlers[task.taskIdentifier]
    }

    private func removeHandler(for task: URLSessionTask) -> FloconURLProtocol? {
        lock.lock(); defer { lock.unlock() }
        return handlers.removeValue(forKey: task.taskIdentifier)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let handler = handler(for: dataTask) else { return completionHandler(.cancel) }
        handler.didReceive(response: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        handler(for: dataTask)?.didReceive(data: data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let handler = handler(for: task) else { return completionHandler(nil) }
        handler.willRedirect(task: task, response: response, newRequest: request, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        removeHandler(for: task)?.didComplete(task: task, error: error)
    }
}
