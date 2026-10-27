import SwiftUI
import Flocon
import Kingfisher

@main
struct FloconSampleApp: App {
    init() {
        // picsum URLs are treated as images: their body is not sent to Flocon.
        Flocon.setNetworkOptions(
            FloconNetworkOptions(
                shouldLog: { _ in true },
                isImage: { request, _ in
                    request.url?.absoluteString.contains("picsum") == true
                }
            )
        )

        // Flocon.initialize(config: FloconConfig(host: "192.168.1.20")) // on a real iPhone
        Flocon.initialize()

        // Kingfisher downloads through its own URLSession: give it an intercepted
        // configuration, same as with Alamofire.
        KingfisherManager.shared.downloader.sessionConfiguration = URLSessionConfiguration.default.withFlocon()

        // UserDefaults.standard is shown automatically; other suites are registered.
        SamplePreferences.seed()
        floconRegisterUserDefaults(SamplePreferences.suite, suiteName: SamplePreferences.suiteName)

        SampleFiles.seed()
        // Documents, Application Support, Caches, tmp and the app container are shown automatically;
        // other folders, such as an App Group container, are registered.
        floconRegisterFolder(
            displayName: "Preferences",
            url: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Preferences")
        )
        SampleDatabase.seed()
        SampleDashboard.shared.start()
        SampleFeatureFlags.register()

        // Listed in the Deeplinks section of Flocon Desktop. Try them on the simulator with:
        // xcrun simctl openurl booted "flocondemo://user/Florent"
        floconRegisterDeeplinks(
            [
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
            ],
            variables: [
                FloconDeeplinkVariable("scheme", description: "URL scheme of the app", suggestions: ["flocondemo"]),
                FloconDeeplinkVariable("comment", description: "Text of the comment"),
            ]
        )

        // The keychain is opt-in, and should only be shown in debug builds:
        // its values are sent unencrypted to the Mac running Flocon.
        #if DEBUG
        SampleKeychain.seed()
        floconRegisterKeychain(isEditable: true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
