import Foundation
import Testing
@testable import Flocon

// The handlers themselves crash the process: these tests cover what they write and how it is read.
@Suite struct FloconCrashStoreTests {
    private let store = FloconCrashStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent("flocon-crashes-\(UUID().uuidString)")
    )

    @Test func readsTheRawFileOfASignalCrash() throws {
        let raw = """
        timestamp=1792356000
        signal=SIGTRAP
        0   FloconDemo    0x0000000100a1b2c3 $s10FloconDemo11ContentViewV4body + 120
        1   SwiftUI       0x00000001a0b1c2d3 SwiftUI + 1234

        """
        let report = try #require(FloconCrashStore.report(fromRawSignalCrash: raw, crashId: "id"))

        #expect(report.crashId == "id")
        #expect(report.timestamp == 1_792_356_000_000)
        #expect(report.exceptionType == "SIGTRAP")
        #expect(report.exceptionMessage.contains("force unwrap"))
        #expect(report.stackTrace.split(separator: "\n").count == 2)
        #expect(report.stackTrace.hasPrefix("0   FloconDemo"))
    }

    @Test func removesTheFramesOfTheSignalHandler() throws {
        let raw = """
        timestamp=1
        signal=SIGTRAP
        0   FloconDemo.debug.dylib   0x1 floconHandleSignal + 560
        1   FloconDemo.debug.dylib   0x2 floconHandleSignal + 12
        2   libsystem_platform.dylib 0x3 _sigtramp + 52
        3   libswiftCore.dylib       0x4 _assertionFailure + 348
        """
        let report = try #require(FloconCrashStore.report(fromRawSignalCrash: raw))
        #expect(report.stackTrace == "3   libswiftCore.dylib       0x4 _assertionFailure + 348")
    }

    @Test func ignoresARawFileWithoutSignal() {
        #expect(FloconCrashStore.report(fromRawSignalCrash: "garbage") == nil)
    }

    @Test func convertsThePendingSignalCrashOnce() throws {
        store.prepare()
        try Data("timestamp=10\nsignal=SIGSEGV\n0 frame\n".utf8).write(to: store.rawSignalFileURL)

        store.convertPendingSignalCrash()
        store.convertPendingSignalCrash()

        let reports = store.pendingReports()
        #expect(reports.count == 1)
        #expect(reports.first?.exceptionType == "SIGSEGV")
        #expect(reports.first?.timestamp == 10_000)
        #expect(try Data(contentsOf: store.rawSignalFileURL).isEmpty)
    }

    @Test func keepsReportsUntilDeleted() {
        let older = CrashReportRemote(crashId: "a", timestamp: 1, exceptionType: "NSRangeException", exceptionMessage: "m", stackTrace: "s")
        let newer = CrashReportRemote(crashId: "b", timestamp: 2, exceptionType: "SIGTRAP", exceptionMessage: "m", stackTrace: "s")
        store.save(newer)
        store.save(older)

        #expect(store.pendingReports() == [older, newer])

        store.delete(older)
        #expect(store.pendingReports() == [newer])
    }

    @Test func encodesLikeTheOtherSDKs() throws {
        let report = CrashReportRemote(crashId: "a", timestamp: 1, exceptionType: "T", exceptionMessage: "M", stackTrace: "S")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try #require(String(data: encoder.encode([report]), encoding: .utf8))
        #expect(json == #"[{"crashId":"a","exceptionMessage":"M","exceptionType":"T","stackTrace":"S","timestamp":1}]"#)
    }
}
