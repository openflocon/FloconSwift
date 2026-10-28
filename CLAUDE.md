# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

FloconSwift is the iOS/macOS SDK of [Flocon](https://github.com/openflocon/Flocon), a debugging tool for mobile apps. The SDK connects to the Flocon desktop app over a WebSocket and sends what happens in the app (network calls, analytics, databases, files...). The Android SDK (FloconAndroid) is the reference: the JSON sent to the desktop must stay compatible with it. No third-party dependency; Swift tools 6.4, iOS 15+ / macOS 12+.

A companion package, [FloconSwiftGrpc](https://github.com/openflocon/FloconSwiftGrpc) (separate repo), depends on the released version of this one and logs through `Flocon.shared.networkPlugin`. Keep that public API stable.

## Commands

```bash
swift build
swift test                                   # all tests (Swift Testing)
swift test --filter FloconStartTests         # one suite
swift test --filter FloconStartTests/configChangesTheHost   # one test
```

The demo app has its own project, opened through the workspace; it needs an iOS 27 simulator (the demo's deployment target):

```bash
xcodebuild -workspace FloconWorkspace.xcworkspace -scheme FloconDemo \
  -destination 'id=<simulator-udid>' -derivedDataPath <dir> build
```

Run it with the Flocon desktop app open; on the simulator the default host `localhost` works. There is no CI and no linter.

## Architecture

- **Entry point** (`Sources/Flocon/Flocon.swift`, `FloconStart.swift`): `Flocon.shared` is a singleton that can only be initialized once (later calls are ignored). Two ways to start it: `startFlocon { flocon in flocon.install(.network) ... }` registers only the installed plugins; `Flocon.initialize(config:)` installs every plugin. Both go through `initializeFlocon(config:features:)`. Because the singleton cannot be reset, tests must not call `start`/`initialize` for real: test the builder (`@testable`) and the plugins directly with a fake `FloconMessageSender`.
- **Plugins** (`Sources/Flocon/Plugins/<Name>/`): each implements `FloconPlugin` (`Core/FloconPlugin.swift`), identified by a `pluginName` that must match the desktop's, and talks to the desktop through a `FloconMessageSender`. `FloconClient` keeps them in a dictionary keyed by name and routes incoming messages to them. The app uses them through the static accessors `Flocon.xPlugin` (`FloconPlugins.swift`), which are never `nil`: when the plugin is not installed or before start they return a plugin wired to a sender that drops everything (`Core/FloconNoOpPlugins.swift`). The optional `Flocon.shared.xPlugin` are kept for FloconSwiftGrpc. There are no global `flocon*` helpers: new API goes on the plugin.
- **Adding a plugin**: create the plugin, add a case to `FloconFeatureKind` and a `FloconFeature` (with its options type if it has any) in `<Plugin>Feature.swift` next to the plugin, plus the kind in `Start/FloconFeature.swift`, register it in `initializeFlocon`, add the accessor in `FloconClient` and `FloconPlugins.swift`.
- **Connection** (`Client/`, `WebSocket/`): `FloconConnections` runs one `FloconLink` (own WebSocket) per address: the default one (`config.host`), always tried, and one more (`additionalAddress`, the one saved in `UserDefaults`, or the one given to `Flocon.connect(address:)`). Each link retries every 3 s until connected, sends `bonjour`, then flushes what was logged; `onClosed` restarts it. Outgoing messages go through a serial `AsyncStream` outbox, so order is kept and JSON encoding happens off the caller's thread, then through `FloconOutbox`: one log, a cursor per link, a message is dropped once every link has sent it. Logging calls from the app must only queue values.
- **Device identity** (`Core/FloconAppInfos.swift`): app name, package, device id and platform are read from the bundle and the device; they are not configurable.
- **Network** (`Plugins/Network/`): calls are captured by a `URLProtocol` (`Interceptor/FloconURLProtocol.swift`). `URLSession.shared` is intercepted with `interceptSharedSession()`; other sessions need `URLSessionConfiguration.withFlocon()`. Mocks and bad-network simulation come from the desktop through the same plugin. Bodies are sent in full (as on Android); only the console logs are truncated.
- **Concurrency**: the package uses `ApproachableConcurrency` under Swift 6 language mode; shared state is protected with `NSLock` and types are `@unchecked Sendable` where needed.

## Conventions

- Code comments and DocC are in English, written as DocC (`///`, `- Parameter`, double-backtick symbol links), and never refer to the Android equivalent.
- One main type per file, named after the file (`FloconBuilder.swift`). Small types that only serve it (its options, a private helper) can sit beside it; as soon as a file holds several unrelated types or grows past a couple of hundred lines, split it. A plugin's `FloconFeature` and options live in its own folder (`Plugins/Database/FloconDatabaseFeature.swift`), not in `FloconStart.swift`.
- Console logging goes through `FloconLogger` and is off unless `Flocon.isLoggingEnabled` is set before starting.
- Public API changes need a README update (`README.md` has one section per plugin) and a test in `Tests/FloconTests/FloconPublicAPITests.swift`, which deliberately does not use `@testable` so it checks that the API is really public.
- The branch `main` is consumed by SPM users directly (no tagged release yet).
