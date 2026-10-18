import Foundation

// MARK: - API publique
// Calquée sur la doc Android (openflocon.github.io/Flocon/analytics) :
//   floconAnalytics("firebase").logEvents(
//       AnalyticsEvent(eventName: "button_clicked",
//                      AnalyticsProperty("button_id", "checkout_pay"))
//   )

/// Équivalent de `"clé" analyticsProperty "valeur"` côté Kotlin.
public struct AnalyticsProperty: Sendable {
    public let name: String
    public let value: String

    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}

/// Équivalent de AnalyticsEvent(eventName, vararg properties).
public struct AnalyticsEvent: Sendable {
    public let eventName: String
    public let properties: [AnalyticsProperty]

    public init(eventName: String, _ properties: AnalyticsProperty...) {
        self.eventName = eventName
        self.properties = properties
    }

    public init(eventName: String, properties: [AnalyticsProperty]) {
        self.eventName = eventName
        self.properties = properties
    }
}

/// Un événement prêt à être envoyé : flux (« firebase », « app_telemetry »…) + horodatage.
public struct FloconAnalyticsItem: Sendable {
    public let streamName: String
    public let eventName: String
    public let createdAt: Date
    public let properties: [AnalyticsProperty]

    public init(streamName: String, event: AnalyticsEvent, createdAt: Date = Date()) {
        self.streamName = streamName
        self.eventName = event.eventName
        self.createdAt = createdAt
        self.properties = event.properties
    }
}

public struct FloconAnalytics: Sendable {
    let streamName: String

    public func logEvents(_ events: AnalyticsEvent...) {
        logEvents(events)
    }

    public func logEvents(_ events: [AnalyticsEvent]) {
        let items = events.map { FloconAnalyticsItem(streamName: streamName, event: $0) }
        Flocon.shared.client?.analyticsPlugin?.registerAnalytics(items)
    }
}

/// Équivalent de `floconAnalytics(streamName)` côté Android.
public func floconAnalytics(_ streamName: String) -> FloconAnalytics {
    FloconAnalytics(streamName: streamName)
}

extension Flocon {
    public static func analytics(_ streamName: String) -> FloconAnalytics {
        floconAnalytics(streamName)
    }
}
