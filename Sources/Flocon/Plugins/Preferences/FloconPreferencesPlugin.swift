import Foundation

/// Shows the preference stores of the app in the Flocon desktop app, and applies the edits made there.
///
/// The list of stores is sent on each connection. The desktop then asks for the content
/// of the store being displayed, and sends the edited values and the deleted keys.
public final class FloconPreferencesPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "shared_preferences"
    // app -> desktop, and desktop -> app for the two requests
    private static let methodGetSharedPreferences = "get_shared_preferences"
    private static let methodGetSharedPreferenceValue = "get_shared_preference_value"
    // desktop -> app
    private static let methodSetSharedPreferenceValue = "set_shared_preference_value"
    private static let methodRemoveSharedPreferenceValue = "remove_shared_preference_value"

    public let pluginName = FloconPreferencesPlugin.name
    private weak var sender: FloconMessageSender?

#if FloconEnabled
    private let lock = NSLock()
    private var preferences: [String: FloconPreference] = [:]
#endif

    #if FloconEnabled
    init(sender: FloconMessageSender) {
        self.sender = sender
        if let bundleId = Bundle.main.bundleIdentifier {
            add(FloconUserDefaultsPreference(defaults: .standard, name: "UserDefaults.standard", domainName: bundleId))
        }
    }
    #else
    init(sender: FloconMessageSender) {
        self.sender = sender
    }
    #endif

    /// Adds a store, or replaces the store that has the same name, without notifying the desktop app.
    func add(_ preference: FloconPreference) {
        #if FloconEnabled
        lock.lock(); preferences[preference.name] = preference; lock.unlock()
        #endif
    }

    /// Shows a store in the desktop app, or replaces the store that has the same name.
    ///
    /// - Parameter preference: The store.
    public func register(_ preference: FloconPreference) {
        #if FloconEnabled
        add(preference)
        sendPreferenceList()
        #endif
    }

#if FloconEnabled
    private func preference(named name: String) -> FloconPreference? {
        lock.lock(); defer { lock.unlock() }
        return preferences[name]
    }
#endif

    // MARK: FloconPlugin

    public func onConnectedToServer() {
        #if FloconEnabled
        sendPreferenceList()
        #endif
    }

    public func onMessageReceived(_ message: FloconMessageFromServer) {
        #if FloconEnabled
        let body = Data(message.body.utf8)
        switch message.method {
        case Self.methodGetSharedPreferences:
            sendPreferenceList()

        case Self.methodGetSharedPreferenceValue:
            guard let request = try? JSONDecoder().decode(ToDeviceGetSharedPreferenceValueMessage.self, from: body),
                  let preference = preference(named: request.sharedPreferenceName) else { return }
            sendContent(of: preference, requestId: request.requestId)

        case Self.methodSetSharedPreferenceValue:
            guard let request = try? JSONDecoder().decode(ToDeviceEditSharedPreferenceValueMessage.self, from: body),
                  let preference = preference(named: request.sharedPreferenceName) else { return }
            preference.setValue(request.value, forKey: request.key)
            // send the content again, so that the desktop shows what was actually stored
            sendContent(of: preference, requestId: request.requestId)

        case Self.methodRemoveSharedPreferenceValue:
            guard let request = try? JSONDecoder().decode(ToDeviceRemovePreferenceValueMessage.self, from: body),
                  let preference = preference(named: request.sharedPreferenceName) else { return }
            preference.removeValue(forKey: request.key)
            sendContent(of: preference, requestId: request.requestId)

        default:
            break
        }
        #endif
    }

    // MARK: Sending

#if FloconEnabled
    private func sendPreferenceList() {
        lock.lock()
        let descriptors = preferences.values
            .sorted { $0.name < $1.name }
            .map { PreferencesDescriptorRemote(name: $0.name, type: $0.type) }
        lock.unlock()
        send(descriptors, method: Self.methodGetSharedPreferences)
    }
#endif

#if FloconEnabled
    private func sendContent(of preference: FloconPreference, requestId: String) {
        let rows = preference.keys().map { PreferenceRowRemote(key: $0, value: preference.value(forKey: $0)) }
        let result = SharedPreferenceValueResultRemote(
            requestId: requestId,
            sharedPreferenceName: preference.name,
            rows: rows
        )
        send(result, method: Self.methodGetSharedPreferenceValue)
    }
#endif

#if FloconEnabled
    private func send<T: Encodable>(_ value: T, method: String) {
        do {
            let data = try JSONEncoder().encode(value)
            guard let json = String(data: data, encoding: .utf8) else { return }
            sender?.send(plugin: pluginName, method: method, body: json)
        } catch {
            FloconLogger.logError("Preferences json mapping error", error)
        }
    }
#endif
}
