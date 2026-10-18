import Foundation

/// Sends the deeplinks of the app to the Flocon desktop app.
///
/// The list is sent when it is registered, and again on each connection.
final class FloconDeeplinksPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "Deeplink"
    private static let methodGetDeeplinks = "GetDeeplinks"

    let pluginName = FloconDeeplinksPlugin.name
    private weak var sender: FloconMessageSender?

    private let lock = NSLock()
    private var registered: DeeplinksRemote?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    func register(deeplinks: [FloconDeeplink], variables: [FloconDeeplinkVariable]) {
        let remote = DeeplinksRemote(deeplinks: deeplinks, variables: variables)
        lock.lock(); registered = remote; lock.unlock()
        send(remote)
    }

    func onConnectedToServer() {
        lock.lock(); let remote = registered; lock.unlock()
        if let remote { send(remote) }
    }

    /// The desktop app sends nothing to this plugin: it opens the deeplinks itself.
    func onMessageReceived(_ message: FloconMessageFromServer) {}

    private func send(_ remote: DeeplinksRemote) {
        do {
            let data = try JSONEncoder().encode(remote)
            guard let json = String(data: data, encoding: .utf8) else { return }
            sender?.send(plugin: pluginName, method: Self.methodGetDeeplinks, body: json)
        } catch {
            FloconLogger.logError("Deeplinks json mapping error", error)
        }
    }
}
