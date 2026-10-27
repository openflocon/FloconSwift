import Foundation

/// JSON format of an analytics item sent to the desktop app.
struct FloconAnalyticsItemRemote: Encodable {
    let id: String
    let analyticsTableId: String
    let eventName: String
    let createdAt: Int64
    let properties: [Property]

    private enum CodingKeys: String, CodingKey {
        case id
        case analyticsTableId = "analytics_table_id"
        case eventName = "event_name"
        case createdAt = "created_at"
        case properties
    }

    struct Property: Encodable {
        let name: String
        let value: String
    }
}
