import Foundation

// MARK: - From device

/// JSON format of a store in the list sent to the desktop app.
struct PreferencesDescriptorRemote: Encodable {
    let name: String
}

/// JSON format of the content of a store, sent in answer to a desktop request.
struct SharedPreferenceValueResultRemote: Encodable {
    let requestId: String
    let sharedPreferenceName: String
    let rows: [PreferenceRowRemote]
}

/// JSON format of one key of a store. Only the property matching the type of the value is set.
struct PreferenceRowRemote: Encodable {
    let key: String
    let stringValue: String?
    let intValue: Int32?
    let floatValue: Float?
    let booleanValue: Bool?
    let longValue: Int64?
    let setStringValue: [String]?

    init(key: String, value: FloconPreferenceValue?) {
        self.key = key
        stringValue = value?.stringValue
        intValue = value?.intValue
        floatValue = value?.floatValue
        booleanValue = value?.booleanValue
        longValue = value?.longValue
        setStringValue = value?.setStringValue
    }
}

// MARK: - To device

/// Desktop request for the content of a store.
struct ToDeviceGetSharedPreferenceValueMessage: Decodable {
    let requestId: String
    let sharedPreferenceName: String
}

/// Desktop request to edit the value of a key. Only the property matching its type is set.
struct ToDeviceEditSharedPreferenceValueMessage: Decodable {
    let requestId: String
    let sharedPreferenceName: String
    let key: String
    let stringValue: String?
    let intValue: Int32?
    let floatValue: Float?
    let booleanValue: Bool?
    let longValue: Int64?
    let setStringValue: [String]?

    var value: FloconPreferenceValue {
        FloconPreferenceValue(
            stringValue: stringValue,
            intValue: intValue,
            longValue: longValue,
            floatValue: floatValue,
            booleanValue: booleanValue,
            setStringValue: setStringValue
        )
    }
}
