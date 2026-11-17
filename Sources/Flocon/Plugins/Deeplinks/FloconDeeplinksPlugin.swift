import Foundation

/// Sends the deeplinks of the app to the Flocon desktop app.
///
/// The list is sent when it is registered, and again on each connection.
public final class FloconDeeplinksPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "deeplink"
    private static let methodGetDeeplinks = "get_deeplinks"

    public let pluginName = FloconDeeplinksPlugin.name
    private weak var sender: FloconMessageSender?

#if FloconEnabled
    private let lock = NSLock()
    private var registered: DeeplinksRemote?
#endif

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    /// Lists deeplinks in the desktop app, replacing the previous list. See ``FloconDeeplinksPlugin/register(deeplinks:variables:)``.
    ///
    /// - Parameters:
    ///   - deeplinks: The deeplinks of the app.
    ///   - variables: The variables referenced by the deeplinks.
    public func register(deeplinks: [FloconDeeplink], variables: [FloconDeeplinkVariable] = []) {
        #if FloconEnabled
        let remote = DeeplinksRemote(deeplinks: deeplinks, variables: variables)
        lock.lock(); registered = remote; lock.unlock()
        send(remote)
        #endif
    }

    public func onConnectedToServer() {
        #if FloconEnabled
        lock.lock(); let remote = registered; lock.unlock()
        if let remote { send(remote) }
        #endif
    }

    /// The desktop app sends nothing to this plugin: it opens the deeplinks itself.
    public func onMessageReceived(_ message: FloconMessageFromServer) {}

#if FloconEnabled
    /// Encoded off the calling thread.
    private func send(_ remote: DeeplinksRemote) {
        sender?.send(plugin: pluginName, method: Self.methodGetDeeplinks, value: remote)
    }
#endif
}
