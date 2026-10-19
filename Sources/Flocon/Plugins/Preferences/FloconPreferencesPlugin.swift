import Foundation

/// Shows the preference stores of the app in the Flocon desktop app, and applies the edits made there.
///
/// The list of stores is sent on each connection. The desktop then asks for the content
/// of the store being displayed, and sends the edited values.
public final class FloconPreferencesPlugin: FloconPlugin, @unchecked Sendable {
    static let name = "sharedPreferences"
    // app -> desktop, and desktop -> app for the two requests
    private static let methodGetSharedPreferences = "getSharedPreferences"
    private static let methodGetSharedPreferenceValue = "getSharedPreferenceValue"
    // desktop -> app
    private static let methodSetSharedPreferenceValue = "setSharedPreferenceValue"

    public let pluginName = FloconPreferencesPlugin.name
    private weak var sender: FloconMessageSender?

    private let lock = NSLock()
    private var preferences: [String: FloconPreference] = [:]

    init(sender: FloconMessageSender) {
        self.sender = sender
        if let bundleId = Bundle.main.bundleIdentifier {
            add(FloconUserDefaultsPreference(defaults: .standard, name: "UserDefaults.standard", domainName: bundleId))
        }
    }

    /// Adds a store, or replaces the store that has the same name, without notifying the desktop app.
    func add(_ preference: FloconPreference) {
        lock.lock(); preferences[preference.name] = preference; lock.unlock()
    }

    /// Shows a store in the desktop app, or replaces the store that has the same name.
    ///
    /// - Parameter preference: The store.
    public func register(_ preference: FloconPreference) {
        add(preference)
        sendPreferenceList()
    }

    private func preference(named name: String) -> FloconPreference? {
        lock.lock(); defer { lock.unlock() }
        return preferences[name]
    }

    // MARK: FloconPlugin

    public func onConnectedToServer() {
        sendPreferenceList()
    }

    public func onMessageReceived(_ message: FloconMessageFromServer) {
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

        default:
            break
        }
    }

    // MARK: Sending

    private func sendPreferenceList() {
        lock.lock()
        let names = preferences.keys.sorted()
        lock.unlock()
        send(names.map(PreferencesDescriptorRemote.init(name:)), method: Self.methodGetSharedPreferences)
    }

    private func sendContent(of preference: FloconPreference, requestId: String) {
        let rows = preference.keys().map { PreferenceRowRemote(key: $0, value: preference.value(forKey: $0)) }
        let result = SharedPreferenceValueResultRemote(
            requestId: requestId,
            sharedPreferenceName: preference.name,
            rows: rows
        )
        send(result, method: Self.methodGetSharedPreferenceValue)
    }

    private func send<T: Encodable>(_ value: T, method: String) {
        do {
            let data = try JSONEncoder().encode(value)
            guard let json = String(data: data, encoding: .utf8) else { return }
            sender?.send(plugin: pluginName, method: method, body: json)
        } catch {
            FloconLogger.logError("Preferences json mapping error", error)
        }
    }
}
