import Foundation

/// Keeps the encoded messages in order until they can be sent to the desktop app(s).
///
/// Every message goes through one log, connected or not. Each ``Link`` (one per desktop address)
/// reads the log from its own position, and a single drain sends to the connected links: a message
/// sent while the log is being flushed waits for the flush to end, then is sent behind the others.
/// Nothing is lost and nothing is sent out of order.
///
/// A message is removed from the log once every link has sent it.
actor FloconOutbox {
    /// A connection to one desktop address. Its state is only touched by the outbox.
    final class Link: @unchecked Sendable {
        fileprivate let transport: @Sendable (String) async -> Bool
        fileprivate var isConnected = false
        fileprivate var pendingHandshake: String?
        /// Sequence number of the next message to send.
        fileprivate var cursor = 0

        /// - Parameter transport: Sends one message. Returns `false` if it could not be sent.
        init(transport: @escaping @Sendable (String) async -> Bool) {
            self.transport = transport
        }
    }

    /// Number of messages dropped because the buffer was full, since the start.
    private(set) var droppedCount = 0

    private var log: FloconMessageLog
    private var links: [Link] = []
    private var isDraining = false
    private var needsDrain = false

    /// - Parameter capacity: Number of messages kept. Above it, the oldest are dropped.
    init(capacity: Int) {
        self.log = FloconMessageLog(capacity: capacity)
    }

    /// Number of messages kept, waiting to be sent by at least one link.
    var bufferedCount: Int { log.count }

    /// Registers a link: it will receive what is still kept, then the next messages.
    func add(_ link: Link) {
        link.cursor = log.firstSequence
        links.append(link)
    }

    /// Unregisters a link: what only it was keeping is released.
    func remove(_ link: Link) {
        links.removeAll { $0 === link }
        trim()
    }

    /// Sends the message to the connected links, and keeps it for the others.
    func enqueue(_ message: String) async {
        if log.append(message) {
            droppedCount += 1
            FloconLogger.log("Buffer full, the oldest message was dropped")
        }
        await drain()
    }

    /// Starts sending on `link`: the handshake first, then the messages kept so far, then the new ones.
    func connected(_ link: Link, handshake: String) async {
        link.pendingHandshake = handshake
        link.isConnected = true
        await drain()
    }

    /// Stops sending on `link`: the next messages are kept until ``connected(_:handshake:)``.
    func disconnected(_ link: Link) {
        link.isConnected = false
    }

    private func drain() async {
        if isDraining {
            // the running drain goes through the links again before it ends
            needsDrain = true
            return
        }
        isDraining = true
        defer { isDraining = false }
        // Each send suspends: what is enqueued or connected meanwhile is handled by the next pass.
        repeat {
            needsDrain = false
            for link in links where link.isConnected {
                await drain(link)
            }
        } while needsDrain
        trim()
    }

    private func drain(_ link: Link) async {
        while link.isConnected {
            // the messages it did not send may have been dropped meanwhile
            link.cursor = max(link.cursor, log.firstSequence)
            if let handshake = link.pendingHandshake {
                if await link.transport(handshake) { link.pendingHandshake = nil } else { link.isConnected = false }
                continue
            }
            guard let message = log.message(at: link.cursor) else { return }
            // moves on once sent, so that a failure does not lose it
            if await link.transport(message) { link.cursor += 1 } else { link.isConnected = false }
        }
    }

    /// Removes what every link has sent. Nothing is removed while there is no link.
    private func trim() {
        guard let sentByAll = links.map(\.cursor).min() else { return }
        log.trim(upTo: sentByAll)
    }
}

/// The messages in the order they were logged, limited to a number of messages.
///
/// Each message has a sequence number, which does not change when the oldest are removed.
struct FloconMessageLog {
    private var items: [String] = []
    // Index of the oldest message: removing at the front of an array would move all the others.
    private var head = 0
    private let capacity: Int

    /// Sequence number of the oldest message kept.
    private(set) var firstSequence = 0

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    var count: Int { items.count - head }

    var isEmpty: Bool { head == items.count }

    /// Adds a message at the end.
    ///
    /// - Returns: `true` if the log was full, and its oldest message was dropped.
    @discardableResult
    mutating func append(_ message: String) -> Bool {
        items.append(message)
        guard count > capacity else { return false }
        removeFirst()
        return true
    }

    /// The message with this sequence number, `nil` if it was removed or is not logged yet.
    func message(at sequence: Int) -> String? {
        let index = head + sequence - firstSequence
        guard sequence >= firstSequence, index < items.count else { return nil }
        return items[index]
    }

    /// Removes the messages before this sequence number.
    mutating func trim(upTo sequence: Int) {
        while firstSequence < sequence, !isEmpty {
            removeFirst()
        }
    }

    private mutating func removeFirst() {
        items[head] = "" // free it now, the slot stays until the next compaction
        head += 1
        firstSequence += 1
        if head >= 1024, head * 2 >= items.count {
            items.removeFirst(head)
            head = 0
        }
    }
}
