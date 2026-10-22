import SwiftUI

struct NetworkScreen: View {
    private let client = SampleNetworkClient()

    var body: some View {
        SampleScreenContainer(screen: .network) {
            SampleSection(title: "HTTP") {
                SampleActionRow(title: "URLSession GET", detail: "Simple JSON request") { try await client.simpleGet() }
                SampleActionRow(title: "URLSession gzip", detail: "Compressed response body") { try await client.gzipGet() }
                SampleActionRow(title: "POST JSON", detail: "Headers and JSON body") { try await client.post() }
                SampleActionRow(title: "Image", detail: "Body not sent to Flocon (isImage)") { try await client.image() }
                SampleActionRow(title: "Slow call", detail: "2 seconds, to see the duration") { try await client.slow() }
            }
            SampleSection(title: "Errors") {
                SampleActionRow(title: "404", detail: "HTTP error status") { try await client.notFound() }
                SampleActionRow(title: "Network error", detail: "Unknown host, logged with an error") { try await client.networkError() }
            }
            SampleSection(title: "Realtime & APIs") {
                SampleActionRow(title: "WebSocket echo", detail: "Events logged by hand", buttonTitle: "Send") { try await client.websocketEcho() }
                SampleActionRow(title: "GraphQL", detail: "Query on a public API") { try await client.graphQL() }
            }
        }
    }
}
