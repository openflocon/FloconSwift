import Foundation

/// The value of one column in a row of a ``FloconTable``.
public struct TableColumnConfig: Sendable {
    /// Name of the column.
    public let columnName: String
    /// Value of the column in this row.
    public let value: String

    /// Creates a column value.
    ///
    /// - Parameters:
    ///   - columnName: Name of the column.
    ///   - value: Value of the column in this row.
    public init(_ columnName: String, _ value: String) {
        self.columnName = columnName
        self.value = value
    }
}

/// A row logged in a table, with the time it was logged.
public struct FloconTableItem: Sendable {
    /// Unique identifier of the row.
    public let id: String
    /// Name of the table the row belongs to.
    public let name: String
    /// When the row was logged.
    public let createdAt: Date
    /// Values of the row, one per column.
    public let columns: [TableColumnConfig]

    /// Creates a row.
    ///
    /// - Parameters:
    ///   - id: Unique identifier of the row. Defaults to a random UUID.
    ///   - name: Name of the table the row belongs to.
    ///   - createdAt: When the row was logged. Defaults to now.
    ///   - columns: Values of the row, one per column.
    public init(id: String = UUID().uuidString, name: String, createdAt: Date = Date(), columns: [TableColumnConfig]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.columns = columns
    }
}

/// Logs rows in a table of the Flocon desktop app.
///
/// Tables are a quick way to inspect structured data while the app runs. Columns are created
/// from the names used in the logged rows:
///
/// ```swift
/// floconTable("users").log(
///     TableColumnConfig("name", "Florent"),
///     TableColumnConfig("age", "33")
/// )
/// ```
public struct FloconTable: Sendable {
    /// Name of the table.
    public let tableName: String

    /// Logs a row in the table.
    ///
    /// Does nothing if ``Flocon/initialize(config:)`` has not been called.
    ///
    /// - Parameter columns: Values of the row, one per column.
    public func log(_ columns: TableColumnConfig...) {
        log(columns)
    }

    /// Logs a row in the table from an array of column values.
    ///
    /// Does nothing if ``Flocon/initialize(config:)`` has not been called.
    ///
    /// - Parameter columns: Values of the row, one per column.
    public func log(_ columns: [TableColumnConfig]) {
        let item = FloconTableItem(name: tableName, columns: columns)
        Flocon.shared.client?.tablePlugin?.registerTable(item)
    }
}

/// Returns the logger of a table.
///
/// - Parameter tableName: Name of the table.
/// - Returns: A logger for that table.
public func floconTable(_ tableName: String) -> FloconTable {
    FloconTable(tableName: tableName)
}

extension Flocon {
    /// Returns the logger of a table.
    ///
    /// - Parameter tableName: Name of the table.
    /// - Returns: A logger for that table.
    public static func table(_ tableName: String) -> FloconTable {
        floconTable(tableName)
    }
}
