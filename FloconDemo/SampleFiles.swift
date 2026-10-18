import UIKit

/// Sample files, to browse, download and delete from the Files section of Flocon Desktop.
enum SampleFiles {
    /// Writes a few files of different kinds in `Documents`, `Library/Application Support` and `Library/Caches`.
    ///
    /// - Returns: The number of files written.
    @discardableResult
    static func seed() -> Int {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        let files: [(URL, Data)] = [
            (documents.appendingPathComponent("profile.json"), profileJSON()),
            (documents.appendingPathComponent("notes/todo.txt"), Data("- Try the Files section of Flocon\n- Download this file\n- Delete it\n".utf8)),
            (documents.appendingPathComponent("notes/ideas.md"), Data("# Ideas\n\nDebug the app from the desktop.\n".utf8)),
            (support.appendingPathComponent("settings.plist"), settingsPlist()),
            (caches.appendingPathComponent("images/avatar.png"), avatarPNG()),
            (caches.appendingPathComponent("response-cache.bin"), Data((0..<200_000).map { UInt8($0 % 256) })),
        ]

        var written = 0
        for (url, data) in files {
            do {
                try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url)
                written += 1
            } catch {
                print("[FloconDemo] cannot write \(url.lastPathComponent): \(error)")
            }
        }
        return written
    }

    private static func profileJSON() -> Data {
        let profile: [String: Any] = ["name": "Florent", "plan": "pro", "devices": ["iPhone", "Mac"]]
        return (try? JSONSerialization.data(withJSONObject: profile, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    private static func settingsPlist() -> Data {
        let settings: [String: Any] = ["theme": "dark", "notifications": true, "volume": 0.8]
        return (try? PropertyListSerialization.data(fromPropertyList: settings, format: .xml, options: 0)) ?? Data()
    }

    private static func avatarPNG() -> Data {
        let size = CGSize(width: 128, height: 128)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.systemBlue.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }
        return image.pngData() ?? Data()
    }
}
