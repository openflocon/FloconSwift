import Foundation

/// JSON format of a WebSocket event sent to the desktop app.
///
/// Optional values are encoded as an explicit `null`, not omitted.
struct FloconWebSocketEventRemote: Encodable {
    let id: String
    let event: String
    let url: String
    let size: Int64
    let timestamp: Int64
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id, event, url, size, timestamp, message, error
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(event, forKey: .event)
        try c.encode(url, forKey: .url)
        try c.encode(size, forKey: .size)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(message, forKey: .message)
        try c.encode(error, forKey: .error)
    }
}
