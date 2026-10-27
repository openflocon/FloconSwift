import SwiftUI
import Flocon
import Kingfisher

@main
struct FloconSampleApp: App {
    init() {
        // Only the installed plugins are started.
        startFlocon { flocon in
            // flocon.config(host: "192.168.1.20") // on a real iPhone

            // picsum URLs are treated as images: their body is not sent to Flocon.
            flocon.install(.network) { options in
                options = FloconNetworkOptions(
                    shouldLog: { _ in true },
                    isImage: { request, _ in
                        request.url?.absoluteString.contains("picsum") == true
                    }
                )
            }
            flocon.install(.database)
            flocon.install(.analytics)
            flocon.install(.featureFlags)
            flocon.install(.tables)
            flocon.install(.dashboard)
            flocon.install(.crashReporter)

            // UserDefaults.standard is shown automatically; other suites are registered.
            flocon.install(.preferences) { preferences in
                preferences.userDefaults(SamplePreferences.suite, suiteName: SamplePreferences.suiteName)
                // The keychain is opt-in, and should only be shown in debug builds:
                // its values are sent unencrypted to the Mac running Flocon.
                #if DEBUG
                preferences.keychain(isEditable: true)
                #endif
            }

            // Documents, Application Support, Caches, tmp and the app container are shown automatically;
            // other folders, such as an App Group container, are registered.
            flocon.install(.files) { files in
                files.folder(
                    displayName: "Preferences",
                    url: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Preferences")
                )
            }

            // Listed in the Deeplinks section of Flocon Desktop. Try them on the simulator with:
            // xcrun simctl openurl booted "flocondemo://user/Florent"
            flocon.install(.deeplinks) { $0.register(SampleDeeplinks.links, variables: SampleDeeplinks.variables) }
        }

        // Kingfisher downloads through its own URLSession: give it an intercepted
        // configuration, same as with Alamofire.
        KingfisherManager.shared.downloader.sessionConfiguration = URLSessionConfiguration.default.withFlocon()

        SamplePreferences.seed()
        SampleFiles.seed()
        SampleDatabase.seed()
        SampleDashboard.shared.start()
        SampleFeatureFlags.register()
        #if DEBUG
        SampleKeychain.seed()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum SampleDeeplinks {
    static let links: [FloconDeeplink] = [
        FloconDeeplink("[scheme]://home", label: "Home", parameters: [.variable("scheme", variableName: "scheme")]),
        FloconDeeplink(
            "[scheme]://user/[userId]",
            label: "User",
            description: "Open the profile of a user",
            parameters: [
                .variable("scheme", variableName: "scheme"),
                .autoComplete("userId", ["Florent", "David", "Guillaume"]),
            ]
        ),
        FloconDeeplink(
            "[scheme]://post/[postId]?comment=[comment]",
            label: "Post",
            description: "Open a post and prefill a comment",
            parameters: [
                .variable("scheme", variableName: "scheme"),
                .autoComplete("postId", ["1", "2", "3"]),
                .variable("comment", variableName: "comment"),
            ]
        ),
    ]

    static let variables: [FloconDeeplinkVariable] = [
        FloconDeeplinkVariable("scheme", description: "URL scheme of the app", suggestions: ["flocondemo"]),
        FloconDeeplinkVariable("comment", description: "Text of the comment"),
    ]
}
