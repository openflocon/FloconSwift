import Foundation

/// Keeps the crashes on disk until they are sent to the desktop app.
///
/// Each crash is a JSON file. A signal crash is first written by the signal handler as a raw
/// text file (see ``FloconSignalCrashHandler``), and turned into a JSON file on the next launch.
struct FloconCrashStore: Sendable {
    let directory: URL

    /// Store of the running app, in `Library/Application Support/flocon_crashes`.
    static let app = FloconCrashStore(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("flocon_crashes", isDirectory: true)
    )

    /// File written by the signal handler, which cannot build JSON.
    var rawSignalFileURL: URL { directory.appendingPathComponent("pending_signal.txt") }

    func prepare() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: Reports

    func save(_ report: CrashReportRemote) {
        prepare()
        do {
            let data = try JSONEncoder().encode(report)
            try data.write(to: directory.appendingPathComponent("\(report.crashId).json"), options: .atomic)
        } catch {
            FloconLogger.logError("Cannot save the crash report", error)
        }
    }

    /// The crashes not sent yet, oldest first.
    func pendingReports() -> [CrashReportRemote] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(CrashReportRemote.self, from: Data(contentsOf: $0)) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func delete(_ report: CrashReportRemote) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(report.crashId).json"))
    }

    // MARK: Signal crashes

    /// Turns the raw file of the last signal crash, if any, into a crash report, then empties it.
    func convertPendingSignalCrash() {
        guard let content = try? String(contentsOf: rawSignalFileURL, encoding: .utf8), !content.isEmpty else { return }
        if let report = Self.report(fromRawSignalCrash: content) {
            save(report)
        }
        try? Data().write(to: rawSignalFileURL)
    }

    /// Reads the raw file written by the signal handler.
    ///
    /// The file starts with `timestamp=<seconds>` and `signal=<name>` lines, followed by the
    /// call stack, one frame per line. The frames of the signal handler are removed.
    static func report(fromRawSignalCrash content: String, crashId: String = UUID().uuidString) -> CrashReportRemote? {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var timestamp: Int64?
        var signal: String?
        while let line = lines.first, line.hasPrefix("timestamp=") || line.hasPrefix("signal=") {
            lines.removeFirst()
            if line.hasPrefix("timestamp=") { timestamp = Int64(line.dropFirst("timestamp=".count)) }
            if line.hasPrefix("signal=") { signal = String(line.dropFirst("signal=".count)) }
        }
        guard let signal else { return nil }
        // the first frames are the signal handler itself, up to the system trampoline
        if let trampoline = lines.firstIndex(where: { $0.contains("_sigtramp") }) {
            lines.removeFirst(trampoline + 1)
        }
        return CrashReportRemote(
            crashId: crashId,
            timestamp: (timestamp ?? 0) * 1000,
            exceptionType: signal,
            exceptionMessage: description(ofSignal: signal),
            stackTrace: lines.filter { !$0.isEmpty }.joined(separator: "\n")
        )
    }

    private static func description(ofSignal signal: String) -> String {
        switch signal {
        case "SIGTRAP":
            return "The app stopped on a trap: usually a Swift runtime error, such as a force unwrap of nil, "
                + "an index out of range or a fatalError. Its message is printed in the console."
        case "SIGABRT":
            return "The app aborted, for example on a failed assertion or a precondition."
        case "SIGSEGV", "SIGBUS":
            return "The app accessed an invalid memory address (EXC_BAD_ACCESS)."
        case "SIGILL":
            return "The app executed an illegal instruction."
        case "SIGFPE":
            return "The app made an arithmetic error, such as an integer division by zero."
        default:
            return "The app was stopped by the \(signal) signal."
        }
    }
}
