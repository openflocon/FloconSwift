import Foundation

/// File operations requested by the Flocon desktop app, limited to the app container.
///
/// The desktop names two root folders: `"files"`, the root of the app container (with its
/// `Documents`, `Library` and `tmp` folders), and `"caches"`, its `Library/Caches` folder.
/// Paths outside the container are refused, even though the iOS sandbox would refuse most
/// of them anyway.
struct FloconFileSystem: Sendable {
    /// Root of the files the desktop can access.
    let rootURL: URL
    /// Folder opened by the `"caches"` constant.
    let cachesURL: URL

    /// File system of the running app.
    static let app = FloconFileSystem(
        rootURL: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        cachesURL: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    )

    /// Returns the folder or file a desktop path points to.
    ///
    /// - Parameters:
    ///   - path: A constant (`"files"`, `"caches"`) or an absolute path.
    ///   - isConstantPath: Whether `path` is a constant.
    /// - Returns: The URL, or `nil` if it is outside the app container.
    func url(forPath path: String, isConstantPath: Bool) -> URL? {
        if isConstantPath {
            switch path {
            case "files": return rootURL
            case "caches": return cachesURL
            default: break
            }
        }
        let url = URL(fileURLWithPath: path)
        return contains(url) ? url : nil
    }

    /// Whether a URL is the root folder or inside it, once symbolic links are resolved.
    func contains(_ url: URL) -> Bool {
        let root = Self.resolved(rootURL).pathComponents
        let candidate = Self.resolved(url).pathComponents
        return candidate.starts(with: root)
    }

    private static func resolved(_ url: URL) -> URL {
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

    /// Deletes a file or folder inside the container. The root folders themselves are never deleted.
    func deleteItem(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        guard contains(url), !isRoot(url) else {
            FloconLogger.log("Refused to delete \(path): outside the app container or a root folder")
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
        return path == Self.resolved(rootURL).path || path == Self.resolved(cachesURL).path
    }
}
