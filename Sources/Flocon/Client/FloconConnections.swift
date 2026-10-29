import Foundation

/// The connections to the desktop app: the default address, always tried, and one more address
/// (given at start, saved from the last launch, or given with ``Flocon/connect(address:)``).
///
/// Each connection is tried again every 3 seconds until it succeeds, and when it is lost.
final class FloconConnections: @unchecked Sendable {
    private let client: FloconClient
    private let states: FloconConnectionStateStore
    private let config: FloconConfig
    private let addressStore: FloconAddressStore?
    private let connectMutex = AsyncMutex()

    init(
        client: FloconClient,
        states: FloconConnectionStateStore,
        config: FloconConfig,
        addressStore: FloconAddressStore?
    ) {
        self.client = client
        self.states = states
        self.config = config
        self.addressStore = addressStore
    }

    /// Starts the connection to the default address, then to the address of the previous launch.
    func start() {
        // the default address (localhost on the simulator) is always tried, whatever the other addresses
        launch(client.defaultLink)

        // then the address given by the app, or the last one that worked: the latter wins
        guard let address = addressStore?.load() ?? config.additionalAddress else { return }
        do {
            let url = try floconWebSocketURL(address: address, port: config.webSocketPort)
            if url != client.defaultLink.url {
                launch(client.addExtraLink(url: url))
            }
        } catch {
            FloconLogger.logError("Ignoring the address '\(address)'", error)
        }
    }

    /// Adds a connection to `address`, next to the default one, replacing the one added before.
    func connect(address: String) async -> FloconConnectResult {
        await connectMutex.lock()
        let result = await connectLocked(address: address)
        await connectMutex.unlock()
        return result
    }

    private func connectLocked(address: String) async -> FloconConnectResult {
        let url: URL
        do {
            url = try floconWebSocketURL(address: address, port: config.webSocketPort)
        } catch let error as FloconAddressError {
            return .invalidAddress(error.message)
        } catch {
            return .invalidAddress(error.localizedDescription)
        }
        let defaultLink = client.defaultLink
        if url == defaultLink.url {
            return defaultLink.isConnected
                ? .connected
                : .failed("\(address) is the default address, Flocon is already trying to connect to it")
        }
        if let previous = client.extraLink { await removeExtraLink(previous) }

        let link = client.addExtraLink(url: url)
        do {
            try await connectOnce(link)
            return .connected
        } catch {
            // the messages stay kept for the other addresses, call connect again to retry
            await removeExtraLink(link)
            return .failed(error.localizedDescription)
        }
    }

    private func launch(_ link: FloconLink) {
        states.set(.connecting, for: link.id)
        link.task = Task { [weak self] in
            await self?.connectUntilSuccess(link)
        }
    }

    /// Connects to the desktop app, retrying every 3 seconds until it succeeds.
    private func connectUntilSuccess(_ link: FloconLink) async {
        while !Task.isCancelled {
            do {
                try await connectOnce(link)
                return
            } catch {
                states.set(.failed(error.localizedDescription), for: link.id)
                FloconLogger.logError("Cannot connect to \(link.url), retrying in 3s", error)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    /// Opens the connection, then sends the handshake, then everything that was kept since the start,
    /// in the order it was logged.
    private func connectOnce(_ link: FloconLink) async throws {
        states.set(.connecting, for: link.id)
        try await client.connect(link, onClosed: { [weak self] in
            self?.connectionLost(link)
        })
        states.set(.connected, for: link.id)
        // the address typed by the user, or given at start, comes back at the next launch
        if link !== client.defaultLink, let host = link.url.host {
            addressStore?.save(host)
        }
    }

    /// Called from the WebSocket's `onClosed` callback, on another thread.
    private func connectionLost(_ link: FloconLink) {
        // the messages are kept until the next connection, try again to connect
        states.set(.buffering, for: link.id)
        launch(link)
    }

    private func removeExtraLink(_ link: FloconLink) async {
        // stop the retries to the previous address
        let task = link.task
        task?.cancel()
        link.task = nil
        await task?.value
        await client.removeExtraLink(link)
        states.clear(link.id)
    }
}

/// Lets one task at a time run a section of code that suspends.
actor AsyncMutex {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func lock() async {
        if isLocked {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            isLocked = true
        }
    }

    func unlock() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
