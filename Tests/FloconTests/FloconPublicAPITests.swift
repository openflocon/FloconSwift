import Foundation
import Testing
// not @testable: this file only compiles if the API it uses is public
import Flocon

/// A store of the app, shown through the public preferences API.
final class FeatureFlagsPreference: FloconPreference, @unchecked Sendable {
    let name = "Feature flags"
    private var flags = ["new_onboarding": true]

    func keys() -> [String] { flags.keys.sorted() }

    func value(forKey key: String) -> FloconPreferenceValue? {
        flags[key].map { FloconPreferenceValue(booleanValue: $0) }
    }

    func setValue(_ value: FloconPreferenceValue, forKey key: String) {
        if let isEnabled = value.booleanValue { flags[key] = isEnabled }
    }
}

@Suite struct FloconPublicAPITests {
    @Test func pluginsAreNilBeforeInitialize() {
        #expect(Flocon.shared.networkPlugin == nil)
        #expect(Flocon.shared.analyticsPlugin == nil)
        #expect(Flocon.shared.featureFlagsPlugin == nil)
        #expect(Flocon.shared.tablePlugin == nil)
        #expect(Flocon.shared.preferencesPlugin == nil)
        #expect(Flocon.shared.deeplinksPlugin == nil)
        #expect(Flocon.shared.filesPlugin == nil)
    }

    @Test func staticPluginsDoNothingBeforeInitialize() {
        // never nil, and every call is accepted without crashing
        Flocon.analyticsPlugin.sender("firebase").logEvents(AnalyticsEvent(eventName: "app_opened"))
        Flocon.featureFlagsPlugin.sender("firebase").register(FloconFeatureFlag(name: "a", state: .on, variant: "on"))
        Flocon.tablePlugin.table("users").log(TableColumnConfig("id", "1"))
        Flocon.networkPlugin.logWebSocketEvent(FloconWebSocketEvent(websocketUrl: "wss://example.com", event: .open))
        Flocon.databasePlugin.register(displayName: "App", url: FileManager.default.temporaryDirectory)
        Flocon.databasePlugin.logQuery(dbName: "App", sqlQuery: "SELECT 1")
        Flocon.deeplinksPlugin.register(deeplinks: [FloconDeeplink("myapp://home", label: "Home")])
        Flocon.preferencesPlugin.registerKeychain()
        Flocon.dashboardPlugin.dashboard(id: "main") {}
        #expect(Flocon.analyticsPlugin === Flocon.analyticsPlugin)
    }

    @Test func registersFoldersBeforeInitialize() {
        // does nothing before initialize, but must compile and not crash
        Flocon.filesPlugin.register(displayName: "Exports", url: FileManager.default.temporaryDirectory)
        Flocon.filesPlugin.register(displayName: "Exports", absolutePath: NSTemporaryDirectory())
        Flocon.filesPlugin.registerAppGroup("group.io.github.openflocon.tests")
        Flocon.filesPlugin.register(FloconFolder(displayName: "Exports", url: FileManager.default.temporaryDirectory))
    }

    @Test func buildsNetworkCalls() {
        let request = FloconNetworkCallRequest(
            networkType: "grpc",
            request: FloconNetworkRequest(url: "localhost:50051", method: "helloworld.Greeter/SayHello", body: #"{"name":"a"}"#)
        )
        let response = FloconNetworkCallResponse(
            callId: request.callId,
            networkType: "grpc",
            durationMs: 3,
            response: FloconNetworkResponse(grpcStatus: "OK", body: #"{"message":"Hello a"}"#)
        )
        #expect(!request.callId.isEmpty)
        #expect(response.callId == request.callId)
        #expect(!request.isMocked && !response.response.isImage)

        // no client yet: must not crash
        Flocon.networkPlugin.logRequest(request)
        Flocon.networkPlugin.logResponse(response)
    }

    @Test func implementsACustomPreference() {
        let preference = FeatureFlagsPreference()
        preference.setValue(FloconPreferenceValue(booleanValue: false), forKey: "new_onboarding")
        #expect(preference.value(forKey: "new_onboarding") == FloconPreferenceValue(booleanValue: false))
        #expect(preference.type == FloconPreferenceType.custom)
        Flocon.preferencesPlugin.register(preference)
    }

    @Test func configuresTheNetworkOptionsWhenInstalling() {
        // only the builder is exercised: the singleton cannot be started in tests
        var options = FloconNetworkOptions()
        options.shouldLog = { $0.url?.host != "analytics.example.com" }
        options.isImage = { request, _ in request.url?.path.hasPrefix("/images/") == true }

        #expect(options.shouldLog(URLRequest(url: URL(string: "https://example.com")!)))
        #expect(!options.shouldLog(URLRequest(url: URL(string: "https://analytics.example.com")!)))
    }

    @Test func connectsWithoutCrashingBeforeInitialize() async {
        let config = FloconConfig(bufferCapacity: 100, additionalAddress: "192.168.1.20", rememberLastAddress: false)
        #expect(config.bufferCapacity == 100)
        #expect(config.additionalAddress == "192.168.1.20")
        #expect(!config.rememberLastAddress)

        // the SDK is not started
        #expect(await Flocon.connect(address: "192.168.1.20") == .notStarted)
        #expect(Flocon.connectionState == .idle)
        var states = Flocon.connectionStates.makeAsyncIterator()
        #expect(await states.next() == .idle)
    }
}
