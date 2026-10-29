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
    /// An outbox with one link, the one of `transport`.
    private func makeOutbox(capacity: Int = 5_000) async -> (FloconOutbox, FloconOutbox.Link, FakeTransport) {
        let transport = FakeTransport()
        let outbox = FloconOutbox(capacity: capacity)
        let link = FloconOutbox.Link { await transport.send($0) }
        await outbox.add(link)
        return (outbox, link, transport)
    }

    @Test func keepsMessagesUntilConnected() async {
        let (outbox, _, transport) = await makeOutbox()
        await outbox.enqueue("a")
        await outbox.enqueue("b")

        #expect(await transport.sent.isEmpty)
        #expect(await outbox.bufferedCount == 2)
    }

    @Test func flushesTheHandshakeThenTheMessagesInOrder() async {
        let (outbox, link, transport) = await makeOutbox()
        let messages = (0..<200).map { "m\($0)" }
        for message in messages { await outbox.enqueue(message) }

        await outbox.connected(link, handshake: "hello")

        #expect(await transport.sent == ["hello"] + messages)
        #expect(await outbox.bufferedCount == 0)
    }

    @Test func sendsRightAwayOnceConnected() async {
        let (outbox, link, transport) = await makeOutbox()
        await outbox.connected(link, handshake: "hello")
        await outbox.enqueue("a")
        await outbox.enqueue("b")

        #expect(await transport.sent == ["hello", "a", "b"])
    }

    @Test func keepsTheMessagesEmittedWhileFlushing() async {
        let (outbox, link, transport) = await makeOutbox()
        for message in ["m0", "m1", "m2"] { await outbox.enqueue(message) }
        await transport.block(on: "m1")

        let flush = Task { await outbox.connected(link, handshake: "hello") }
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
        let (outbox, link, transport) = await makeOutbox(capacity: 3)
        for index in 1...5 { await outbox.enqueue("m\(index)") }

        #expect(await outbox.bufferedCount == 3)
        #expect(await outbox.droppedCount == 2)

        await outbox.connected(link, handshake: "hello")
        #expect(await transport.sent == ["hello", "m3", "m4", "m5"])
    }

    @Test func keepsTheMessagesOfALostConnectionForTheNextOne() async {
        let (outbox, link, transport) = await makeOutbox()
        await outbox.connected(link, handshake: "hello")
        await outbox.enqueue("a")
        await outbox.disconnected(link)
        await outbox.enqueue("b")
        await outbox.enqueue("c")

        #expect(await transport.sent == ["hello", "a"])

        await outbox.connected(link, handshake: "hello again")
        #expect(await transport.sent == ["hello", "a", "hello again", "b", "c"])
    }

    @Test func putsBackAMessageThatCouldNotBeSent() async {
        let (outbox, link, transport) = await makeOutbox()
        for message in ["a", "b", "c"] { await outbox.enqueue(message) }
        await transport.failOnce(on: "b")

        await outbox.connected(link, handshake: "hello")
        // "b" failed: it and what follows wait for the next connection
        #expect(await transport.sent == ["hello", "a"])
        #expect(await outbox.bufferedCount == 2)

        await outbox.enqueue("d")
        #expect(await transport.sent == ["hello", "a"])

        await outbox.connected(link, handshake: "hello again")
        #expect(await transport.sent == ["hello", "a", "hello again", "b", "c", "d"])
    }

    @Test func sendsToEveryConnectedAddress() async {
        let outbox = FloconOutbox(capacity: 5_000)
        let localhost = FakeTransport()
        let remote = FakeTransport()
        let localhostLink = FloconOutbox.Link { await localhost.send($0) }
        let remoteLink = FloconOutbox.Link { await remote.send($0) }
        await outbox.add(localhostLink)
        await outbox.add(remoteLink)
        await outbox.enqueue("a")

        await outbox.connected(remoteLink, handshake: "hello")
        await outbox.enqueue("b")
        await outbox.connected(localhostLink, handshake: "hi")
        await outbox.enqueue("c")

        #expect(await remote.sent == ["hello", "a", "b", "c"])
        #expect(await localhost.sent == ["hi", "a", "b", "c"])
    }

    @Test func keepsAMessageWhileAnAddressHasNotSentIt() async {
        let outbox = FloconOutbox(capacity: 5_000)
        let localhostLink = FloconOutbox.Link { _ in false }
        let remote = FakeTransport()
        let remoteLink = FloconOutbox.Link { await remote.send($0) }
        await outbox.add(localhostLink)
        await outbox.add(remoteLink)
        await outbox.connected(remoteLink, handshake: "hello")
        await outbox.enqueue("a")

        // localhost never connected: it still has to get "a" if it connects
        #expect(await outbox.bufferedCount == 1)

        await outbox.remove(localhostLink)
        #expect(await outbox.bufferedCount == 0)
    }

    @Test func anAddressAddedLateGetsWhatIsStillKept() async {
        let outbox = FloconOutbox(capacity: 5_000)
        await outbox.add(FloconOutbox.Link { _ in false })
        await outbox.enqueue("a")
        await outbox.enqueue("b")

        let remote = FakeTransport()
        let remoteLink = FloconOutbox.Link { await remote.send($0) }
        await outbox.add(remoteLink)
        await outbox.connected(remoteLink, handshake: "hello")

        #expect(await remote.sent == ["hello", "a", "b"])
    }
}

@Suite struct FloconMessageLogTests {
    @Test func isFirstInFirstOutWithSequenceNumbers() {
        var log = FloconMessageLog(capacity: 10)
        log.append("a")
        log.append("b")

        #expect(log.message(at: 0) == "a")
        #expect(log.message(at: 1) == "b")
        #expect(log.message(at: 2) == nil)

        log.trim(upTo: 1)
        #expect(log.message(at: 0) == nil)
        #expect(log.message(at: 1) == "b")
        #expect(log.firstSequence == 1)
        #expect(log.count == 1)
    }

    @Test func dropsTheOldestAboveTheCapacity() {
        var log = FloconMessageLog(capacity: 2)

        let first = log.append("a")
        let second = log.append("b")
        let third = log.append("c")

        #expect(!first)
        #expect(!second)
        #expect(third)
        #expect(log.count == 2)
        #expect(log.message(at: 0) == nil)
        #expect(log.message(at: 1) == "b")
        #expect(log.message(at: 2) == "c")
    }

    @Test func staysInOrderAcrossCompactions() {
        var log = FloconMessageLog(capacity: 20_000)
        var expected = 0
        for index in 0..<10_000 {
            log.append("\(index)")
            if index % 3 == 0 {
                #expect(log.message(at: expected) == "\(expected)")
                expected += 1
                log.trim(upTo: expected)
            }
        }
        while !log.isEmpty {
            #expect(log.message(at: expected) == "\(expected)")
            expected += 1
            log.trim(upTo: expected)
        }
        #expect(expected == 10_000)
    }

    @Test func keepsAtLeastOneMessage() {
        var log = FloconMessageLog(capacity: 0)
        log.append("a")
        log.append("b")

        #expect(log.count == 1)
        #expect(log.message(at: 1) == "b")
    }
}

@Suite struct FloconConnectionStateTests {
    @Test func startsIdle() {
        #expect(FloconConnectionStateStore().state == .idle)
    }

    @Test func streamStartsWithTheCurrentStateThenFollowsTheChanges() async {
        let store = FloconConnectionStateStore()
        let link = UUID()
        store.set(.buffering, for: link)
        var states = store.stream.makeAsyncIterator()

        #expect(await states.next() == .buffering)
        store.set(.connecting, for: link)
        store.set(.connecting, for: link) // same state: not repeated
        store.set(.failed("offline"), for: link)
        store.set(.connected, for: link)

        #expect(await states.next() == .connecting)
        #expect(await states.next() == .failed("offline"))
        #expect(await states.next() == .connected)
        #expect(store.state == .connected)
    }

    @Test func isConnectedAsSoonAsOneAddressIs() {
        let store = FloconConnectionStateStore()
        let localhost = UUID()
        let remote = UUID()

        store.set(.failed("offline"), for: localhost)
        #expect(store.state == .failed("offline"))
        store.set(.connecting, for: remote)
        #expect(store.state == .connecting)
        store.set(.connected, for: remote)
        store.set(.failed("offline"), for: localhost)
        #expect(store.state == .connected)

        store.clear(remote)
        #expect(store.state == .failed("offline"))
        store.clear(localhost)
        #expect(store.state == .idle)
    }
}
