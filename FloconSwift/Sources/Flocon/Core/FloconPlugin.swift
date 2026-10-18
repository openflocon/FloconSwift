import Foundation

// Équivalent de FloconMessageSender : ce que les plugins utilisent pour parler au desktop.
public protocol FloconMessageSender: AnyObject {
    func send(plugin: String, method: String, body: String)
}

// Équivalent de FloconPlugin. Le dispatch se fait via `pluginName`
// (les constantes Protocol.ToDevice.X.Plugin côté Kotlin).
public protocol FloconPlugin: AnyObject {
    var pluginName: String { get }
    func onConnectedToServer()
    func onMessageReceived(_ message: FloconMessageFromServer)
}
