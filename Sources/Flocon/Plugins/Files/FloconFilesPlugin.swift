import Foundation

/// Lets the Flocon desktop app browse, download and delete the files of the app.
///
/// The desktop lists a folder (`listFiles`), downloads a file (`getFile`, sent over HTTP) and
/// deletes files or folder contents, after which the folder is listed again. Every path is
/// limited to the app container, see ``FloconFileSystem``.
final class FloconFilesPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "files"
    // desktop -> app
    private static let methodListFiles = "listFiles"
    private static let methodGetFile = "getFile"
    private static let methodDeleteFile = "deleteFile"
    private static let methodDeleteFiles = "deleteFiles"
    private static let methodDeleteFolderContent = "deleteFolderContent"
    // app -> desktop: older desktop versions compare method names case-sensitively
    private static let methodListFilesResult = "listFiles"

    let pluginName = FloconFilesPlugin.name
    private weak var sender: FloconMessageSender?
    private weak var fileSender: FloconFileSender?
    private let fileSystem: FloconFileSystem

    /// File operations can be slow: they run in order, off the thread that receives the messages.
    private let queue = DispatchQueue(label: "io.github.openflocon.files")
    private let lock = NSLock()
    private var withFoldersSize = false

    init(sender: FloconMessageSender, fileSender: FloconFileSender, fileSystem: FloconFileSystem = .app) {
        self.sender = sender
        self.fileSender = fileSender
        self.fileSystem = fileSystem
    }

    func onConnectedToServer() {}

    func onMessageReceived(_ message: FloconMessageFromServer) {
        let body = Data(message.body.utf8)
        let decoder = JSONDecoder()
        switch message.method {
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
                request.filePaths.forEach(self.fileSystem.deleteItem(atPath:))
                self.sendListing(path: request.parentPath, isConstantPath: request.isConstantParentPath, requestId: request.requestId)
            }

        case Self.methodDeleteFolderContent:
            guard let request = try? decoder.decode(ToDeviceDeleteFolderContentMessage.self, from: body) else { return }
            queue.async {
                if let folder = self.fileSystem.url(forPath: request.path, isConstantPath: request.isConstantPath) {
                    self.fileSystem.deleteContents(ofFolder: folder)
                }
                self.sendListing(path: request.path, isConstantPath: request.isConstantPath, requestId: request.requestId)
            }

        default:
            break
        }
    }

    private func sendListing(path: String, isConstantPath: Bool, requestId: String) {
        lock.lock(); let withFoldersSize = withFoldersSize; lock.unlock()
        let files = fileSystem.url(forPath: path, isConstantPath: isConstantPath)
            .map { fileSystem.contentsOfFolder($0, withFoldersSize: withFoldersSize) } ?? []
        let result = FilesResultRemote(requestId: requestId, files: files)
        do {
            let data = try JSONEncoder().encode(result)
            guard let json = String(data: data, encoding: .utf8) else { return }
            sender?.send(plugin: pluginName, method: Self.methodListFilesResult, body: json)
        } catch {
            FloconLogger.logError("Files json mapping error", error)
        }
    }
}
