import Foundation

/// Options of the files plugin.
public struct FloconFilesOptions {
    var folders: [FloconFolder] = []
    var appGroups: [String] = []

    /// Lists a folder in the desktop app. The usual folders of the app are shown automatically.
    public mutating func folder(displayName: String, url: URL) {
        folders.append(FloconFolder(displayName: displayName, url: url))
    }

    /// Lists the container of an App Group.
    public mutating func appGroup(_ identifier: String) {
        appGroups.append(identifier)
    }
}

extension FloconFeature where Options == FloconFilesOptions {
    /// Lets the desktop app browse the files of the app.
    public static var files: FloconFeature<FloconFilesOptions> {
        .init(
            kind: .files,
            makeOptions: { FloconFilesOptions() },
            apply: { options in
                options.folders.forEach(floconRegisterFolder)
                options.appGroups.forEach(floconRegisterAppGroup)
            }
        )
    }
}
