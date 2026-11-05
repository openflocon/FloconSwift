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

    @Test func configFallsBackToTheDefaultPortsWhenInvalid() {
        var builder = FloconBuilder()
        builder.config(webSocketPort: 0, httpPort: 70_000)
        #expect(builder.config.webSocketPort == 9023)
        #expect(builder.config.httpPort == 9024)

        builder.config(webSocketPort: -1, httpPort: 65_535)
        #expect(builder.config.webSocketPort == 9023)
        #expect(builder.config.httpPort == 65_535)
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
    private func parse(_ address: String) throws -> FloconAddress {
        try FloconAddress(parsing: address, webSocketPort: 9023, httpPort: 9024)
    }

    @Test func readsAHostWithTheDefaultPorts() throws {
        #expect(try parse("192.168.1.20") == FloconAddress(host: "192.168.1.20", webSocketPort: 9023, httpPort: 9024))
        #expect(try parse(" my-mac.local ") == FloconAddress(host: "my-mac.local", webSocketPort: 9023, httpPort: 9024))
        let custom = try FloconAddress(parsing: "localhost", webSocketPort: 9500, httpPort: 9501)
        #expect(custom.webSocketURL == URL(string: "wss://localhost:9500")!)
        #expect(custom.httpPort == 9501)
    }

    @Test func readsTheWebSocketPort() throws {
        #expect(try parse("host:10023") == FloconAddress(host: "host", webSocketPort: 10023, httpPort: 9024))
        #expect(try parse("my-mac.local:1").webSocketURL == URL(string: "wss://my-mac.local:1")!)
        #expect(try parse("host:65535").webSocketPort == 65535)
    }

    @Test func readsBothPorts() throws {
        let address = try parse("192.168.1.10:10023:10024")
        #expect(address == FloconAddress(host: "192.168.1.10", webSocketPort: 10023, httpPort: 10024))
        #expect(address.webSocketURL == URL(string: "wss://192.168.1.10:10023")!)
        #expect(try parse("host:9023:65535").httpPort == 65535)
    }

    @Test func refusesAnInvalidPort() {
        let addresses = [
            "host:a:b", "host:1:2:3", "host:1:", "host::2", "host:0:9", "host:9:99999", "host:123456:1",
            "host:0", "host:99999", "host:65536", "host:abc", "host:", "host:-1", ":9100", "host:9:0", "host:0009023"
        ]
        for address in addresses {
            #expect(throws: FloconAddressError.self) { try parse(address) }
        }
    }

    @Test func refusesASchemeAPathOrAnEmptyAddress() {
        for address in ["", "  ", "ws://192.168.1.20", "wss://host:9100", "192.168.1.20/path", "host?x=1", "host#a", "my mac", "host: 9100"] {
            #expect(throws: FloconAddressError.self) { try parse(address) }
        }
    }

    @Test func storesThePortsOnlyWhenTheyDifferFromTheConfiguredOnes() throws {
        #expect(try parse("host").stored(webSocketPort: 9023, httpPort: 9024) == "host")
        #expect(try parse("host:9023:9024").stored(webSocketPort: 9023, httpPort: 9024) == "host")
        #expect(try parse("host:10023").stored(webSocketPort: 9023, httpPort: 9024) == "host:10023:9024")
        #expect(try parse("host:9023:10024").stored(webSocketPort: 9023, httpPort: 9024) == "host:9023:10024")
        // values stored by older versions (host, host:port) still load
        #expect(try parse("host:10023").httpPort == 9024)
    }
}
