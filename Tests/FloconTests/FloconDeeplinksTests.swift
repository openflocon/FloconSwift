#if FloconEnabled
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

    @Test func encodesLabelsAndDefaultNextToTheValues() throws {
        let remote = DeeplinksRemote(
            deeplinks: [
                FloconDeeplink(
                    "app://home?tab=[tab]",
                    parameters: [
                        .autoComplete("tab") { suggestions in
                            suggestions.suggest("posts")
                            suggestions.suggest("friends", label: "Friends list")
                        },
                    ]
                ),
            ],
            variables: [
                FloconDeeplinkVariable("env") { suggestions in
                    suggestions.suggest("prod", label: "Production")
                    suggestions.suggestDefault("staging", label: "Staging")
                },
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = try #require(String(data: encoder.encode(remote), encoding: .utf8))

        let expected = #"""
        {"deeplinks":[{"link":"app://home?tab=[tab]","parameters":[{"autoComplete":["posts","friends"],\#
        "name":"tab","suggestions":[{"value":"posts"},{"label":"Friends list","value":"friends"}],\#
        "type":"auto_complete"}]}],\#
        "variables":[{"mode":{"items":[{"label":"Production","value":"prod"},\#
        {"isDefault":true,"label":"Staging","value":"staging"}],"suggestions":["prod","staging"],\#
        "type":"auto_complete"},"name":"env"}]}
        """#
        #expect(json == expected)
    }

    @Test func keepsOnlyTheFirstDefaultAndTheLastDeclarationOfAValue() {
        var suggestions = FloconDeeplinkSuggestions()
        suggestions.suggestDefault("a", label: "A")
        suggestions.suggestDefault("b", label: "B")
        suggestions.suggest("a", label: "A bis")

        let result = suggestions.suggestions

        #expect(result.map(\.value) == ["b", "a"])
        #expect(result.map(\.isDefault) == [true, false])
        #expect(result.last?.label == "A bis")
    }
}
#endif
