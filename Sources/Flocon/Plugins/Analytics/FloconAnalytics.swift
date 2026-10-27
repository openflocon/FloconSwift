import Foundation

/// A key-value property attached to an ``AnalyticsEvent``.
public struct AnalyticsProperty: Sendable {
    /// Name of the property.
    public let name: String
    /// Value of the property.
    public let value: String

    /// Creates a property.
    ///
    /// - Parameters:
    ///   - name: Name of the property.
    ///   - value: Value of the property.
    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}

/// An analytics event, shown in the Analytics section of the Flocon desktop app.
public struct AnalyticsEvent: Sendable {
    /// Name of the event, for example `"button_clicked"`.
    public let eventName: String
    /// Properties of the event.
    public let properties: [AnalyticsProperty]

    /// Creates an event.
    ///
    /// - Parameters:
    ///   - eventName: Name of the event.
    ///   - properties: Properties of the event.
    public init(eventName: String, _ properties: AnalyticsProperty...) {
        self.eventName = eventName
        self.properties = properties
    }

    /// Creates an event from an array of properties.
    ///
    /// - Parameters:
    ///   - eventName: Name of the event.
    ///   - properties: Properties of the event.
    public init(eventName: String, properties: [AnalyticsProperty]) {
        self.eventName = eventName
        self.properties = properties
    }
}

/// An ``AnalyticsEvent`` logged on a stream, with the time it was logged.
public struct FloconAnalyticsItem: Sendable {
    /// Name of the stream, for example `"firebase"`.
    public let streamName: String
    /// Name of the event.
    public let eventName: String
    /// When the event was logged.
    public let createdAt: Date
    /// Properties of the event.
    public let properties: [AnalyticsProperty]

    /// Creates an item from an event.
    ///
    /// - Parameters:
    ///   - streamName: Name of the stream the event belongs to.
    ///   - event: The event.
    ///   - createdAt: When the event was logged. Defaults to now.
    public init(streamName: String, event: AnalyticsEvent, createdAt: Date = Date()) {
        self.streamName = streamName
        self.eventName = event.eventName
        self.createdAt = createdAt
        self.properties = event.properties
    }
}

/// Logs analytics events on a stream of the Flocon desktop app.
///
/// Each stream is shown as its own table in the desktop app. Use one stream per analytics
/// provider, so that you can check what each of them receives:
///
/// ```swift
/// Flocon.analyticsPlugin.sender("firebase").logEvents(
///     AnalyticsEvent(
///         eventName: "button_clicked",
///         AnalyticsProperty("button_id", "checkout_pay")
///     )
/// )
/// ```
public struct FloconAnalytics: Sendable {
    let plugin: FloconAnalyticsPlugin
    let streamName: String

    /// Logs events on the stream.
    ///
    /// Does nothing if ``Flocon/initialize(config:)`` has not been called.
    ///
    /// - Parameter events: The events to log.
    public func logEvents(_ events: AnalyticsEvent...) {
        logEvents(events)
    }

    /// Logs an array of events on the stream.
    ///
    /// Does nothing if ``Flocon/initialize(config:)`` has not been called.
    ///
    /// - Parameter events: The events to log.
    public func logEvents(_ events: [AnalyticsEvent]) {
        let items = events.map { FloconAnalyticsItem(streamName: streamName, event: $0) }
        plugin.registerAnalytics(items)
    }
}
