import Foundation

/// JSON format of a console message sent to the desktop app.
struct FloconWebViewConsoleLogRemote: Encodable {
    let id: String
    let webViewId: String
    let url: String?
    let level: String
    let message: String
    let sourceId: String?
    let lineNumber: Int?
    let createdAt: Int64

    private enum CodingKeys: String, CodingKey {
        case id
        case webViewId = "web_view_id"
        case url
        case level
        case message
        case sourceId = "source_id"
        case lineNumber = "line_number"
        case createdAt = "created_at"
    }
}

/// JSON format of a page event sent to the desktop app.
struct FloconWebViewPageEventRemote: Encodable {
    let id: String
    let webViewId: String
    let url: String?
    let type: String
    let message: String?
    let statusCode: Int?
    let createdAt: Int64

    private enum CodingKeys: String, CodingKey {
        case id
        case webViewId = "web_view_id"
        case url
        case type
        case message
        case statusCode = "status_code"
        case createdAt = "created_at"
    }
}

/// JSON format of a bridge call sent to the desktop app.
struct FloconWebViewBridgeCallRemote: Encodable {
    let id: String
    let webViewId: String
    let url: String?
    let interfaceName: String
    let method: String
    let arguments: String?
    let result: String?
    let createdAt: Int64

    private enum CodingKeys: String, CodingKey {
        case id
        case webViewId = "web_view_id"
        case url
        case interfaceName = "interface_name"
        case method
        case arguments
        case result
        case createdAt = "created_at"
    }
}
