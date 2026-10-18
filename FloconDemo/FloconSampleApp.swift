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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
