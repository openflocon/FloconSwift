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

    @Test func registersFoldersBeforeInitialize() {
        // does nothing before initialize, but must compile and not crash
        floconRegisterFolder(displayName: "Exports", url: FileManager.default.temporaryDirectory)
        floconRegisterFolder(displayName: "Exports", absolutePath: NSTemporaryDirectory())
        floconRegisterAppGroup("group.io.github.openflocon.tests")
        Flocon.registerFolder(FloconFolder(displayName: "Exports", url: FileManager.default.temporaryDirectory))
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
        Flocon.shared.networkPlugin?.logRequest(request)
        Flocon.shared.networkPlugin?.logResponse(response)
    }

    @Test func implementsACustomPreference() {
        let preference = FeatureFlagsPreference()
        preference.setValue(FloconPreferenceValue(booleanValue: false), forKey: "new_onboarding")
        #expect(preference.value(forKey: "new_onboarding") == FloconPreferenceValue(booleanValue: false))
        floconRegisterPreference(preference)
    }
}
