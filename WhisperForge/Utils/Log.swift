import Foundation
import os

/// Centralized logging for WhisperForge.
///
/// Privacy-first dictation means diagnostics must never persist the user's speech
/// or file paths into the macOS unified log. `Log.debug` compiles to nothing in
/// Release, so any leftover diagnostic logging is stripped from shipping builds.
/// Anything that genuinely must ship goes through `os.Logger` with explicit
/// privacy markers (default `.private`), never plain `print`.
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.vitorsolen.WhisperForge"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let model = Logger(subsystem: subsystem, category: "model")

    /// Debug-only diagnostic. No-op in Release; the argument is not even evaluated.
    @inline(__always)
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        Swift.print(message())
        #endif
    }

    /// Ships in Release. The message is marked public, so pass diagnostics only —
    /// never the user's transcript, speech, or other private content.
    static func error(_ message: @autoclosure () -> String) {
        general.error("\(message(), privacy: .public)")
    }
}
