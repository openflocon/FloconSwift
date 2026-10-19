import Foundation

// MARK: - From device

/// JSON format of the content of a folder, sent in answer to a desktop request.
struct FilesResultRemote: Encodable {
    let requestId: String
    let files: [FileRemote]
}

/// JSON format of a file or folder in a listing.
struct FileRemote: Encodable, Equatable {
    let name: String
    let isDirectory: Bool
    /// Absolute path, sent back by the desktop to open, download or delete the item.
    let path: String
    /// Size in bytes; for a folder, the size of its content when requested, `0` otherwise.
    let size: Int64
    /// Last modification date, in milliseconds since 1970.
    let lastModified: Int64
}

// MARK: - To device

/// Desktop request for the content of a folder.
struct ToDeviceGetFilesMessage: Decodable {
    let requestId: String
    /// The identifier of a root folder when `isConstantPath` is `true`, an absolute path otherwise.
    let path: String
    let isConstantPath: Bool
    let withFoldersSize: Bool?
}

/// Desktop request to download a file.
struct ToDeviceGetFileMessage: Decodable {
    let requestId: String
    let path: String
}

/// Desktop request to delete a file or folder, then list its parent folder.
struct ToDeviceDeleteFileMessage: Decodable {
    let requestId: String
    let parentPath: String
    let filePath: String
    let isConstantParentPath: Bool
}

/// Desktop request to delete several files or folders, then list their parent folder.
struct ToDeviceDeleteFilesMessage: Decodable {
    let requestId: String
    let parentPath: String
    let filePaths: [String]
    let isConstantParentPath: Bool
}

/// Desktop request to empty a folder, then list it.
struct ToDeviceDeleteFolderContentMessage: Decodable {
    let requestId: String
    let path: String
    let isConstantPath: Bool
}

/// Desktop request for the root folders.
struct ToDeviceGetRootsMessage: Decodable {
    let requestId: String
}

// MARK: - Root folders, from device

/// JSON format of the root folders, sent in answer to a desktop request.
struct FileRootsResultRemote: Encodable {
    let requestId: String
    let roots: [FileRootRemote]
}

/// JSON format of a root folder.
struct FileRootRemote: Encodable, Equatable {
    /// Identifier sent back by the desktop as a constant path.
    let id: String
    /// Name shown in the desktop app.
    let name: String
    /// Absolute path.
    let path: String
}
