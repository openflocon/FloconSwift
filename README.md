# Flocon for iOS

Swift SDK for [Flocon](https://github.com/openflocon/Flocon), the desktop debugging tool for mobile apps.

Once the SDK is started, your app connects to the Flocon desktop app on your Mac and shows, live:

- **Network**: every HTTP call made through `URLSession` (headers, bodies, timing, redirects, images), and the WebSocket events you log
- **Analytics**: the events sent to your analytics providers, one table per provider
- **Tables**: any structured data you want to inspect while the app runs
- **App icon**: your app appears with its icon in the desktop app

## Requirements

- iOS 15+ or macOS 12+
- Swift 6.4+ / Xcode 26+
- The [Flocon desktop app](https://github.com/openflocon/Flocon) running on your Mac

## Installation

The package is in the [`FloconSwift`](FloconSwift) folder of this repository.
Add it to your project as a local package: in Xcode, choose **File › Add Package Dependencies… › Add Local…**, select the `FloconSwift` folder, then add the `Flocon` library to your app target.

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

## Sample app

Open `FloconWorkspace.xcworkspace` and run the `FloconDemo` scheme. The sample triggers HTTP calls, loads an image list with Kingfisher, runs a WebSocket echo, and logs analytics events and table rows.

## Documentation

The public API is documented with DocC comments. In Xcode, choose **Product › Build Documentation** with the `Flocon` scheme to browse it.
