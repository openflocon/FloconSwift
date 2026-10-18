import Foundation
import Testing
@testable import Flocon

@Suite struct FloconFileSystemTests {
    private let root: URL
    private let caches: URL
    private let fileSystem: FloconFileSystem

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("flocon-tests-\(UUID().uuidString)", isDirectory: true)
        caches = root.appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        fileSystem = FloconFileSystem(rootURL: root, cachesURL: caches)
    }

    private func write(_ text: String, to relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    @Test func mapsConstantPaths() {
        #expect(fileSystem.url(forPath: "files", isConstantPath: true) == root)
        #expect(fileSystem.url(forPath: "caches", isConstantPath: true) == caches)
    }

    @Test func refusesPathsOutsideTheContainer() throws {
        #expect(fileSystem.url(forPath: "/etc/hosts", isConstantPath: false) == nil)
        #expect(fileSystem.url(forPath: root.path + "/../outside", isConstantPath: false) == nil)

        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/etc"))
        #expect(fileSystem.url(forPath: link.path, isConstantPath: false) == nil)

        #expect(fileSystem.url(forPath: root.appendingPathComponent("Documents").path, isConstantPath: false) != nil)
    }

    @Test func listsFolderContent() throws {
        try write("12345", to: "Documents/a.txt")
        try write("123", to: "Documents/sub/b.txt")

        let documents = root.appendingPathComponent("Documents")
        let withoutSizes = fileSystem.contentsOfFolder(documents, withFoldersSize: false)
        #expect(withoutSizes.map(\.name) == ["a.txt", "sub"])
        #expect(withoutSizes[0].isDirectory == false && withoutSizes[0].size == 5)
        #expect(withoutSizes[1].isDirectory == true && withoutSizes[1].size == 0)
        #expect(withoutSizes[0].lastModified > 0)

        let withSizes = fileSystem.contentsOfFolder(documents, withFoldersSize: true)
        #expect(withSizes[1].size == 3)
    }

    @Test func deletesInsideTheContainerOnly() throws {
        try write("x", to: "Documents/a.txt")
        try write("y", to: "Library/Caches/c.txt")
        let file = root.appendingPathComponent("Documents/a.txt")

        fileSystem.deleteItem(atPath: file.path)
        #expect(!FileManager.default.fileExists(atPath: file.path))

        // root folders are kept
        fileSystem.deleteItem(atPath: root.path)
        fileSystem.deleteItem(atPath: caches.path)
        #expect(FileManager.default.fileExists(atPath: caches.path))

        fileSystem.deleteContents(ofFolder: caches)
        #expect(FileManager.default.fileExists(atPath: caches.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: caches.path).isEmpty)
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
