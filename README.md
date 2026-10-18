# Flocon for iOS

Swift SDK for [Flocon](https://github.com/openflocon/Flocon), the desktop debugging tool for mobile apps.

Once the SDK is started, your app connects to the Flocon desktop app on your Mac and shows, live:

- **Network**: every HTTP call made through `URLSession` (headers, bodies, timing, redirects, images), and the WebSocket events you log
- **Analytics**: the events sent to your analytics providers, one table per provider
- **Tables**: any structured data you want to inspect while the app runs
- **Preferences**: the content of your `UserDefaults` stores and, if you opt in, your keychain passwords, editable from the desktop
- **Files**: browse, download and delete the files of the app container
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
        Flocon.initialize()
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

`Flocon.initialize()` can be called from any thread. The SDK connects in the background and keeps retrying until the desktop app is reachable; messages sent in the meantime are queued.

### On a physical device

The default host, `localhost`, works from the iOS Simulator. On a device, use the local IP address of your Mac:

```swift
Flocon.initialize(config: FloconConfig(host: "192.168.1.20"))
```

Your app also needs to be allowed to reach the local network: add `NSLocalNetworkUsageDescription` to its `Info.plist`, and an App Transport Security exception for the Mac, as the connection uses plain `ws://`.

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
Flocon.setNetworkOptions(
    FloconNetworkOptions(
        shouldLog: { request in request.url?.host != "analytics.example.com" },
        isImage: { request, _ in request.url?.path.hasPrefix("/images/") == true }
    )
)
```

Responses with a `Content-Type: image/*` header are always treated as images.

### WebSockets

WebSocket traffic cannot be intercepted automatically. Log the events of the connections you want to inspect:

```swift
let task = URLSession.shared.webSocketTask(with: url)
task.resume()
floconLogWebSocketEvent(FloconWebSocketEvent(websocketUrl: url.absoluteString, event: .open))

try await task.send(.string(text))
floconLogWebSocketEvent(
    FloconWebSocketEvent(websocketUrl: url.absoluteString, event: .sendMessage, message: text)
)
```

## Analytics

Log your events on one stream per analytics provider:

```swift
floconAnalytics("firebase").logEvents(
    AnalyticsEvent(
        eventName: "button_clicked",
        AnalyticsProperty("button_id", "checkout_pay")
    )
)
```

## Tables

Log rows in a table; its columns are created from the names you use:

```swift
floconTable("users").log(
    TableColumnConfig("name", "Florent"),
    TableColumnConfig("age", "33")
)
```

## Preferences

`UserDefaults.standard` is shown automatically. Register your other stores, such as the ones shared with an App Group:

```swift
let shared = UserDefaults(suiteName: "group.com.example.app")!
floconRegisterUserDefaults(shared, suiteName: "group.com.example.app")
```

Values of type `String`, `Bool`, number, `Date` and `[String]` can be edited from the desktop; an edit is applied only when its type matches the stored value. `Data`, dictionaries and mixed arrays are shown read-only.

### Keychain

The keychain is not shown by default. Opt in, in debug builds only: its values are sent unencrypted to the Mac running Flocon.

```swift
#if DEBUG
floconRegisterKeychain()                    // read-only
// floconRegisterKeychain(isEditable: true) // also apply the edits made in the desktop
#endif
```

Generic and internet passwords appear as two stores, with one key per item (`service / account`, `server / account`). Values are shown as text when they are UTF-8, as their size otherwise. Items protected by Face ID, Touch ID or the passcode, or unreadable while the device is locked, are shown as `<protected>`: reading them never shows an authentication prompt. The Simulator does not enforce these protections, so it shows their values.

With `isEditable: true`, only existing items with a text value can be edited; items are never added or deleted.

## Files

Nothing to set up: the Files section of the desktop app opens the root of the app container (with its `Documents`, `Library` and `tmp` folders), or its `Library/Caches` folder.

Files are downloaded over the desktop HTTP server (`FloconConfig.httpPort`, `9024` by default). On a physical device, this needs the same App Transport Security exception as the WebSocket connection. Paths outside the app container are refused, and the root folders themselves can never be deleted.

## Sample app

Open `FloconWorkspace.xcworkspace` and run the `FloconDemo` scheme. The sample triggers HTTP calls, loads an image list with Kingfisher, runs a WebSocket echo, logs analytics events and table rows, shows `UserDefaults` values and keychain items that update live when you edit them in the desktop app, and writes sample files to browse.

## Documentation

The public API is documented with DocC comments. In Xcode, choose **Product › Build Documentation** with the `Flocon` scheme to browse it.
