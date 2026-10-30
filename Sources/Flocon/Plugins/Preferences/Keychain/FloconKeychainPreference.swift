import Foundation
import LocalAuthentication
import Security

/// Exposes the password items of the app keychain to the Flocon desktop app.
///
/// Items are read in two steps: their attributes first, which never needs authentication,
/// then each value with a context that forbids any user interaction. An item protected by
/// Face ID, Touch ID or the passcode never shows a prompt: it is shown as protected instead.
final class FloconKeychainPreference: FloconPreference, @unchecked Sendable {
    /// Kind of keychain item shown by a preference.
    enum ItemClass: Sendable {
        case genericPassword
        case internetPassword

        var secClass: CFString {
            switch self {
            case .genericPassword: kSecClassGenericPassword
            case .internetPassword: kSecClassInternetPassword
            }
        }

        var displayName: String {
            switch self {
            case .genericPassword: "Keychain · Generic passwords"
            case .internetPassword: "Keychain · Internet passwords"
            }
        }

        /// Attribute shown before the account in the key of an item.
        var groupingAttribute: CFString {
            switch self {
            case .genericPassword: kSecAttrService
            case .internetPassword: kSecAttrServer
            }
        }
    }

    /// Value shown for an item that needs authentication, or an unlocked device, to be read.
    static let protectedValue = "<protected>"

    let name: String
    let type = FloconPreferenceType.keychain
    private let itemClass: ItemClass
    private let isEditable: Bool

    private let lock = NSLock()
    /// Attributes of the items found by the last ``keys()`` call, by key.
    private var itemsByKey: [String: [String: Any]] = [:]

    /// Attributes that identify an item, used to read or update exactly that item.
    private static let primaryKeyAttributes: [String] = [
        kSecAttrAccount, kSecAttrService, kSecAttrServer, kSecAttrAccessGroup, kSecAttrProtocol,
        kSecAttrPort, kSecAttrPath, kSecAttrSecurityDomain, kSecAttrAuthenticationType,
    ].map { $0 as String }

    /// Creates a preference for one kind of keychain item.
    ///
    /// - Parameters:
    ///   - itemClass: The kind of items to show.
    ///   - isEditable: Whether the values edited in the desktop app are written to the keychain.
    init(itemClass: ItemClass, isEditable: Bool) {
        self.itemClass = itemClass
        self.isEditable = isEditable
        self.name = itemClass.displayName
    }

    // MARK: FloconPreference

    func keys() -> [String] {
        var mapping: [String: [String: Any]] = [:]
        for attributes in listItems() {
            let baseKey = Self.key(of: attributes, groupingAttribute: itemClass.groupingAttribute)
            var key = baseKey
            if mapping[key] != nil, let group = attributes[kSecAttrAccessGroup as String] as? String {
                key = "\(baseKey) [\(group)]"
            }
            var index = 2
            while mapping[key] != nil {
                key = "\(baseKey) #\(index)"
                index += 1
            }
            mapping[key] = attributes
        }
        lock.lock(); itemsByKey = mapping; lock.unlock()
        return mapping.keys.sorted()
    }

    func value(forKey key: String) -> FloconPreferenceValue? {
        guard let attributes = attributes(forKey: key) else { return nil }
        switch readData(of: attributes) {
        case .success(let data):
            return FloconPreferenceValue(stringValue: Self.displayString(of: data))
        case .failure(let status) where status == errSecInteractionNotAllowed || status == errSecAuthFailed:
            return FloconPreferenceValue(stringValue: Self.protectedValue)
        case .failure(let status):
            return FloconPreferenceValue(stringValue: "<unreadable: OSStatus \(status.rawValue)>")
        }
    }

    func setValue(_ value: FloconPreferenceValue, forKey key: String) {
        guard isEditable else {
            FloconLogger.log("Ignored edit of \(name).\(key): the keychain is registered as read-only")
            return
        }
        guard let attributes = attributes(forKey: key),
              let newValue = value.stringValue,
              case .success(let current) = readData(of: attributes),
              String(data: current, encoding: .utf8) != nil else {
            FloconLogger.log("Ignored edit of \(name).\(key): only readable text values can be edited")
            return
        }
        let update: [String: Any] = [kSecValueData as String: Data(newValue.utf8)]
        let status = SecItemUpdate(itemQuery(for: attributes) as CFDictionary, update as CFDictionary)
        if status != errSecSuccess {
            FloconLogger.log("Keychain update of \(name).\(key) failed: OSStatus \(status)")
        }
    }

    // MARK: Keychain access

    private struct KeychainStatus: Error {
        let rawValue: OSStatus
        static func == (lhs: KeychainStatus, rhs: OSStatus) -> Bool { lhs.rawValue == rhs }
    }

    private func attributes(forKey key: String) -> [String: Any]? {
        lock.lock(); defer { lock.unlock() }
        return itemsByKey[key]
    }

    /// Returns the attributes of every item of the class, including the ones synced with iCloud.
    private func listItems() -> [[String: Any]] {
        var query = baseQuery()
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnAttributes as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? [[String: Any]] ?? []
        case errSecItemNotFound:
            return []
        default:
            FloconLogger.log("Keychain listing of \(name) failed: OSStatus \(status)")
            return []
        }
    }

    /// Reads the value of an item, without ever asking the user to authenticate.
    private func readData(of attributes: [String: Any]) -> Result<Data, KeychainStatus> {
        var query = itemQuery(for: attributes)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return .failure(KeychainStatus(rawValue: status)) }
        return .success(result as? Data ?? Data())
    }

    /// Query matching exactly one item, from its attributes.
    private func itemQuery(for attributes: [String: Any]) -> [String: Any] {
        var query = baseQuery()
        for attribute in Self.primaryKeyAttributes {
            if let value = attributes[attribute] {
                query[attribute] = value
            }
        }
        query[kSecAttrSynchronizable as String] = attributes[kSecAttrSynchronizable as String] ?? kSecAttrSynchronizableAny
        // never show a Face ID, Touch ID or passcode prompt: protected items fail instead
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        return query
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [kSecClass as String: itemClass.secClass]
        #if os(macOS)
        // the iOS-style keychain, scoped to the app, rather than the user's login keychain
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    // MARK: Formatting

    /// Key of an item in the desktop app: `service / account`, or `server / account`.
    static func key(of attributes: [String: Any], groupingAttribute: CFString) -> String {
        let group = attributes[groupingAttribute as String] as? String
        let account = attributes[kSecAttrAccount as String] as? String
        return [group, account]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " / ")
            .nonEmpty ?? "<no service or account>"
    }

    /// The value as text when it is UTF-8, its size otherwise.
    static func displayString(of data: Data) -> String {
        String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
