import Foundation

/// Finds the SQLite files of the app, so that they are shown without being registered.
///
/// Core Data, GRDB and SQLite.swift stores are found whatever their extension: a file is a
/// database when it starts with the SQLite header.
struct FloconDatabaseDiscovery: Sendable {
    /// Folders scanned, with the name shown before the path of the files they contain.
    let roots: [(name: String, url: URL)]
    /// Number of nested folders scanned below a root.
    var maxDepth = 7

    /// Folders of the running app: `Documents` and `Library/Application Support`, where Core Data
    /// creates its stores by default.
    static let app = FloconDatabaseDiscovery(roots: [
        ("Documents", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]),
        ("Application Support", FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]),
    ])

    private static let sqliteHeader = Data("SQLite format 3\0".utf8)
    // files written next to a database by SQLite
    private static let companionSuffixes = ["-wal", "-shm", "-journal"]

    /// Returns the databases found in the roots.
    ///
    /// - Returns: The databases, named by their path from their root, such as `Documents/app.sqlite`.
    func databases() -> [FloconDatabase] {
        roots.flatMap { root in
            scan(root.url, depth: 0).map { url in
                let relative = Self.resolved(url).pathComponents
                    .dropFirst(Self.resolved(root.url).pathComponents.count)
                return FloconDatabase(displayName: ([root.name] + relative).joined(separator: "/"), url: url)
            }
        }
    }

    private func scan(_ folder: URL, depth: Int) -> [URL] {
        guard depth < maxDepth,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: folder,
                  includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey]
              )
        else { return [] }

        return items.sorted { $0.lastPathComponent < $1.lastPathComponent }.flatMap { url -> [URL] in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                return scan(url, depth: depth + 1)
            }
            guard values?.isRegularFile == true,
                  !Self.companionSuffixes.contains(where: url.lastPathComponent.hasSuffix),
                  Self.isSQLite(url)
            else { return [] }
            return [url]
        }
    }

    // /var and /private/var are the same folder on iOS
    private static func resolved(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    /// Whether a file starts with the SQLite header.
    static func isSQLite(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return handle.readData(ofLength: sqliteHeader.count) == sqliteHeader
    }
}
