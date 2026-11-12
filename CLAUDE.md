# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

FloconSwift is the iOS/macOS SDK of [Flocon](https://github.com/openflocon/Flocon), a debugging tool for mobile apps. The SDK connects to the Flocon desktop app over a WebSocket and sends what happens in the app (network calls, analytics, databases, files...). The Android SDK (FloconAndroid) is the reference: the JSON sent to the desktop must stay compatible with it. No third-party dependency; Swift 6.0 tools (`swift-tools-version: 6.0`), Xcode 16+, iOS 15+ / macOS 12+.

A companion package, [FloconSwiftGrpc](https://github.com/openflocon/FloconSwiftGrpc) (separate repo), depends on the released version of this one and logs through `Flocon.shared.networkPlugin`. Keep that public API stable.

## Commands

```bash
swift build
swift test                                   # all tests (Swift Testing)
swift test --filter FloconStartTests         # one suite
swift test --filter FloconStartTests/configChangesTheHost   # one test
```

The demo app has its own project, opened through the workspace; it needs an iOS 17 or later simulator (the demo's deployment target is iOS 17):

```bash
xcodebuild -workspace FloconWorkspace.xcworkspace -scheme FloconDemo \
  -destination 'id=<simulator-udid>' -derivedDataPath <dir> build
```

Run it with the Flocon desktop app open; on the simulator the default host `localhost` works. Code style is checked by SwiftLint (`brew install swiftlint`, then `swiftlint lint --strict`; config in `.swiftlint.yml`, relaxed for tests in `Tests/.swiftlint.yml`). The `SwiftLint` GitHub Action runs it on every pull request that touches Swift files. There is no other CI.

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

## Who does what

Subagents live in `.claude/agents/`. The main session plans and writes code; delegate these jobs:

- **Explore** (haiku): finding where something is (files, symbols, usages). Use it instead of reading many files yourself. It returns paths, line numbers and one sentence each.
- **architect** (opus): before implementing a new plugin, a connection or outbox change, or a public API change, send it the plan. Apply its changes before starting.
- **test-runner** (haiku): running `swift build`, `swift test`, SwiftLint or the demo build after a change. It returns PASS/FAIL and only the failures.
- **reviewer** (sonnet): reviewing the diff before committing or opening a pull request. Fix what it reports, or say why it isn't a problem.

Explore only locates code; design questions go to architect.

## Git and pull requests

- Never push to `main`: work on a branch (`claude/<short-name>`) and bring `main` in with a merge, never a rebase or force-push on a branch someone else owns.
- One logical change per commit, with a short imperative summary and no prefix (`Add CLAUDE.md`, `Split FloconStart.swift: builder, feature kinds...`). Pull requests are merged with a merge commit: the title follows the same style.
- Only open a pull request when asked to, against `main`.
- Fill `.github/pull_request_template.md`: keep its headings, remove the sections that do not apply. Describe what changed and why, not the file list.
- There is no CI, so the `Verification` section is the only proof: tick only what was actually run, and say plainly what could not be run (for example no Swift toolchain in a cloud session) instead of claiming it passed.
- Never commit secrets, `local.properties`, signing keys or build outputs (`.build/`, derived data).
