import Foundation

/// Sends the deeplinks of the app to the Flocon desktop app.
///
/// The list is sent when it is registered, and again on each connection.
public final class FloconDeeplinksPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "Deeplink"
    private static let methodGetDeeplinks = "GetDeeplinks"

    public let pluginName = FloconDeeplinksPlugin.name
    private weak var sender: FloconMessageSender?

    private let lock = NSLock()
    private var registered: DeeplinksRemote?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    /// Lists deeplinks in the desktop app, replacing the previous list. See ``FloconDeeplinksPlugin/register(deeplinks:variables:)``.
    ///
    /// - Parameters:
    ///   - deeplinks: The deeplinks of the app.
    ///   - variables: The variables referenced by the deeplinks.
    public func register(deeplinks: [FloconDeeplink], variables: [FloconDeeplinkVariable] = []) {
        let remote = DeeplinksRemote(deeplinks: deeplinks, variables: variables)
        lock.lock(); registered = remote; lock.unlock()
        send(remote)
    }

    public func onConnectedToServer() {
        lock.lock(); let remote = registered; lock.unlock()
        if let remote { send(remote) }
    }

    /// The desktop app sends nothing to this plugin: it opens the deeplinks itself.
    public func onMessageReceived(_ message: FloconMessageFromServer) {}

    /// Encoded off the calling thread.
    private func send(_ remote: DeeplinksRemote) {
        sender?.send(plugin: pluginName, method: Self.methodGetDeeplinks, value: remote)
    }
}
