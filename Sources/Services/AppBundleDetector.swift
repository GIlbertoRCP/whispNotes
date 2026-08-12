import Foundation

// MARK: - App Bundle Detection Utility
/// Detects whether the process is running inside a proper .app bundle.
/// macOS TCC (Transparency, Consent, and Control) on macOS 26+ requires a signed .app bundle
/// for privacy-sensitive APIs (microphone, speech recognition). Bare CLI executables from
/// `swift run` will be terminated with SIGABRT if they attempt to use these APIs.
enum AppBundleDetector {
    /// Returns `true` if running inside a proper .app bundle (e.g. WhispNotes.app/Contents/MacOS/WhispNotes).
    /// Returns `false` if running as a bare CLI executable (e.g. .build/debug/swift-whispnotes via `swift run`).
    ///
    /// NOTE: We cannot use `Bundle.main.bundleIdentifier` because the `-sectcreate __TEXT __info_plist`
    /// linker flag embeds the Info.plist into the Mach-O binary, causing Bundle.main to report
    /// a bundleIdentifier even for bare CLI executables. Instead, we check the actual executable path.
    static var isRunningInAppBundle: Bool {
        let execPath = ProcessInfo.processInfo.arguments.first ?? ""
        return execPath.contains(".app/Contents/MacOS/")
    }
    
    /// Returns `true` if TCC-protected audio/speech APIs are safe to call.
    /// On macOS 26+, calling AVCaptureDevice.requestAccess or SFSpeechRecognizer.authorizationStatus()
    /// from a non-bundled executable causes an immediate SIGABRT.
    static var canUseTCCProtectedAPIs: Bool {
        return isRunningInAppBundle
    }
}

