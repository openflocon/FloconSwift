import Foundation

// MARK: - API publique
// Calquée sur Android (flocon-base/.../plugins/tables) :
//   floconTable("users").log(
//       "name" toParam "Florent",
//       "age" toParam "33",
//   )

/// Équivalent de TableColumnConfig / `"colonne" toParam "valeur"` côté Kotlin.
public struct TableColumnConfig: Sendable {
    public let columnName: String
    public let value: String

    public init(_ columnName: String, _ value: String) {
        self.columnName = columnName
        self.value = value
    }
}

/// Équivalent de TableItem : une ligne de la table, horodatée.
public struct FloconTableItem: Sendable {
    public let id: String
    public let name: String
    public let createdAt: Date
    public let columns: [TableColumnConfig]

    public init(id: String = UUID().uuidString, name: String, createdAt: Date = Date(), columns: [TableColumnConfig]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.columns = columns
    }
}

/// Équivalent de TableBuilder.
public struct FloconTable: Sendable {
    public let tableName: String

    public func log(_ columns: TableColumnConfig...) {
        log(columns)
    }

    public func log(_ columns: [TableColumnConfig]) {
        let item = FloconTableItem(name: tableName, columns: columns)
        Flocon.shared.client?.tablePlugin?.registerTable(item)
    }
}

/// Équivalent de `floconTable(tableName)` côté Android.
public func floconTable(_ tableName: String) -> FloconTable {
    FloconTable(tableName: tableName)
}

extension Flocon {
    public static func table(_ tableName: String) -> FloconTable {
        floconTable(tableName)
    }
}
