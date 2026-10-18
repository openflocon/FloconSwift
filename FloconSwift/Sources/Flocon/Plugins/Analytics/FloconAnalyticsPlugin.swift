import Foundation

// MARK: - Plugin

/// Équivalent de FloconAnalyticsPluginImpl : un message envoyé par item,
/// les erreurs sont loggées sans interrompre les suivants.
public final class FloconAnalyticsPlugin: FloconPlugin, @unchecked Sendable {
    // Protocol.FromDevice.Analytics côté Kotlin
    static let name = "Analytics"
    private static let methodAddItems = "AddItems"

    public let pluginName = FloconAnalyticsPlugin.name
    private weak var sender: FloconMessageSender?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    public func onConnectedToServer() {}

    public func onMessageReceived(_ message: FloconMessageFromServer) {
        // no op (comme côté Android)
    }

    public func registerAnalytics(_ items: [FloconAnalyticsItem]) {
        guard !items.isEmpty else { return }
        // 1. On transforme chaque item en modèle
        let models = items.compactMap { item -> FloconAnalyticsItemRemote? in
            return FloconAnalyticsItemRemote(
                id: UUID().uuidString,
                analyticsTableId: item.streamName,
                eventName: item.eventName,
                createdAt: Int64(item.createdAt.timeIntervalSince1970 * 1000),
                properties: item.properties.map { .init(name: $0.name, value: $0.value) }
            )
        }

        // 2. On encode le tableau complet d'un coup en JSON
        do {
            let data = try JSONEncoder().encode(models)
            guard let jsonArrayString = String(data: data, encoding: .utf8) else { return }
            
            // 3. On envoie la chaîne JSON globale (qui commence par "[" et finit par "]")
            sender?.send(plugin: pluginName, method: Self.methodAddItems, body: jsonArrayString)
        } catch {
            FloconLogger.logError("error on sendAnalytics", error)
        }
    }
}
