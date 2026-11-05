import Foundation
import Testing
@testable import Flocon

@Suite struct FloconStartTests {
    @Test func nothingIsInstalledByDefault() {
        let builder = FloconBuilder()
        #expect(builder.features.isEmpty)
    }

    @Test func installAddsThePluginAndKeepsItsOptions() {
        var builder = FloconBuilder()
        builder.install(.analytics)
        builder.install(.database) { $0.register(displayName: "App", url: URL(fileURLWithPath: "/tmp/app.db")) }
        builder.install(.network) { $0.shouldLog = { _ in false } }

        #expect(builder.features == [.analytics, .database, .network])
        #expect(builder.applications.count == 3)
    }

    @Test func configChangesTheHost() {
        var builder = FloconBuilder()
        builder.config(host: "192.168.1.20")

        #expect(builder.config.host == "192.168.1.20")
        #expect(builder.config.webSocketPort == 9023)
    }

    @Test func connectKeepsTheDefaultOptionsWithoutABlock() {
        var builder = FloconBuilder()
        builder.connect()

        #expect(builder.config.bufferCapacity == 5_000)
        #expect(builder.config.additionalAddress == nil)
        #expect(builder.config.rememberLastAddress)
    }

    @Test func connectSetsTheOptions() {
        var builder = FloconBuilder()
        builder.connect { setup in
            setup.bufferCapacity = 100
            setup.address = "192.168.1.20"
            setup.rememberLastAddress = false
        }

        #expect(builder.config.bufferCapacity == 100)
        #expect(builder.config.additionalAddress == "192.168.1.20")
        #expect(!builder.config.rememberLastAddress)
    }
}

@Suite struct FloconAddressTests {
    @Test func readsAnIpAddressOrAHostWithThePort9023() throws {
        #expect(try floconWebSocketURL(address: "192.168.1.20", port: 9023) == URL(string: "wss://192.168.1.20:9023")!)
        #expect(try floconWebSocketURL(address: " my-mac.local ", port: 9023) == URL(string: "wss://my-mac.local:9023")!)
        #expect(try floconWebSocketURL(address: "localhost", port: 9023) == URL(string: "wss://localhost:9023")!)
    }

    @Test func refusesAPortASchemeAPathOrAnEmptyAddress() {
        for address in ["", "192.168.1.20:9023", "192.168.1.20:9100", "ws://192.168.1.20", "192.168.1.20/path", "my mac"] {
            #expect(throws: FloconAddressError.self) { try floconWebSocketURL(address: address, port: 9023) }
        }
    }
}
