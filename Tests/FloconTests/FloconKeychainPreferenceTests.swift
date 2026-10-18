import Foundation
import Security
import Testing
@testable import Flocon

// The keychain itself needs an app with a keychain entitlement: these tests cover the formatting.
@Suite struct FloconKeychainPreferenceTests {
    @Test func keyJoinsServiceAndAccount() {
        let attributes: [String: Any] = [
            kSecAttrService as String: "com.example.api",
            kSecAttrAccount as String: "user@example.com",
        ]
        #expect(FloconKeychainPreference.key(of: attributes, groupingAttribute: kSecAttrService) == "com.example.api / user@example.com")
    }

    @Test func keyUsesTheAvailableAttributes() {
        let serverOnly: [String: Any] = [kSecAttrServer as String: "api.example.com", kSecAttrAccount as String: ""]
        #expect(FloconKeychainPreference.key(of: serverOnly, groupingAttribute: kSecAttrServer) == "api.example.com")
        #expect(FloconKeychainPreference.key(of: [:], groupingAttribute: kSecAttrService) == "<no service or account>")
    }

    @Test func valueIsTextWhenUTF8() {
        #expect(FloconKeychainPreference.displayString(of: Data("secret".utf8)) == "secret")
        #expect(FloconKeychainPreference.displayString(of: Data([0xFF, 0xFE, 0x00])) == "<3 bytes>")
    }
}
