import Foundation

/// JSON format of a timeline event sent to the desktop app.
struct FloconTimelineEventRemote: Encodable {
    let type: String
    let value: String
    /// `nil` when empty: the key is then omitted.
    let params: [String: String]?
    /// `nil` for a typed log: the key is then omitted.
    let level: String?
    /// Epoch in milliseconds, at the moment of the call.
    let timestamp: Int64

    init(type: String, value: String, params: [String: String], level: TimelineLevel?, timestamp: Int64) {
        self.type = type
        self.value = value
        self.params = params.isEmpty ? nil : params
        self.level = level?.rawValue
        self.timestamp = timestamp
    }
}
