# Flocon for iOS

Swift SDK for [Flocon](https://github.com/openflocon/Flocon), the desktop debugging tool for mobile apps.

Once the SDK is started, your app connects to the Flocon desktop app on your Mac and shows, live:

- **Network**: every HTTP call made through `URLSession` (headers, bodies, timing, redirects, images), and the WebSocket events you log; mocks and bad network simulation set from the desktop
- **Analytics**: the events sent to your analytics providers, one table per provider
- **Feature flags**: the flags evaluated by your app, with their provider, variant and payload
- **Tables**: any structured data you want to inspect while the app runs
- **Preferences**: the content of your `UserDefaults` stores and, if you opt in, your keychain passwords, editable from the desktop
- **Files**: browse, download and delete the files of the app, and of the folders you register (App Groups…)
- **Databases**: query the SQLite databases of the app (Core Data, GRDB, SQLite…), and see the queries it runs
- **Dashboards**: values of your app updated live, and buttons, inputs and forms that run actions in it
- **Deeplinks**: the deeplinks of your app, with their parameters
- **Crashes**: the crashes of your app, reported on the next launch
- **App icon**: your app appears with its icon in the desktop app

## Requirements

- iOS 15+ or macOS 12+
- Swift 6.4+ / Xcode 26+
- The [Flocon desktop app](https://github.com/openflocon/Flocon) running on your Mac

## Installation

Flocon is distributed with Swift Package Manager. There is no tagged release yet, so depend on the `main` branch.

### Xcode

1. Choose **File › Add Package Dependencies…**
2. Paste `https://github.com/openflocon/FloconSwift.git` in the search field.
3. Set **Dependency Rule** to **Branch** › `main`, then click **Add Package**.
4. Add the `Flocon` library to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/openflocon/FloconSwift.git", branch: "main"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "Flocon", package: "FloconSwift"),
        ]
    ),
]
```

## Getting started

Start the SDK as early as possible, for example in the initializer of your `App`:

```swift
import Flocon

@main
struct MyApp: App {
    init() {
        startFlocon { flocon in
            flocon.install(.network)
            flocon.install(.analytics)
            flocon.install(.database) { $0.register(displayName: "App", url: databaseURL) }
        }
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

Only the installed plugins are started: the others, such as `Flocon.analyticsPlugin`, do nothing: their calls can stay in the app. The available plugins are `.network` (also intercepts `URLSession.shared`), `.analytics`, `.featureFlags`, `.tables`, `.preferences`, `.files`, `.database`, `.dashboard`, `.deeplinks` and `.crashReporter`. Those with options take a closure, for example `flocon.install(.preferences) { $0.userDefaults(suite, suiteName: "group") }`.

`Flocon.initialize()` is the short form that installs every plugin.

`startFlocon` and `Flocon.initialize()` can be called from any thread. The SDK connects in the background and keeps retrying until the desktop app is reachable; messages sent in the meantime are kept in memory (see [Connecting to another address](#connecting-to-another-address)).

The SDK works off the main thread: messages are encoded and sent in the background, and the logging calls (analytics, tables, database queries…) only queue their values.

### Console logs

The SDK prints nothing in the Xcode console by default. To see what it does, for example when the app does not show up in the desktop app, turn its logs on before starting it:

```swift
Flocon.isLoggingEnabled = true
startFlocon { flocon in /* ... */ }
```

The logs are prefixed with `[Flocon]`: connection, messages sent and received, errors. Long payloads, such as network bodies, are cut to 500 characters in the console; the desktop app still receives them in full.

### On a physical device

The default host, `localhost`, works from the iOS Simulator. On a device, use the local IP address of your Mac:

```swift
Flocon.initialize(config: FloconConfig(host: "192.168.1.20"))
```

Your app also needs to be allowed to reach the local network: add `NSLocalNetworkUsageDescription` to its `Info.plist`. The connection uses `wss://` with the self-signed certificate of the desktop app, which is accepted without being verified (the connection is encrypted, not authenticated), so no App Transport Security exception is needed.

### Connecting to another address

By default the SDK tries `localhost` (the simulator) and keeps retrying every 3 seconds. If the address of the Mac is not known when the app starts, for example because the user types it in, call `Flocon.connect(address:)` when you have it, from a debug menu for instance. The SDK keeps trying `localhost` and also connects to this address:

```swift
startFlocon { flocon in
    flocon.install(.network)
    flocon.install(.analytics)
}

// later, once the address is known
let result = await Flocon.connect(address: "192.168.1.20")
```

Until a desktop is reachable, everything the app logs is kept in memory. `Flocon.connect(address:)` opens the connection, introduces the app to the desktop, then sends what was kept, in the order it was logged, before sending the next messages right away. It returns a `FloconConnectResult` (`.connected`, `.notStarted`, `.invalidAddress`, `.failed`) instead of throwing; the messages are kept in every case, so you can call it again. Calling it with a new address replaces the previous one. Give only the IP address (or host) of the Mac, without scheme nor port: the port is always `9023`, anything else is `.invalidAddress`.

The options are set with `connect` in the `startFlocon` block:

```swift
startFlocon { flocon in
    flocon.connect { setup in
        setup.bufferCapacity = 10_000       // messages kept while no desktop is reachable
        setup.address = "192.168.1.20"      // also tried at start, for a Mac with a fixed IP
        setup.rememberLastAddress = true    // the last connected address is tried again at the next launch
    }
    flocon.install(.network)
}
```

Up to 5000 messages are kept (`bufferCapacity`): above that, the oldest are dropped. The same buffer is used when a connection to the desktop is lost: the messages are kept, the SDK reconnects every 3 seconds, and sends them once it is back.

The last address the SDK connected to is kept in the `UserDefaults` of the app (`rememberLastAddress`, `true` by default) and tried again at the next launch, next to `localhost`. It wins over `address`. `FloconConfig` has the same options (`bufferCapacity`, `additionalAddress`, `rememberLastAddress`) for `Flocon.initialize(config:)`.

Follow the connection with `Flocon.connectionState`, or with the `Flocon.connectionStates` stream, which starts with the current state (`.connected` as soon as one address is connected):

```swift
for await state in Flocon.connectionStates {
    switch state {
    case .idle: break               // the SDK is not started
    case .buffering: break          // not connected, the messages are kept
    case .connecting: break
    case .connected: break          // the messages are sent right away
    case .failed(let reason): print(reason) // the messages are still kept
    }
}
```

## Network

Create your sessions with a configuration intercepted by Flocon:

```swift
let session = URLSession(configuration: .default.withFlocon())
```

The same works for the libraries built on `URLSession`:

```swift
// Alamofire
let session = Session(configuration: URLSessionConfiguration.default.withFlocon())

// Kingfisher
KingfisherManager.shared.downloader.sessionConfiguration = .default.withFlocon()
```

To intercept `URLSession.shared` too:

```swift
Flocon.interceptSharedSession()
```

### Options

Choose which requests are sent, and which responses are images (their body is not sent, the desktop app downloads them from their URL):

```swift
startFlocon { flocon in
    flocon.install(.network) { options in
        options.shouldLog = { request in request.url?.host != "analytics.example.com" }
        options.isImage = { request, _ in request.url?.path.hasPrefix("/images/") == true }
    }
}
```

Responses with a `Content-Type: image/*` header are always treated as images.

### Mocks and bad network

The mocks and the bad network simulation set in the desktop app apply to the intercepted calls, with nothing to add to your code:

- a request matched by a mock (regular expression on the full URL, and method) receives its response, or its error, without reaching the server; it is shown as mocked in the desktop app
- the bad network simulation adds latency to the calls, and makes some of them fail with one of its errors

The errors set in the desktop app, such as `java.net.UnknownHostException`, are turned into the closest `URLError` (`.cannotFindHost`, `.timedOut`, `.cannotConnectToHost`, `.secureConnectionFailed`, otherwise `.networkConnectionLost`).

Both are saved on the device, and apply from the next launch too, before the app connects to the desktop. Requests excluded by `shouldLog` are neither logged nor mocked.

### WebSockets

WebSocket traffic cannot be intercepted automatically. Log the events of the connections you want to inspect:

```swift
let task = URLSession.shared.webSocketTask(with: url)
task.resume()
Flocon.networkPlugin.logWebSocketEvent(FloconWebSocketEvent(websocketUrl: url.absoluteString, event: .open))

try await task.send(.string(text))
Flocon.networkPlugin.logWebSocketEvent(
    FloconWebSocketEvent(websocketUrl: url.absoluteString, event: .sendMessage, message: text)
)
```

## Analytics

Log your events on one stream per analytics provider:

```swift
Flocon.analyticsPlugin.sender("firebase").logEvents(
    AnalyticsEvent(
        eventName: "button_clicked",
        AnalyticsProperty("button_id", "checkout_pay")
    )
)
```

## Feature flags

Register the flags your app evaluated, one provider per feature flag system (Firebase Remote Config, Statsig, an in-house one…). No dependency on their SDKs: each call replaces the flags of the provider, and they are sent again when the app reconnects to the desktop:

```swift
Flocon.featureFlagsPlugin.sender("firebase").register(
    FloconFeatureFlag(name: "new_checkout", state: .custom, variant: "treatment", payload: #"{"steps": 3}"#),
    FloconFeatureFlag(name: "dark_mode", state: .on, variant: "on"),
    FloconFeatureFlag(name: "onboarding_v2", state: .off, variant: "control")
)
```

`state` (`.on`, `.off` or `.custom` for an experiment arm or a value) colors the variant in the desktop. The desktop lists them with a search, and shows the payload (formatted when it is json) when you click a flag.

## Tables

Log rows in a table; its columns are created from the names you use:

```swift
Flocon.tablePlugin.table("users").log(
    TableColumnConfig("name", "Florent"),
    TableColumnConfig("age", "33")
)
```

## Preferences

`UserDefaults.standard` is shown automatically. Register your other stores, such as the ones shared with an App Group:

```swift
let shared = UserDefaults(suiteName: "group.com.example.app")!
Flocon.preferencesPlugin.registerUserDefaults(shared, suiteName: "group.com.example.app")
```

Values of type `String`, `Bool`, number, `Date` and `[String]` can be edited from the desktop; an edit is applied only when its type matches the stored value. `Data`, dictionaries and mixed arrays are shown read-only.

### Keychain

The keychain is not shown by default. Opt in, in debug builds only: its values are sent unencrypted to the Mac running Flocon.

```swift
#if DEBUG
Flocon.preferencesPlugin.registerKeychain()                    // read-only
// Flocon.preferencesPlugin.registerKeychain(isEditable: true) // also apply the edits made in the desktop
#endif
```

Generic and internet passwords appear as two stores, with one key per item (`service / account`, `server / account`). Values are shown as text when they are UTF-8, as their size otherwise. Items protected by Face ID, Touch ID or the passcode, or unreadable while the device is locked, are shown as `<protected>`: reading them never shows an authentication prompt. The Simulator does not enforce these protections, so it shows their values.

With `isEditable: true`, only existing items with a text value can be edited; items are never added or deleted.

## Files

The Files section of the desktop app shows `Documents`, `Application Support`, `Caches`, `tmp` and the whole app container without any setup. Register other folders, such as the container of an App Group shared with your widgets and extensions:

```swift
Flocon.filesPlugin.registerAppGroup("group.com.example.app")
Flocon.filesPlugin.register(displayName: "Exports", url: exportsURL)
```

Files are downloaded over the desktop HTTP server (`FloconConfig.httpPort`, `9024` by default). On a physical device, this needs the same App Transport Security exception as the WebSocket connection. Paths outside these folders are refused, and the folders themselves can never be deleted.

## Databases

The SQLite files of `Documents` and `Library/Application Support` are shown without any setup: Core Data stores, GRDB and SQLite.swift databases are found whatever their extension. Run any SQL query on them from the desktop app.

Register the databases stored elsewhere, such as in an App Group, or give a database a clearer name:

```swift
let url = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.app")!
    .appendingPathComponent("shared.sqlite")
Flocon.databasePlugin.register(displayName: "Shared", url: url)
```

Only the listed databases can be queried, and a file that does not exist is not listed. Queries from the desktop run on their own connection: a write waits up to one second for the app to release its lock. Blobs are shown as hexadecimal, truncated after 64 bytes.

To see the queries run by the app, log them from the trace hook of your database library, for example with GRDB:

```swift
var configuration = Configuration()
configuration.prepareDatabase { db in
    db.trace { event in
        Flocon.databasePlugin.logQuery(dbName: "app", sqlQuery: "\(event)")
    }
}
```

## Dashboards

A dashboard shows values of the app, and runs actions in it from the desktop app. A section is either static, or rebuilt each time a Combine publisher emits, such as a `@Published` property:

```swift
final class DebugDashboard {
    // keep the handle: the dashboard stops following the publishers when it is released
    private var handle: FloconDashboardHandle?

    func start(session: Session) {
        handle = Flocon.dashboardPlugin.dashboard(id: "main") {
            FloconSection("User", publisher: session.$user) { user in
                FloconText("name", user.name)
                FloconText("status", user.status, color: 0xFFFF0000) // ARGB
                FloconButton("Log out", id: "logout") { session.logOut() }
                FloconTextField(id: "rename", label: "Rename", value: user.name) { session.rename($0) }
                FloconCheckBox(id: "premium", label: "Premium", value: user.isPremium) { session.setPremium($0) }
            }
            FloconSection("Build") {
                FloconPlainText("commit", buildCommit)
                FloconJSON("config", configJSON)
                FloconMarkdown("Release note", "# 1.0\nFirst **release**")
                FloconHTML("About", "<h1>MyApp</h1>")
            }
            FloconForm("Create user", submitText: "Create", onSubmitted: { values in
                session.createUser(name: values["name"] ?? "", isAdmin: values["admin"] == "true")
            }) {
                FloconTextField(id: "name", label: "Name", value: "")
                FloconCheckBox(id: "admin", label: "Admin", value: false)
            }
        }
    }
}
```

The actions are called on the main actor. Element identifiers must be unique in their dashboard. A form sends the values of its inputs together, keyed by their identifiers, with check boxes as `"true"` or `"false"`. The dashboard is sent once every reactive section has a value, and again on each connection.

## Deeplinks

List the deeplinks of your app, writing the parts to fill in between brackets:

```swift
floconRegisterDeeplinks(
    [
        FloconDeeplink("myapp://home", label: "Home"),
        FloconDeeplink(
            "myapp://user/[userId]",
            label: "User",
            description: "Open the profile of a user",
            parameters: [.autoComplete("userId", ["Florent", "David"])]
        ),
        FloconDeeplink("myapp://[env]/settings", parameters: [.variable("env", variableName: "env")]),
    ],
    variables: [FloconDeeplinkVariable("env", suggestions: ["staging", "production"])]
)
```

A variable is shared by several deeplinks, and edited once in the desktop app.

Opening a deeplink from the desktop app on the iOS Simulator needs a desktop version that includes [openflocon/Flocon#580](https://github.com/openflocon/Flocon/pull/580); older versions only open them with `adb`. You can always open one from the terminal:

```bash
xcrun simctl openurl booted "myapp://user/Florent"
```

## Crashes

Crashes are reported by default. A crash cannot be sent while the app crashes: it is saved, and sent the next time the app connects to the desktop.

- Objective-C exceptions (`NSException`) are reported with their name, reason and call stack.
- Swift runtime errors (force unwrap of `nil`, `fatalError`, index out of range…) and other crash signals (`SIGTRAP`, `SIGABRT`, `SIGSEGV`…) are reported with the signal and the call stack. The Swift error message is only printed in the console.

The handlers already installed, by another crash reporter for example, are kept and still called. Crashes are not caught while the Xcode debugger is attached, as it catches them first: launch the app from the simulator or the device to try it. To install no handler at all:

```swift
Flocon.initialize(config: FloconConfig(isCrashReporterEnabled: false))
```

## Extending Flocon

Each feature is a plugin of `Flocon`: `Flocon.networkPlugin`, `analyticsPlugin`, `featureFlagsPlugin`, `tablePlugin`, `preferencesPlugin`, `databasePlugin`, `filesPlugin`, `dashboardPlugin` and `deeplinksPlugin`. They are never `nil`: until `Flocon.initialize()`, or if the plugin is not installed, they do nothing. (`Flocon.shared.networkPlugin` and the like are optionals, `nil` in that case.)

### Logging other network calls

`URLSession` calls are logged by the SDK. Log the calls of another client, such as a socket or a gRPC client, with the network plugin ([FloconSwiftGrpc](https://github.com/openflocon/FloconSwiftGrpc) does it for grpc-swift):

```swift
let call = FloconNetworkCallRequest(
    networkType: "http",
    request: FloconNetworkRequest(url: "https://api.example.com/users", method: "GET")
)
Flocon.networkPlugin.logRequest(call)

// once the response is received
Flocon.networkPlugin.logResponse(
    FloconNetworkCallResponse(
        callId: call.callId,
        networkType: "http",
        durationMs: 120,
        response: FloconNetworkResponse(httpCode: 200, body: #"{"users": []}"#)
    )
)
```

### Showing a store of your own

Implement `FloconPreference` to show and edit any key-value store in the Preferences section, then register it:

```swift
final class DebugSettingsPreference: FloconPreference {
    let name = "Debug settings"
    func keys() -> [String] { DebugSettings.all.map(\.key) }
    func value(forKey key: String) -> FloconPreferenceValue? {
        FloconPreferenceValue(booleanValue: DebugSettings.isEnabled(key))
    }
    func setValue(_ value: FloconPreferenceValue, forKey key: String) {
        if let isEnabled = value.booleanValue { DebugSettings.set(key, isEnabled) }
    }
}

Flocon.preferencesPlugin.register(DebugSettingsPreference())
```

## Sample app

Open `FloconWorkspace.xcworkspace` and run the `FloconDemo` scheme. The sample has a home listing the plugins and one screen per plugin, in the colors of the Flocon desktop app: Network (HTTP calls, errors, a WebSocket echo, GraphQL), Database, Analytics, Feature flags, Preferences (`UserDefaults` and keychain items that update live when you edit them in the desktop app), Files, Dashboard & Tables, Deeplinks (handled by the `flocondemo://` URL scheme), Images (a list loaded with Kingfisher) and Crash reporter. Each row shows the duration or the error of its last run.

## Documentation

The public API is documented with DocC comments. In Xcode, choose **Product › Build Documentation** with the `Flocon` scheme to browse it.
