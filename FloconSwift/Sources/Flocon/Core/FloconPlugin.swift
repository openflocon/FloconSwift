import Foundation

/// Sends messages to the Flocon desktop app.
public protocol FloconMessageSender: AnyObject {
    /// Sends a message to the desktop app.
    ///
    /// Messages are delivered in order. They are queued while the app is not connected.
    ///
    /// - Parameters:
    ///   - plugin: Name of the desktop plugin the message is addressed to.
    ///   - method: Name of the method handled by that plugin.
    ///   - body: Payload of the message, usually JSON.
    func send(plugin: String, method: String, body: String)
}

/// A feature of the SDK that talks to its counterpart in the Flocon desktop app.
///
/// Messages from the desktop are routed to the plugin whose ``pluginName`` matches
/// ``FloconMessageFromServer/plugin``.
public protocol FloconPlugin: AnyObject {
    /// Name of the plugin in the Flocon protocol, for example `"network"`.
    var pluginName: String { get }
    /// Called each time the SDK connects to the desktop app.
    func onConnectedToServer()
    /// Called when the desktop app sends a message to this plugin.
    ///
    /// - Parameter message: The message, whose ``FloconMessageFromServer/plugin`` is ``pluginName``.
    func onMessageReceived(_ message: FloconMessageFromServer)
}
