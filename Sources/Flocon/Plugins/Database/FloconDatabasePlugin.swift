import Foundation

/// Lets the Flocon desktop app list and query the SQLite databases of the app, and shows the
/// queries the app logs.
///
/// The list of databases is sent on each connection and each registration. The desktop then
/// queries a database by its path; only the listed databases can be queried.
public final class FloconDatabasePlugin: FloconPlugin, @unchecked Sendable {
    static let name = "database"
    // desktop -> app
    private static let methodGetDatabases = "getDatabases"
    private static let methodQuery = "query"
    // app -> desktop
    private static let methodDatabasesResult = "getdatabases"
    private static let methodQueryResult = "query"
    private static let methodLogQuery = "logquery"

    public let pluginName = FloconDatabasePlugin.name
    private weak var sender: FloconMessageSender?
    private let discovery: FloconDatabaseDiscovery

    /// Scans and queries can be slow: they run in order, off the thread that receives the messages.
    private let queue = DispatchQueue(label: "io.github.openflocon.database")
    private let lock = NSLock()
    // by path, so that registering a file again replaces it
    private var registered: [String: FloconDatabase] = [:]
    private var registrationOrder: [String] = []

    init(sender: FloconMessageSender, discovery: FloconDatabaseDiscovery = .app) {
        self.sender = sender
        self.discovery = discovery
    }

    /// Shows a database in the desktop app, or renames a database already shown.
    ///
    /// - Parameter database: The database.
    public func register(_ database: FloconDatabase) {
        let path = Self.path(of: database.url)
        lock.lock()
        if registered[path] == nil { registrationOrder.append(path) }
        registered[path] = database
        lock.unlock()
        queue.async { self.sendDatabases() }
    }

    /// Shows a query run by the app in the desktop app.
    ///
    /// - Parameters:
    ///   - dbName: Name of the database.
    ///   - sqlQuery: The SQL query.
    ///   - bindArgs: Values bound to the query; `nil` is shown as `null`.
    public func logQuery(dbName: String, sqlQuery: String, bindArgs: [Any?]) {
        let model = DatabaseQueryLogRemote(
            dbName: dbName,
            sqlQuery: sqlQuery,
            bindArgs: bindArgs.map { $0.map { String(describing: $0) } ?? "null" },
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        send(model, method: Self.methodLogQuery)
    }

    // MARK: FloconPlugin

    public func onConnectedToServer() {
        queue.async { self.sendDatabases() }
    }

    public func onMessageReceived(_ message: FloconMessageFromServer) {
        switch message.method {
        case Self.methodGetDatabases:
            queue.async { self.sendDatabases() }

        case Self.methodQuery:
            guard let request = try? JSONDecoder().decode(ToDeviceDatabaseQueryMessage.self, from: Data(message.body.utf8)) else {
                FloconLogger.log(payload: message.body, "Unreadable database query:")
                return
            }
            queue.async {
                let result = self.execute(query: request.query, database: request.database)
                self.send(QueryResultRemote(requestId: request.requestId, result: result.json()), method: Self.methodQueryResult)
            }

        default:
            break
        }
    }

    // MARK: Databases

    /// The databases found in the app, then the registered ones, without duplicates.
    ///
    /// A registered database keeps its name and its place among the found ones.
    func databases() -> [FloconDatabase] {
        lock.lock()
        let registered = registered
        let order = registrationOrder
        lock.unlock()

        let found = discovery.databases()
        let foundPaths = Set(found.map { Self.path(of: $0.url) })
        let renamed = found.map { registered[Self.path(of: $0.url)] ?? $0 }
        let others = order
            .filter { !foundPaths.contains($0) && FileManager.default.fileExists(atPath: $0) }
            .compactMap { registered[$0] }
        return renamed + others
    }

    func execute(query: String, database id: String) -> FloconDatabaseResult {
        let path = Self.path(of: URL(fileURLWithPath: id))
        guard databases().contains(where: { Self.path(of: $0.url) == path }) else {
            return .error(message: "Unknown database: \(id)", originalSql: query)
        }
        return FloconSQLite.execute(query: query, atPath: path)
    }

    private func sendDatabases() {
        let list = databases().map { DeviceDatabaseRemote(id: Self.path(of: $0.url), name: $0.displayName) }
        send(list, method: Self.methodDatabasesResult)
    }

    /// Encoded off the calling thread: ``logQuery(dbName:sqlQuery:bindArgs:)`` is often called from the main thread.
    private func send<T: Encodable & Sendable>(_ value: T, method: String) {
        sender?.send(plugin: pluginName, method: method, value: value)
    }

    /// Path used as identifier, the same for every spelling of a file.
    private static func path(of url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
