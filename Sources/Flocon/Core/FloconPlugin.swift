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

    /// Sends a value to the desktop app, as JSON.
    ///
    /// The SDK encodes the value off the calling thread, in the order of the messages: calling
    /// this from the main thread only queues the value.
    ///
    /// - Parameters:
    ///   - plugin: Name of the desktop plugin the message is addressed to.
    ///   - method: Name of the method handled by that plugin.
    ///   - value: Payload of the message, encoded with `JSONEncoder`.
    func send<T: Encodable & Sendable>(plugin: String, method: String, value: T)
}

extension FloconMessageSender {
    /// Encodes the value on the calling thread, then sends it with ``send(plugin:method:body:)``.
    public func send<T: Encodable & Sendable>(plugin: String, method: String, value: T) {
        guard let body = FloconJSON.encode(value, plugin: plugin) else { return }
        send(plugin: plugin, method: method, body: body)
    }
}

/// JSON encoding of the messages sent to the desktop app.
enum FloconJSON {
    static func encode<T: Encodable>(_ value: T, plugin: String) -> String? {
        do {
            return String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        } catch {
            FloconLogger.logError("\(plugin): json mapping error", error)
            return nil
        }
    }
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
