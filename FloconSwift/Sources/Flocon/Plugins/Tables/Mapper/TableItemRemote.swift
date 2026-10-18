import Foundation

/// JSON format of a table row sent to the desktop app.
struct TableItemRemote: Encodable {
    let id: String
    let name: String
    let createdAt: Int64
    let columns: [TableColumnRemote]
}

/// JSON format of a column value in a table row.
struct TableColumnRemote: Encodable {
    let column: String
    let value: String
}
