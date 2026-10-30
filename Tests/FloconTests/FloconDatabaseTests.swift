import Foundation
import SQLite3
import Testing
@testable import Flocon

private final class RecordingSender: FloconMessageSender, @unchecked Sendable {
    struct Message {
        let plugin: String
        let method: String
        let body: String
    }

    private let lock = NSLock()
    private var _messages: [Message] = []

    var messages: [Message] {
        lock.lock(); defer { lock.unlock() }
        return _messages
    }

    func send(plugin: String, method: String, body: String) {
        lock.lock(); _messages.append(Message(plugin: plugin, method: method, body: body)); lock.unlock()
    }

    /// Waits for the plugin queue to send a message with this method.
    func waitFor(method: String, count: Int = 1) async -> [Message] {
        for _ in 0..<200 {
            let matching = messages.filter { $0.method == method }
            if matching.count >= count { return matching }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return messages.filter { $0.method == method }
    }
}

@Suite struct FloconDatabaseTests {
    private let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("flocon-database-\(UUID().uuidString)", isDirectory: true)

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Creates a SQLite file with a `dogs` table.
    @discardableResult
    private func makeDatabase(at relativePath: String) throws -> URL {
        let url = folder.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let sql = """
        CREATE TABLE dogs (id INTEGER PRIMARY KEY, name TEXT, weight REAL, photo BLOB, owner TEXT);
        INSERT INTO dogs (name, weight, photo, owner) VALUES ('Rex', 12.5, x'CAFE', NULL);
        INSERT INTO dogs (name, weight, photo, owner) VALUES ('Médor', 30.0, NULL, 'Florent');
        """
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        return url
    }

    private func makePlugin(sender: RecordingSender) -> FloconDatabasePlugin {
        FloconDatabasePlugin(sender: sender, discovery: FloconDatabaseDiscovery(roots: [("Documents", folder)]))
    }

    private func query(_ sql: String, on url: URL, plugin: FloconDatabasePlugin) -> FloconDatabaseResult {
        plugin.execute(query: sql, database: url.path)
    }

    // MARK: Queries

    @Test func selectsRowsOfEveryType() throws {
        let url = try makeDatabase(at: "dogs.sqlite")
        let plugin = makePlugin(sender: RecordingSender())

        let result = query("SELECT id, name, weight, photo, owner FROM dogs ORDER BY id", on: url, plugin: plugin)

        #expect(result == .select(
            columns: ["id", "name", "weight", "photo", "owner"],
            values: [
                ["1", "Rex", "12.5", "x'CAFE'", nil],
                ["2", "Médor", "30.0", nil, "Florent"],
            ]
        ))
    }

    @Test func returnsTheIdOfAnInsertedRow() throws {
        let url = try makeDatabase(at: "dogs.sqlite")
        let plugin = makePlugin(sender: RecordingSender())

        #expect(query("INSERT INTO dogs (name) VALUES ('Pluto')", on: url, plugin: plugin) == .insert(insertedId: 3))
    }

    @Test func returnsTheNumberOfChangedRows() throws {
        let url = try makeDatabase(at: "dogs.sqlite")
        let plugin = makePlugin(sender: RecordingSender())

        #expect(query("UPDATE dogs SET weight = 1", on: url, plugin: plugin) == .updateDelete(affectedCount: 2))
        #expect(query("DELETE FROM dogs WHERE name = 'Rex'", on: url, plugin: plugin) == .updateDelete(affectedCount: 1))
    }

    @Test func runsOtherStatements() throws {
        let url = try makeDatabase(at: "dogs.sqlite")
        let plugin = makePlugin(sender: RecordingSender())

        #expect(query("CREATE TABLE cats (id INTEGER)", on: url, plugin: plugin) == .rawSuccess)
        #expect(query("PRAGMA table_info(cats)", on: url, plugin: plugin) != .rawSuccess)
    }

    @Test func reportsSQLErrors() throws {
        let url = try makeDatabase(at: "dogs.sqlite")
        let plugin = makePlugin(sender: RecordingSender())

        let result = query("SELECT * FROM cats", on: url, plugin: plugin)

        #expect(result == .error(message: "no such table: cats", originalSql: "SELECT * FROM cats"))
    }

    @Test func refusesUnlistedDatabases() throws {
        let plugin = makePlugin(sender: RecordingSender())
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("flocon-\(UUID().uuidString).sqlite")

        let result = query("CREATE TABLE t (id INTEGER)", on: outside, plugin: plugin)

        guard case .error = result else {
            Issue.record("Expected an error, got \(result)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: outside.path))
    }

    @Test func truncatesLongBlobs() {
        #expect(FloconSQLite.blobDescription(Data([0x01, 0xAB])) == "x'01AB'")
        let long = FloconSQLite.blobDescription(Data(repeating: 0xFF, count: 100))
        #expect(long == "x'\(String(repeating: "FF", count: 64))…' (100 bytes)")
    }

    // MARK: Protocol

    @Test func answersAQueryWithItsRequestId() async throws {
        let url = try makeDatabase(at: "dogs.sqlite")
        let sender = RecordingSender()
        let plugin = makePlugin(sender: sender)
        let body = #"{"query":"SELECT name FROM dogs WHERE id = 1","requestId":"r1","database":"\#(url.path)"}"#

        plugin.onMessageReceived(FloconMessageFromServer(plugin: "database", method: "query", body: body))

        let message = try #require(await sender.waitFor(method: "query").first)
        #expect(message.plugin == "database")
        // the desktop reads a JSON string, holding a JSON string
        let outer = try JSONSerialization.jsonObject(with: Data(message.body.utf8)) as? [String: String]
        #expect(outer?["requestId"] == "r1")
        let result = try JSONSerialization.jsonObject(with: Data(try #require(outer?["result"]).utf8)) as? [String: String]
        #expect(result?["type"] == "Select")
        let select = try JSONSerialization.jsonObject(with: Data(try #require(result?["body"]).utf8)) as? [String: Any]
        #expect(select?["columns"] as? [String] == ["name"])
        #expect(select?["values"] as? [[String]] == [["Rex"]])
    }

    @Test func encodesNullValuesAndOtherResults() {
        #expect(FloconDatabaseResult.select(columns: ["a"], values: [[nil]]).json()
            == #"{"body":"{\"columns\":[\"a\"],\"values\":[[null]]}","type":"Select"}"#)
        #expect(FloconDatabaseResult.rawSuccess.json() == #"{"body":"{}","type":"RawSuccess"}"#)
        #expect(FloconDatabaseResult.insert(insertedId: 4).json() == #"{"body":"{\"insertedId\":4}","type":"Insert"}"#)
    }

    @Test func sendsTheDatabasesOnConnection() async throws {
        try makeDatabase(at: "dogs.sqlite")
        let sender = RecordingSender()
        let plugin = makePlugin(sender: sender)

        plugin.onConnectedToServer()

        let message = try #require(await sender.waitFor(method: "get_databases").first)
        let list = try JSONSerialization.jsonObject(with: Data(message.body.utf8)) as? [[String: String]]
        #expect(list?.map { $0["name"] } == ["Documents/dogs.sqlite"])
    }

    @Test func registeredDatabasesKeepTheirName() async throws {
        let found = try makeDatabase(at: "dogs.sqlite")
        let outsideFolder = FileManager.default.temporaryDirectory.appendingPathComponent("flocon-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outsideFolder, withIntermediateDirectories: true)
        let outside = outsideFolder.appendingPathComponent("other.db")
        try FileManager.default.copyItem(at: found, to: outside)
        let sender = RecordingSender()
        let plugin = makePlugin(sender: sender)

        plugin.register(FloconDatabase(displayName: "Dogs", url: found))
        plugin.register(FloconDatabase(displayName: "Other", url: outside))
        plugin.register(FloconDatabase(displayName: "Missing", url: outsideFolder.appendingPathComponent("missing.db")))

        #expect(plugin.databases().map(\.displayName) == ["Dogs", "Other"])
        #expect(await sender.waitFor(method: "get_databases", count: 3).count == 3)
        #expect(query("SELECT count(*) FROM dogs", on: outside, plugin: plugin) == .select(columns: ["count(*)"], values: [["2"]]))
    }

    @Test func logsQueries() throws {
        let sender = RecordingSender()
        let plugin = makePlugin(sender: sender)

        plugin.logQuery(dbId: "/data/app.sqlite", sqlQuery: "SELECT * FROM dogs WHERE id = ?", bindArgs: [1, nil, "Rex"])

        let message = try #require(sender.messages.first)
        #expect(message.method == "log_query")
        let log = try JSONSerialization.jsonObject(with: Data(message.body.utf8)) as? [String: Any]
        #expect(log?["dbId"] as? String == "/data/app.sqlite")
        #expect(log?["sqlQuery"] as? String == "SELECT * FROM dogs WHERE id = ?")
        #expect(log?["bindArgs"] as? [String] == ["1", "null", "Rex"])
        #expect(log?["timestamp"] is Int64)
    }

    @Test func logsQueriesWithTheIdOfTheDatabaseFile() throws {
        let sender = RecordingSender()
        let plugin = makePlugin(sender: sender)
        let url = URL(fileURLWithPath: "/tmp/../tmp/app.sqlite")

        plugin.logQuery(database: url, sqlQuery: "SELECT 1")

        let message = try #require(sender.messages.first)
        let log = try JSONSerialization.jsonObject(with: Data(message.body.utf8)) as? [String: Any]
        #expect(log?["dbId"] as? String == FloconDatabase(displayName: "App", url: url).id)
    }

    // MARK: Discovery

    @Test func findsSQLiteFilesWhateverTheirExtension() throws {
        try makeDatabase(at: "store")
        try makeDatabase(at: "nested/deeper/app.sqlite")
        try Data("not a database".utf8).write(to: folder.appendingPathComponent("notes.sqlite"))
        try Data("SQLite format 3\0".utf8).write(to: folder.appendingPathComponent("store-wal"))

        let names = FloconDatabaseDiscovery(roots: [("Documents", folder)]).databases().map(\.displayName)

        #expect(names == ["Documents/nested/deeper/app.sqlite", "Documents/store"])
    }

    @Test func stopsAtTheMaximumDepth() throws {
        try makeDatabase(at: "a/b/c/deep.sqlite")
        var discovery = FloconDatabaseDiscovery(roots: [("Documents", folder)])
        discovery.maxDepth = 3

        #expect(discovery.databases().isEmpty)
        discovery.maxDepth = 4
        #expect(discovery.databases().map(\.displayName) == ["Documents/a/b/c/deep.sqlite"])
    }
}
