import Foundation

/// Lets the Flocon desktop app browse, download and delete the files of the app.
///
/// The desktop asks for the root folders (`getRoots`): the folders of every app, then the ones
/// registered with ``register(_:)``. It then lists a folder (`listFiles`), downloads a file
/// (`getFile`, sent over HTTP) and deletes files or folder contents, after which the folder is
/// listed again. Every path is limited to the root folders.
public final class FloconFilesPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "files"
    // desktop -> app
    private static let methodGetRoots = "getRoots"
    private static let methodListFiles = "listFiles"
    private static let methodGetFile = "getFile"
    private static let methodDeleteFile = "deleteFile"
    private static let methodDeleteFiles = "deleteFiles"
    private static let methodDeleteFolderContent = "deleteFolderContent"
    // app -> desktop: older desktop versions compare method names case-sensitively
    private static let methodListFilesResult = "listFiles"
    private static let methodGetRootsResult = "getRoots"

    public let pluginName = FloconFilesPlugin.name
    private weak var sender: FloconMessageSender?
    private weak var fileSender: FloconFileSender?
    private let defaultRoots: [FloconFileRoot]

    /// File operations can be slow: they run in order, off the thread that receives the messages.
    private let queue = DispatchQueue(label: "io.github.openflocon.files")
    private let lock = NSLock()
    private var withFoldersSize = false
    // in registration order, a folder registered again keeps its place
    private var registered: [FloconFileRoot] = []

    init(sender: FloconMessageSender, fileSender: FloconFileSender, defaultRoots: [FloconFileRoot] = FloconFileRoot.appDefaults) {
        self.sender = sender
        self.fileSender = fileSender
        self.defaultRoots = defaultRoots
    }

    /// Shows a folder in the desktop app, or renames a folder already shown.
    ///
    /// - Parameter folder: The folder.
    public func register(_ folder: FloconFolder) {
        let root = FloconFileRoot(folder: folder)
        lock.lock()
        if let index = registered.firstIndex(where: { $0.id == root.id }) {
            registered[index] = root
        } else {
            registered.append(root)
        }
        lock.unlock()
    }

    /// The root folders: the default ones, then the registered ones.
    var fileSystem: FloconFileSystem {
        lock.lock(); defer { lock.unlock() }
        // a registered folder renames a default one at the same location
        let registeredPaths = Set(registered.map(\.id))
        let defaults = defaultRoots.filter { !registeredPaths.contains(FloconFileSystem.resolved($0.url).path) }
        return FloconFileSystem(roots: defaults + registered)
    }

    // MARK: FloconPlugin

    public func onConnectedToServer() {}

    public func onMessageReceived(_ message: FloconMessageFromServer) {
        let body = Data(message.body.utf8)
        let decoder = JSONDecoder()
        switch message.method {
        case Self.methodGetRoots:
            guard let request = try? decoder.decode(ToDeviceGetRootsMessage.self, from: body) else { return }
            queue.async { self.sendRoots(requestId: request.requestId) }

        case Self.methodListFiles:
            guard let request = try? decoder.decode(ToDeviceGetFilesMessage.self, from: body) else { return }
            lock.lock(); withFoldersSize = request.withFoldersSize ?? false; lock.unlock()
            queue.async { self.sendListing(path: request.path, isConstantPath: request.isConstantPath, requestId: request.requestId) }

        case Self.methodGetFile:
            guard let request = try? decoder.decode(ToDeviceGetFileMessage.self, from: body),
                  let url = fileSystem.url(forPath: request.path, isConstantPath: false) else { return }
            let fileSender = fileSender
            Task { await fileSender?.sendFile(at: url, remotePath: request.path, requestId: request.requestId) }

        case Self.methodDeleteFile:
            guard let request = try? decoder.decode(ToDeviceDeleteFileMessage.self, from: body) else { return }
            queue.async {
                self.fileSystem.deleteItem(atPath: request.filePath)
                self.sendListing(path: request.parentPath, isConstantPath: request.isConstantParentPath, requestId: request.requestId)
            }

        case Self.methodDeleteFiles:
            guard let request = try? decoder.decode(ToDeviceDeleteFilesMessage.self, from: body) else { return }
            queue.async {
                let fileSystem = self.fileSystem
                request.filePaths.forEach(fileSystem.deleteItem(atPath:))
                self.sendListing(path: request.parentPath, isConstantPath: request.isConstantParentPath, requestId: request.requestId)
            }

        case Self.methodDeleteFolderContent:
            guard let request = try? decoder.decode(ToDeviceDeleteFolderContentMessage.self, from: body) else { return }
            queue.async {
                let fileSystem = self.fileSystem
                if let folder = fileSystem.url(forPath: request.path, isConstantPath: request.isConstantPath) {
                    fileSystem.deleteContents(ofFolder: folder)
                }
                self.sendListing(path: request.path, isConstantPath: request.isConstantPath, requestId: request.requestId)
            }

        default:
            break
        }
    }

    private func sendRoots(requestId: String) {
        let roots = fileSystem.existingRoots.map { FileRootRemote(id: $0.id, name: $0.name, path: $0.url.path) }
        send(FileRootsResultRemote(requestId: requestId, roots: roots), method: Self.methodGetRootsResult)
    }

    private func sendListing(path: String, isConstantPath: Bool, requestId: String) {
        lock.lock(); let withFoldersSize = withFoldersSize; lock.unlock()
        let fileSystem = fileSystem
        let files = fileSystem.url(forPath: path, isConstantPath: isConstantPath)
            .map { fileSystem.contentsOfFolder($0, withFoldersSize: withFoldersSize) } ?? []
        send(FilesResultRemote(requestId: requestId, files: files), method: Self.methodListFilesResult)
    }

    private func send(_ model: some Encodable, method: String) {
        do {
            let data = try JSONEncoder().encode(model)
            guard let json = String(data: data, encoding: .utf8) else { return }
            sender?.send(plugin: pluginName, method: method, body: json)
        } catch {
            FloconLogger.logError("Files json mapping error", error)
        }
    }
}
