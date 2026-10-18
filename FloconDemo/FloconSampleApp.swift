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
