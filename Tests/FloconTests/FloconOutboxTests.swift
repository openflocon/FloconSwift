import Foundation
import Testing
@testable import Flocon

/// Records what the outbox sends, and can hold or fail a message.
private actor FakeTransport {
    private(set) var sent: [String] = []
    private var blocked: String?
    private var release: CheckedContinuation<Void, Never>?
    private var failureOnce: String?

    func send(_ message: String) async -> Bool {
        if message == blocked {
            blocked = nil
            await withCheckedContinuation { release = $0 }
        }
        if message == failureOnce {
            failureOnce = nil
            return false
        }
        sent.append(message)
        return true
    }

    /// The next send of `message` waits for ``resume()``.
    func block(on message: String) { blocked = message }
    func failOnce(on message: String) { failureOnce = message }
    var isBlocked: Bool { release != nil }

    func resume() {
        release?.resume()
        release = nil
    }
}

@Suite struct FloconOutboxTests {
    private func makeOutbox(capacity: Int = 5_000) -> (FloconOutbox, FakeTransport) {
        let transport = FakeTransport()
        return (FloconOutbox(capacity: capacity) { await transport.send($0) }, transport)
    }

    @Test func keepsMessagesUntilConnected() async {
        let (outbox, transport) = makeOutbox()
        await outbox.enqueue("a")
        await outbox.enqueue("b")

        #expect(await transport.sent.isEmpty)
        #expect(await outbox.bufferedCount == 2)
    }

    @Test func flushesTheHandshakeThenTheMessagesInOrder() async {
        let (outbox, transport) = makeOutbox()
        let messages = (0..<200).map { "m\($0)" }
        for message in messages { await outbox.enqueue(message) }

        await outbox.connected(handshake: "hello")

        #expect(await transport.sent == ["hello"] + messages)
        #expect(await outbox.bufferedCount == 0)
    }

    @Test func sendsRightAwayOnceConnected() async {
        let (outbox, transport) = makeOutbox()
        await outbox.connected(handshake: "hello")
        await outbox.enqueue("a")
        await outbox.enqueue("b")

        #expect(await transport.sent == ["hello", "a", "b"])
    }

    @Test func keepsTheMessagesEmittedWhileFlushing() async {
        let (outbox, transport) = makeOutbox()
        for message in ["m0", "m1", "m2"] { await outbox.enqueue(message) }
        await transport.block(on: "m1")

        let flush = Task { await outbox.connected(handshake: "hello") }
        while await !transport.isBlocked { await Task.yield() }
        // the flush is in the middle of "m1"
        await outbox.enqueue("late1")
        await outbox.enqueue("late2")
        await transport.resume()
        await flush.value

        #expect(await transport.sent == ["hello", "m0", "m1", "m2", "late1", "late2"])
        #expect(await outbox.bufferedCount == 0)
    }

    @Test func dropsTheOldestMessagesAboveTheCapacity() async {
        let (outbox, transport) = makeOutbox(capacity: 3)
        for index in 1...5 { await outbox.enqueue("m\(index)") }

        #expect(await outbox.bufferedCount == 3)
        #expect(await outbox.droppedCount == 2)

        await outbox.connected(handshake: "hello")
        #expect(await transport.sent == ["hello", "m3", "m4", "m5"])
    }

    @Test func keepsTheMessagesOfALostConnectionForTheNextOne() async {
        let (outbox, transport) = makeOutbox()
        await outbox.connected(handshake: "hello")
        await outbox.enqueue("a")
        await outbox.disconnected()
        await outbox.enqueue("b")
        await outbox.enqueue("c")

        #expect(await transport.sent == ["hello", "a"])

        await outbox.connected(handshake: "hello again")
        #expect(await transport.sent == ["hello", "a", "hello again", "b", "c"])
    }

    @Test func putsBackAMessageThatCouldNotBeSent() async {
        let (outbox, transport) = makeOutbox()
        for message in ["a", "b", "c"] { await outbox.enqueue(message) }
        await transport.failOnce(on: "b")

        await outbox.connected(handshake: "hello")
        // "b" failed: it and what follows wait for the next connection
        #expect(await transport.sent == ["hello", "a"])
        #expect(await outbox.bufferedCount == 2)

        await outbox.enqueue("d")
        #expect(await transport.sent == ["hello", "a"])

        await outbox.connected(handshake: "hello again")
        #expect(await transport.sent == ["hello", "a", "hello again", "b", "c", "d"])
    }
}

@Suite struct FloconMessageQueueTests {
    @Test func isFirstInFirstOut() {
        var queue = FloconMessageQueue(capacity: 10)
        queue.append("a")
        queue.append("b")

        #expect(queue.popFirst() == "a")
        #expect(queue.popFirst() == "b")
        #expect(queue.popFirst() == nil)
        #expect(queue.count == 0)
    }

    @Test func dropsTheOldestAboveTheCapacity() {
        var queue = FloconMessageQueue(capacity: 2)

        #expect(!queue.append("a"))
        #expect(!queue.append("b"))
        #expect(queue.append("c"))
        #expect(queue.count == 2)
        #expect(queue.popFirst() == "b")
        #expect(queue.popFirst() == "c")
    }

    @Test func putsAMessageBackAtTheFront() {
        var queue = FloconMessageQueue(capacity: 10)
        queue.append("a")
        queue.append("b")

        let first = queue.popFirst()!
        queue.pushFront(first)
        queue.pushFront("hello") // nothing to reuse at the front anymore

        #expect(queue.popFirst() == "hello")
        #expect(queue.popFirst() == "a")
        #expect(queue.popFirst() == "b")
    }

    @Test func staysInOrderAcrossCompactions() {
        var queue = FloconMessageQueue(capacity: 20_000)
        var expected = 0
        for index in 0..<10_000 {
            queue.append("\(index)")
            if index % 3 == 0 {
                #expect(queue.popFirst() == "\(expected)")
                expected += 1
            }
        }
        while let message = queue.popFirst() {
            #expect(message == "\(expected)")
            expected += 1
        }
        #expect(expected == 10_000)
    }

    @Test func keepsAtLeastOneMessage() {
        var queue = FloconMessageQueue(capacity: 0)
        queue.append("a")
        queue.append("b")

        #expect(queue.count == 1)
        #expect(queue.popFirst() == "b")
    }
}

@Suite struct FloconConnectionStateTests {
    @Test func startsIdle() {
        #expect(FloconConnectionStateStore().state == .idle)
    }

    @Test func streamStartsWithTheCurrentStateThenFollowsTheChanges() async {
        let store = FloconConnectionStateStore()
        store.set(.buffering)
        var states = store.stream.makeAsyncIterator()

        #expect(await states.next() == .buffering)
        store.set(.connecting)
        store.set(.connecting) // same state: not repeated
        store.set(.failed("offline"))
        store.set(.connected)

        #expect(await states.next() == .connecting)
        #expect(await states.next() == .failed("offline"))
        #expect(await states.next() == .connected)
        #expect(store.state == .connected)
    }
}
