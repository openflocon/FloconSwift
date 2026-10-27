import Foundation
import Testing
@testable import Flocon

@Suite struct FloconFileSystemTests {
    private let root: URL
    private let documents: URL
    private let caches: URL
    private let fileSystem: FloconFileSystem

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("flocon-tests-\(UUID().uuidString)", isDirectory: true)
        documents = root.appendingPathComponent("Documents", isDirectory: true)
        caches = root.appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        fileSystem = FloconFileSystem(roots: [
            FloconFileRoot(id: "documents", name: "Documents", url: documents),
            FloconFileRoot(id: "caches", name: "Caches", url: caches),
            FloconFileRoot(id: "missing", name: "Missing", url: root.appendingPathComponent("missing")),
        ])
    }

    private func write(_ text: String, to relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    @Test func mapsRootIdentifiers() {
        #expect(fileSystem.url(forPath: "documents", isConstantPath: true) == documents)
        #expect(fileSystem.url(forPath: "caches", isConstantPath: true) == caches)
        #expect(fileSystem.url(forPath: "files", isConstantPath: true) == nil)
    }

    @Test func showsOnlyExistingRoots() {
        #expect(fileSystem.existingRoots.map(\.id) == ["documents", "caches"])
    }

    @Test func refusesPathsOutsideTheRoots() throws {
        #expect(fileSystem.url(forPath: "/etc/hosts", isConstantPath: false) == nil)
        #expect(fileSystem.url(forPath: documents.path + "/../outside", isConstantPath: false) == nil)
        // inside the container, but in no root folder
        #expect(fileSystem.url(forPath: root.appendingPathComponent("Library").path, isConstantPath: false) == nil)

        let link = documents.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/etc"))
        #expect(fileSystem.url(forPath: link.path, isConstantPath: false) == nil)

        #expect(fileSystem.url(forPath: documents.appendingPathComponent("a.txt").path, isConstantPath: false) != nil)
        #expect(fileSystem.url(forPath: caches.appendingPathComponent("b.txt").path, isConstantPath: false) != nil)
    }

    @Test func listsFolderContent() throws {
        try write("12345", to: "Documents/a.txt")
        try write("123", to: "Documents/sub/b.txt")

        let withoutSizes = fileSystem.contentsOfFolder(documents, withFoldersSize: false)
        #expect(withoutSizes.map(\.name) == ["a.txt", "sub"])
        #expect(withoutSizes[0].isDirectory == false && withoutSizes[0].size == 5)
        #expect(withoutSizes[1].isDirectory == true && withoutSizes[1].size == 0)
        #expect(withoutSizes[0].lastModified > 0)

        let withSizes = fileSystem.contentsOfFolder(documents, withFoldersSize: true)
        #expect(withSizes[1].size == 3)
    }

    @Test func deletesInsideTheRootsOnly() throws {
        try write("x", to: "Documents/a.txt")
        try write("y", to: "Library/Caches/c.txt")
        try write("z", to: "Library/outside.txt")
        let file = documents.appendingPathComponent("a.txt")

        fileSystem.deleteItem(atPath: file.path)
        #expect(!FileManager.default.fileExists(atPath: file.path))

        fileSystem.deleteItem(atPath: root.appendingPathComponent("Library/outside.txt").path)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Library/outside.txt").path))

        // root folders are kept
        fileSystem.deleteItem(atPath: documents.path)
        fileSystem.deleteItem(atPath: caches.path)
        #expect(FileManager.default.fileExists(atPath: documents.path))
        #expect(FileManager.default.fileExists(atPath: caches.path))

        fileSystem.deleteContents(ofFolder: caches)
        #expect(FileManager.default.fileExists(atPath: caches.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: caches.path).isEmpty)
    }
}

private final class RecordingSender: FloconMessageSender, FloconFileSender, @unchecked Sendable {
    private let lock = NSLock()
    private var bodies: [String: [String]] = [:]

    func send(plugin: String, method: String, body: String) {
        lock.lock(); bodies[method, default: []].append(body); lock.unlock()
    }

    func sendFile(at fileURL: URL, remotePath: String, requestId: String) async {}

    private func lastBody(method: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return bodies[method]?.last
    }

    /// Waits for the plugin queue to send a message with this method.
    func waitFor(method: String) async -> String? {
        for _ in 0..<200 {
            if let body = lastBody(method: method) { return body }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return nil
    }
}

@Suite struct FloconFilesPluginTests {
    private struct RootsResult: Decodable {
        struct Root: Decodable, Equatable {
            let id: String
            let name: String
            let path: String
        }
        let requestId: String
        let roots: [Root]
    }

    private func message(_ method: String, _ body: String) throws -> FloconMessageFromServer {
        let json = try JSONSerialization.data(withJSONObject: ["plugin": "files", "method": method, "body": body])
        return try JSONDecoder().decode(FloconMessageFromServer.self, from: json)
    }

    @Test func sendsDefaultThenRegisteredRoots() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("flocon-tests-\(UUID().uuidString)", isDirectory: true)
        let documents = base.appendingPathComponent("Documents", isDirectory: true)
        let group = base.appendingPathComponent("Group", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)

        let sender = RecordingSender()
        let plugin = FloconFilesPlugin(
            sender: sender,
            fileSender: sender,
            defaultRoots: [FloconFileRoot(id: "documents", name: "Documents", url: documents)]
        )
        plugin.register(FloconFolder(displayName: "Old name", url: group))
        plugin.register(FloconFolder(displayName: "Group", url: group))
        plugin.register(FloconFolder(displayName: "Missing", url: base.appendingPathComponent("missing")))

        plugin.onMessageReceived(try message("getRoots", #"{"requestId":"1"}"#))
        let body = try #require(await sender.waitFor(method: "getRoots"))
        let result = try JSONDecoder().decode(RootsResult.self, from: Data(body.utf8))

        #expect(result.requestId == "1")
        #expect(result.roots.map(\.name) == ["Documents", "Group"])
        #expect(result.roots[0].id == "documents")
        #expect(result.roots[1].id == FloconFileSystem.resolved(group).path)

        // the registered folder is accessible, by identifier and by path
        let fileSystem = plugin.fileSystem
        #expect(fileSystem.url(forPath: result.roots[1].id, isConstantPath: true) == group)
        #expect(fileSystem.url(forPath: group.appendingPathComponent("a.txt").path, isConstantPath: false) != nil)
    }
}

@Suite struct FloconFileUploaderTests {
    @Test func writesAMultipartBody() throws {
        let directory = FileManager.default.temporaryDirectory
        let file = directory.appendingPathComponent("flocon-\(UUID().uuidString).txt")
        let body = directory.appendingPathComponent("flocon-body-\(UUID().uuidString)")
        try Data("content".utf8).write(to: file)

        try FloconFileUploader.writeBody(to: body, boundary: "B", fields: [("requestId", "42")], fileURL: file)

        let expected = """
        --B\r
        Content-Disposition: form-data; name="requestId"\r
        \r
        42\r
        --B\r
        Content-Disposition: form-data; name="file"; filename="\(file.lastPathComponent)"\r
        Content-Type: application/octet-stream\r
        \r
        content\r
        --B--\r

        """
        #expect(try String(contentsOf: body, encoding: .utf8) == expected)
    }
}
