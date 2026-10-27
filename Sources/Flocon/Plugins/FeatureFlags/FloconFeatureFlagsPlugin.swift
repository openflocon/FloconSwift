import Foundation

/// Sends the feature flags of the app to the Flocon desktop app.
///
/// The flags of a provider are sent when they are registered, and again on each connection.
public final class FloconFeatureFlagsPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "featureflags"
    private static let methodRegister = "register"

    public let pluginName = FloconFeatureFlagsPlugin.name
    private weak var sender: FloconMessageSender?

    private let lock = NSLock()
    private var registered: [String: [FloconFeatureFlag]] = [:]

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    /// Replaces the flags of a provider in the desktop app. See ``FloconFeatureFlagsPlugin/sender(_:)``.
    ///
    /// - Parameters:
    ///   - provider: Name of the provider, for example `"firebase"`.
    ///   - flags: All the flags of the provider.
    public func register(provider: String, flags: [FloconFeatureFlag]) {
        lock.lock(); registered[provider] = flags; lock.unlock()
        send(FloconFeatureFlagsRemote(provider: provider, flags: flags))
    }

    public func onConnectedToServer() {
        lock.lock(); let all = registered; lock.unlock()
        for provider in all.keys.sorted() {
            send(FloconFeatureFlagsRemote(provider: provider, flags: all[provider] ?? []))
        }
    }

    /// The desktop app is read only: it sends nothing to this plugin.
    public func onMessageReceived(_ message: FloconMessageFromServer) {}

    /// Encoded off the calling thread.
    private func send(_ remote: FloconFeatureFlagsRemote) {
        sender?.send(plugin: pluginName, method: Self.methodRegister, value: remote)
    }
}

extension FloconFeatureFlagsPlugin {
    /// Returns a registrar bound to a feature flag provider.
    ///
    /// - Parameter provider: Name of the provider, for example `"firebase"`.
    /// - Returns: A registrar for that provider.
    public func sender(_ provider: String) -> FloconFeatureFlags {
        FloconFeatureFlags(plugin: self, provider: provider)
    }
}
