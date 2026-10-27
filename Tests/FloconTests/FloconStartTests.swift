import Foundation
import Testing
@testable import Flocon

@Suite struct FloconStartTests {
    @Test func onlyTheDeviceIsInstalledByDefault() {
        let builder = FloconBuilder()
        #expect(builder.features == [.device])
    }

    @Test func installAddsThePluginAndKeepsItsOptions() {
        var builder = FloconBuilder()
        builder.install(.analytics)
        builder.install(.database) { $0.register(displayName: "App", url: URL(fileURLWithPath: "/tmp/app.db")) }
        builder.install(.network) { $0.shouldLog = { _ in false } }

        #expect(builder.features == [.device, .analytics, .database, .network])
        #expect(builder.applications.count == 3)
    }

    @Test func configChangesTheHost() {
        var builder = FloconBuilder()
        builder.config(host: "192.168.1.20")

        #expect(builder.config.host == "192.168.1.20")
        #expect(builder.config.webSocketPort == 9023)
    }

    @Test func connectsAutomaticallyByDefault() {
        let builder = FloconBuilder()

        #expect(builder.config.connectsAutomatically)
        #expect(builder.config.bufferCapacity == 5_000)
    }

    @Test func connectLaterKeepsTheMessagesInMemory() {
        var builder = FloconBuilder()
        builder.connectLater(bufferCapacity: 100)

        #expect(!builder.config.connectsAutomatically)
        #expect(builder.config.bufferCapacity == 100)
    }
}
