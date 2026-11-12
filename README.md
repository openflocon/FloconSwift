# Flocon for iOS

Swift SDK for [Flocon](https://github.com/openflocon/Flocon), the desktop debugger for mobile apps: inspect the network calls, databases, files, preferences and more of your iOS or macOS app, live, from your Mac.

<!-- screenshot: hero -->

## Requirements

- iOS 15+ or macOS 12+
- Xcode 16+ (Swift 6.0, the `swift-tools-version` of the package)
- The [Flocon desktop app](https://github.com/openflocon/Flocon) running on your Mac

## Installation

Flocon is distributed with Swift Package Manager. The latest release is [2.0.0](https://github.com/openflocon/FloconSwift/releases).

### Xcode

1. Choose **File > Add Package Dependencies...**
2. Paste `https://github.com/openflocon/FloconSwift.git` in the search field.
3. Keep **Dependency Rule** on **Up to Next Major Version** from `2.0.0`, then click **Add Package**.
4. Add the `Flocon` library to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/openflocon/FloconSwift.git", from: "2.0.0"),
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

## Quick start

Start the SDK as early as possible, for example in the initializer of your `App`, and install the features you need:

```swift
import Flocon
import SwiftUI

@main
struct MyApp: App {
    init() {
        startFlocon { flocon in
            flocon.install(.network)
            flocon.install(.analytics)
            flocon.install(.preferences)
        }
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

`Flocon.initialize()` is the short form that installs every feature. Plugins that are not installed do nothing, so their calls can stay in your code.

Network calls are logged for the sessions built with `URLSession(configuration: .default.withFlocon())`; call `Flocon.interceptSharedSession()` to also log `URLSession.shared`.

### Info.plist

| Key | Needed for |
| --- | --- |
| `NSLocalNetworkUsageDescription` | Reaching your Mac on the local network (physical device) |
| `NSCameraUsageDescription` | Scanning the QR code with `FloconQRScannerView` |

No App Transport Security exception is needed: the SDK talks to the desktop over `wss://` and `https://` (WebSocket and file transfers), with the self-signed certificate of the desktop app, which is accepted without being verified (encrypted, not authenticated).

### Simulator or physical device

- **Simulator**: nothing to do, the default host `localhost` works.
- **Physical device**: give the local IP address of your Mac, with `flocon.config(host: "192.168.1.20")` in the `startFlocon` block.
- **No IP at hand**: scan the QR code shown by Flocon Desktop with `FloconQRScannerView` (iOS only), or call `Flocon.connect(address:)` from a debug menu:

```swift
.sheet(isPresented: $isScanning) {
    FloconQRScannerView { result in
        if result == .connected { isScanning = false }
    }
}
```

Until a desktop is reachable, the SDK keeps what the app logs in memory and sends it once connected. If the app does not show up, set `Flocon.isLoggingEnabled = true` before starting the SDK to print its `[Flocon]` logs in the Xcode console.

More about the connection, custom ports and troubleshooting: [Connect your app](https://openflocon.github.io/Flocon/setup/) and [Troubleshooting](https://openflocon.github.io/Flocon/troubleshooting/).

## Features

| Feature | Enable with | Documentation |
| --- | --- | --- |
| Network (HTTP, images, mocks, bad network simulation) | `.network` | [Network](https://openflocon.github.io/Flocon/network/), [Mocking](https://openflocon.github.io/Flocon/mocking/), [Bad quality](https://openflocon.github.io/Flocon/bad-quality/), [Images](https://openflocon.github.io/Flocon/image/) |
| WebSockets (events you log) | `.network` | [WebSocket](https://openflocon.github.io/Flocon/websocket/) |
| gRPC | `.network` + [FloconSwiftGrpc](https://github.com/openflocon/FloconSwiftGrpc) | [gRPC](https://openflocon.github.io/Flocon/grpc/) |
| Databases (SQLite, Core Data, GRDB) | `.database` | [Database](https://openflocon.github.io/Flocon/database/) |
| Preferences (`UserDefaults`, keychain) | `.preferences` | [SharedPreferences](https://openflocon.github.io/Flocon/sharedpref/) |
| Files | `.files` | [Files](https://openflocon.github.io/Flocon/files/) |
| Dashboards | `.dashboard` | [Dashboard](https://openflocon.github.io/Flocon/dashboard/) |
| Tables | `.tables` | [Table](https://openflocon.github.io/Flocon/table/) |
| Deeplinks | `.deeplinks` | [Deeplink](https://openflocon.github.io/Flocon/deeplink/) |
| Analytics | `.analytics` | [Analytics](https://openflocon.github.io/Flocon/analytics/) |
| Feature flags | `.featureFlags` | [Feature flags](https://openflocon.github.io/Flocon/featureflags/) |
| Timeline (navigation, user actions, lifecycle, your own events) | `.timeline` | [Timeline](https://openflocon.github.io/Flocon/timeline/) |
| Crash reporter | `.crashReporter` | [Crash reporter](https://openflocon.github.io/Flocon/crashreporter/) |

Features with options take a closure, for example:

```swift
startFlocon { flocon in
    flocon.install(.database) { $0.register(displayName: "App", url: databaseURL) }
    flocon.install(.files) { $0.appGroup("group.com.example.app") }
    flocon.install(.preferences) { $0.userDefaults(sharedDefaults, suiteName: "group.com.example.app") }
}
```

Each feature is also reachable at runtime through `Flocon.networkPlugin`, `Flocon.databasePlugin`, `Flocon.filesPlugin`, `Flocon.deeplinksPlugin`, `Flocon.timelinePlugin`, and so on. They are never `nil` and do nothing when the feature is not installed.

## AI agents

Flocon ships an MCP server, so an AI agent such as Claude Code, Cursor or Codex can read what your app does (network calls, databases, logs...) while it runs, and debug it with you. See [MCP](https://openflocon.github.io/Flocon/mcp/) and the [MCP cookbook](https://openflocon.github.io/Flocon/mcp-cookbook/).

## Sample app

Open `FloconWorkspace.xcworkspace` and run the `FloconDemo` scheme (iOS 17+ simulator) with the Flocon desktop app open. It has one screen per feature.

## Documentation

The full documentation, with Kotlin, Swift and Flutter examples for every feature, is on [openflocon.github.io/Flocon](https://openflocon.github.io/Flocon/). The public API is also documented with DocC comments: in Xcode, choose **Product > Build Documentation** with the `Flocon` scheme.

## Contributing

Issues and pull requests are welcome on [FloconSwift](https://github.com/openflocon/FloconSwift). Run `swift build` and `swift test`, and `swiftlint lint --strict` before opening a pull request. The desktop app lives in [openflocon/Flocon](https://github.com/openflocon/Flocon).

## License

MIT, see [LICENSE](LICENSE).
