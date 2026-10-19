import Foundation

/// A folder the desktop can open, shown at the top of the Files section.
struct FloconFileRoot: Sendable, Equatable {
    /// Stable identifier, sent back by the desktop as a constant path.
    let id: String
    /// Name shown in the desktop app.
    let name: String
    let url: URL

    /// Folders of every app: `Documents`, `Application Support`, `Caches`, `tmp` and the whole container.
    static let appDefaults: [FloconFileRoot] = {
        let fileManager = FileManager.default
        func directory(_ directory: FileManager.SearchPathDirectory) -> URL {
            fileManager.urls(for: directory, in: .userDomainMask)[0]
        }
        return [
            FloconFileRoot(id: "documents", name: "Documents", url: directory(.documentDirectory)),
            FloconFileRoot(id: "applicationSupport", name: "Application Support", url: directory(.applicationSupportDirectory)),
            FloconFileRoot(id: "caches", name: "Caches", url: directory(.cachesDirectory)),
            FloconFileRoot(id: "tmp", name: "tmp", url: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)),
            FloconFileRoot(id: "container", name: "App container", url: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)),
        ]
    }()

    /// A folder registered by the app, identified by its path.
    init(folder: FloconFolder) {
        self.init(id: FloconFileSystem.resolved(folder.url).path, name: folder.displayName, url: folder.url)
    }

    init(id: String, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }
}

/// File operations requested by the Flocon desktop app, limited to the root folders.
///
/// The desktop opens a root folder by its ``FloconFileRoot/id``, then any path inside it.
/// Paths outside every root folder are refused, and the root folders themselves are never deleted.
struct FloconFileSystem: Sendable {
    /// Folders the desktop can access, in the order they are shown.
    let roots: [FloconFileRoot]

    /// Root folders that exist, as shown in the desktop app.
    var existingRoots: [FloconFileRoot] {
        roots.filter { root in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: root.url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    /// Returns the folder or file a desktop path points to.
    ///
    /// - Parameters:
    ///   - path: The identifier of a root folder or an absolute path.
    ///   - isConstantPath: Whether `path` is the identifier of a root folder.
    /// - Returns: The URL, or `nil` if it is outside every root folder.
    func url(forPath path: String, isConstantPath: Bool) -> URL? {
        if isConstantPath {
            return roots.first { $0.id == path }?.url
        }
        let url = URL(fileURLWithPath: path)
        return contains(url) ? url : nil
    }

    /// Whether a URL is a root folder or inside one, once symbolic links are resolved.
    func contains(_ url: URL) -> Bool {
        let candidate = Self.resolved(url).pathComponents
        return roots.contains { candidate.starts(with: Self.resolved($0.url).pathComponents) }
    }

    static func resolved(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    // MARK: Listing

    /// Lists the content of a folder, sorted by name.
    ///
    /// - Parameters:
    ///   - folder: The folder to list.
    ///   - withFoldersSize: Whether to compute the size of each subfolder, which reads all its content.
    /// - Returns: The files and folders, or an empty array if the folder cannot be read.
    func contentsOfFolder(_ folder: URL, withFoldersSize: Bool) -> [FileRemote] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: []
        ) else {
            FloconLogger.log("Cannot list folder \(folder.path)")
            return []
        }
        return children
            .map { child in
                let values = try? child.resourceValues(forKeys: Set(keys))
                let isDirectory = values?.isDirectory ?? false
                let size: Int64 = isDirectory
                    ? (withFoldersSize ? Self.sizeOfFolder(child) : 0)
                    : Int64(values?.fileSize ?? 0)
                let modified = values?.contentModificationDate ?? .distantPast
                return FileRemote(
                    name: child.lastPathComponent,
                    isDirectory: isDirectory,
                    path: child.path,
                    size: size,
                    lastModified: Int64(modified.timeIntervalSince1970 * 1000)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func sizeOfFolder(_ folder: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    // MARK: Deleting

    /// Deletes a file or folder inside a root folder. The root folders themselves are never deleted.
    func deleteItem(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        guard contains(url), !isRoot(url) else {
            FloconLogger.log("Refused to delete \(path): outside the root folders or a root folder")
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            FloconLogger.logError("Cannot delete \(path)", error)
        }
    }

    /// Deletes everything inside a folder, keeping the folder.
    func deleteContents(ofFolder folder: URL) {
        guard let children = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return
        }
        for child in children {
            deleteItem(atPath: child.path)
        }
    }

    private func isRoot(_ url: URL) -> Bool {
        let path = Self.resolved(url).path
        return roots.contains { Self.resolved($0.url).path == path }
    }
}
