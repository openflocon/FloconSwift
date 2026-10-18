import Foundation
import Testing
@testable import Flocon

@Suite struct FloconDeeplinksTests {
    @Test func encodesLikeTheOtherSDKs() throws {
        let remote = DeeplinksRemote(
            deeplinks: [
                FloconDeeplink("[host]://home", parameters: [.variable("host", variableName: "host")]),
                FloconDeeplink(
                    "[host]://user/[userId]",
                    label: "User",
                    description: "Open a user",
                    parameters: [.autoComplete("userId", ["Florent", "David"])]
                ),
            ],
            variables: [
                FloconDeeplinkVariable("test_variable"),
                FloconDeeplinkVariable("host", description: "Host variable", suggestions: ["flocon", "flocon2"]),
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = try #require(String(data: encoder.encode(remote), encoding: .utf8))

        let expected = #"""
        {"deeplinks":[\#
        {"link":"[host]://home","parameters":[{"name":"host","type":"variable","variableName":"host"}]},\#
        {"description":"Open a user","label":"User","link":"[host]://user/[userId]",\#
        "parameters":[{"autoComplete":["Florent","David"],"name":"userId","type":"auto_complete"}]}],\#
        "variables":[{"name":"test_variable"},\#
        {"description":"Host variable","mode":{"suggestions":["flocon","flocon2"],"type":"auto_complete"},"name":"host"}]}
        """#
        #expect(json == expected)
    }
}
