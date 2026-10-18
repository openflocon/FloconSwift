import Foundation

// MARK: - Modèle JSON
// Identique à TableItemRemote / TableColumnRemote (flocon/.../tables/model/TableItem.kt).

struct TableItemRemote: Encodable {
    let id: String
    let name: String
    let createdAt: Int64
    let columns: [TableColumnRemote]
}

struct TableColumnRemote: Encodable {
    let column: String
    let value: String
}
