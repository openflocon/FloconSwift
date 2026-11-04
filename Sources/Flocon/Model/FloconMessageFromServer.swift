import Foundation

/// A message sent by the Flocon desktop app to a plugin.
public struct FloconMessageFromServer: Decodable {
    /// Name of the plugin the message is addressed to.
    public let plugin: String
    /// Name of the requested method, for example `"get_app_icon"`.
    public let method: String
    /// Payload of the message, usually JSON. Can be empty.
    public let body: String
}
