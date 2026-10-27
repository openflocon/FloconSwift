import Foundation

/// Keeps the encoded messages in order until they can be sent to the desktop app.
///
/// Every message goes through the buffer, whether the app is connected or not, and a single
/// drain empties it: a message sent while the buffer is being flushed is put behind the others,
/// so nothing is lost and nothing is sent out of order.
actor FloconOutbox {
    /// Number of messages dropped because the buffer was full, since the start.
    private(set) var droppedCount = 0

    private var queue: FloconMessageQueue
    private let transport: @Sendable (String) async -> Bool
    private var isConnected = false
    private var isDraining = false

    /// - Parameters:
    ///   - capacity: Number of messages kept while not connected. Above it, the oldest are dropped.
    ///   - transport: Sends one message. Returns `false` if it could not be sent.
    init(capacity: Int, transport: @escaping @Sendable (String) async -> Bool) {
        self.queue = FloconMessageQueue(capacity: capacity)
        self.transport = transport
    }

    /// Number of messages waiting to be sent.
    var bufferedCount: Int { queue.count }

    /// Sends the message, or keeps it if the app is not connected.
    func enqueue(_ message: String) async {
        if queue.append(message) {
            droppedCount += 1
            FloconLogger.log("Buffer full, the oldest message was dropped")
        }
        await drain()
    }

    /// Starts sending: the handshake first, then the messages kept so far, then the new ones.
    func connected(handshake: String) async {
        queue.pushFront(handshake)
        isConnected = true
        await drain()
    }

    /// Stops sending: the next messages are kept until ``connected(handshake:)``.
    func disconnected() {
        isConnected = false
    }

    private func drain() async {
        guard isConnected, !isDraining else { return }
        isDraining = true
        defer { isDraining = false }
        // The buffer is read again after each send, which suspends: the messages enqueued
        // meanwhile are sent by this loop, after the ones that were already there.
        while isConnected, let message = queue.popFirst() {
            if await transport(message) { continue }
            // put it back, first: it is older than everything else
            queue.pushFront(message)
            isConnected = false
        }
    }
}

/// A first-in first-out queue of messages, limited to a number of messages.
struct FloconMessageQueue {
    private var items: [String] = []
    // Index of the oldest message: removing at the front of an array would move all the others.
    private var head = 0
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    var count: Int { items.count - head }

    /// Adds a message at the end.
    ///
    /// - Returns: `true` if the queue was full, and its oldest message was dropped.
    @discardableResult
    mutating func append(_ message: String) -> Bool {
        items.append(message)
        guard count > capacity else { return false }
        _ = popFirst()
        return true
    }

    mutating func popFirst() -> String? {
        guard head < items.count else { return nil }
        let message = items[head]
        items[head] = "" // free it now, the slot stays until the next compaction
        head += 1
        if head >= 1024, head * 2 >= items.count {
            items.removeFirst(head)
            head = 0
        }
        return message
    }

    /// Puts a message back at the front. Does not drop anything, even above the capacity.
    mutating func pushFront(_ message: String) {
        if head > 0 {
            head -= 1
            items[head] = message
        } else {
            items.insert(message, at: 0)
        }
    }
}
