import Foundation

/// JSON format of an analytics item sent to the desktop app.
struct FloconAnalyticsItemRemote: Encodable {
    let id: String
    let analyticsTableId: String
    let eventName: String
    let createdAt: Int64
    let properties: [Property]

    struct Property: Encodable {
        let name: String
        let value: String
    }
}
