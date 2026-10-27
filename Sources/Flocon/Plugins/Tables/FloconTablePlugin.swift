import Foundation

/// Sends table rows to the Flocon desktop app.
///
/// Log rows with ``FloconTablePlugin/table(_:)`` rather than calling this plugin directly.
public final class FloconTablePlugin: FloconPlugin, @unchecked Sendable {
    static let name = "Table"
    private static let methodAddItems = "AddItems"

    public let pluginName = FloconTablePlugin.name
    private weak var sender: FloconMessageSender?

    init(sender: FloconMessageSender) {
        self.sender = sender
    }

    public func onConnectedToServer() {}

    /// The desktop app sends nothing to this plugin.
    public func onMessageReceived(_ message: FloconMessageFromServer) {}

    /// Sends a row to the desktop app.
    ///
    /// - Parameter item: The row to send.
    public func registerTable(_ item: FloconTableItem) {
        let model = TableItemRemote(
            id: item.id,
            name: item.name,
            createdAt: Int64(item.createdAt.timeIntervalSince1970 * 1000),
            columns: item.columns.map { TableColumnRemote(column: $0.columnName, value: $0.value) }
        )
        // the desktop expects a JSON array of items, even for a single row; encoded off the calling thread
        sender?.send(plugin: pluginName, method: Self.methodAddItems, value: [model])
    }
}

extension FloconTablePlugin {
    /// Returns the logger of a table.
    ///
    /// - Parameter tableName: Name of the table.
    /// - Returns: A logger for that table.
    public func table(_ tableName: String) -> FloconTable {
        FloconTable(plugin: self, tableName: tableName)
    }
}
