import Foundation

// MARK: - Objective-C exceptions

/// Records the uncaught Objective-C exceptions (`NSException`), then lets the app crash as before.
enum FloconExceptionCrashHandler {
    private nonisolated(unsafe) static var store: FloconCrashStore?
    private nonisolated(unsafe) static var previousHandler: (@convention(c) (NSException) -> Void)?

    static func install(store: FloconCrashStore) {
        self.store = store
        previousHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(floconHandleUncaughtException)
    }

    fileprivate static func handle(_ exception: NSException) {
        // the exception is followed by an abort(): the signal handler must not record it again
        FloconSignalCrashHandler.markCrashAsRecorded()
        store?.save(
            CrashReportRemote(
                crashId: UUID().uuidString,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                exceptionType: exception.name.rawValue,
                exceptionMessage: exception.reason ?? "",
                stackTrace: exception.callStackSymbols.joined(separator: "\n")
            )
        )
        previousHandler?(exception)
    }
}

private func floconHandleUncaughtException(_ exception: NSException) {
    FloconExceptionCrashHandler.handle(exception)
}

// MARK: - Signals

/// Records the crashes reported as signals: Swift runtime errors (force unwrap of `nil`,
/// `fatalError`, index out of range…), invalid memory accesses and aborts.
///
/// A signal handler may only call async-signal-safe functions: no memory allocation, no Swift
/// `String`, no JSON. The handler writes the time, the signal and the call stack in a file opened
/// at install time, with buffers allocated at install time too. ``FloconCrashStore`` turns that
/// file into a crash report on the next launch.
///
/// The previous handler of each signal is restored and the signal raised again, so that the app
/// crashes as before, and other crash reporters still see the crash.
///
/// The handler does not run while a debugger is attached: the debugger catches the signals first.
enum FloconSignalCrashHandler {
    static let signals: [Int32] = [SIGTRAP, SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE]

    fileprivate nonisolated(unsafe) static var fileDescriptor: Int32 = -1
    fileprivate nonisolated(unsafe) static var isCrashRecorded: sig_atomic_t = 0
    fileprivate nonisolated(unsafe) static var frames: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
    fileprivate nonisolated(unsafe) static var digits: UnsafeMutablePointer<UInt8>?
    fileprivate nonisolated(unsafe) static var previousActions: UnsafeMutablePointer<sigaction>?

    fileprivate static let maxFrames: Int32 = 128
    fileprivate static let digitsCapacity = 32

    static func install(store: FloconCrashStore) {
        store.prepare()
        // the previous crash, if any, must be read before the file is emptied
        store.convertPendingSignalCrash()
        fileDescriptor = open(store.rawSignalFileURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fileDescriptor >= 0 else {
            FloconLogger.log("Cannot open the crash file: signal crashes will not be reported")
            return
        }

        frames = .allocate(capacity: Int(maxFrames))
        digits = .allocate(capacity: digitsCapacity)
        previousActions = .allocate(capacity: Int(NSIG))
        previousActions?.initialize(repeating: sigaction(), count: Int(NSIG))

        for signal in signals {
            var action = sigaction()
            action.__sigaction_u.__sa_handler = floconHandleSignal
            sigemptyset(&action.sa_mask)
            action.sa_flags = 0
            sigaction(signal, &action, previousActions! + Int(signal))
        }
    }

    /// Tells the signal handler that the crash is already recorded, by the exception handler.
    static func markCrashAsRecorded() {
        isCrashRecorded = 1
    }
}

/// Async-signal-safe: see ``FloconSignalCrashHandler``.
private func floconHandleSignal(_ signal: Int32) {
    let fd = FloconSignalCrashHandler.fileDescriptor
    if FloconSignalCrashHandler.isCrashRecorded == 0, fd >= 0 {
        FloconSignalCrashHandler.isCrashRecorded = 1
        floconWrite(fd, "timestamp=")
        floconWriteNumber(fd, Int(time(nil)))
        floconWrite(fd, "\nsignal=")
        floconWrite(fd, floconSignalName(signal))
        floconWrite(fd, "\n")
        if let frames = FloconSignalCrashHandler.frames {
            let count = backtrace(frames, FloconSignalCrashHandler.maxFrames)
            backtrace_symbols_fd(frames, count, fd)
        }
        fsync(fd)
    }

    // let the previous handler, or the system, handle the crash
    if let previous = FloconSignalCrashHandler.previousActions?[Int(signal)] {
        var action = previous
        sigaction(signal, &action, nil)
    } else {
        Darwin.signal(signal, SIG_DFL)
    }
    raise(signal)
}

private func floconWrite(_ fd: Int32, _ text: StaticString) {
    _ = write(fd, text.utf8Start, text.utf8CodeUnitCount)
}

/// Writes a positive number in base 10, into the buffer allocated at install time.
private func floconWriteNumber(_ fd: Int32, _ value: Int) {
    guard let digits = FloconSignalCrashHandler.digits else { return }
    var remaining = max(value, 0)
    var index = FloconSignalCrashHandler.digitsCapacity
    repeat {
        index -= 1
        digits[index] = UInt8(48 + remaining % 10)
        remaining /= 10
    } while remaining > 0 && index > 0
    _ = write(fd, digits + index, FloconSignalCrashHandler.digitsCapacity - index)
}

private func floconSignalName(_ signal: Int32) -> StaticString {
    switch signal {
    case SIGTRAP: "SIGTRAP"
    case SIGABRT: "SIGABRT"
    case SIGSEGV: "SIGSEGV"
    case SIGBUS: "SIGBUS"
    case SIGILL: "SIGILL"
    case SIGFPE: "SIGFPE"
    default: "SIGNAL"
    }
}
