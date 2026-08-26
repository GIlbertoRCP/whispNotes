import Foundation
import os.log
import AppKit

// MARK: - Unified Apple os.Logger Diagnostics Subsystem
public struct WhispLogger {
    public static let subsystem = "com.whispnotes.app"
    
    public static let general = Logger(subsystem: subsystem, category: "General")
    public static let dataManager = Logger(subsystem: subsystem, category: "DataManager")
    public static let speech = Logger(subsystem: subsystem, category: "SpeechTranscriber")
    public static let gemmaAI = Logger(subsystem: subsystem, category: "GemmaAI")
    public static let updater = Logger(subsystem: subsystem, category: "ReleaseUpdater")
    public static let ui = Logger(subsystem: subsystem, category: "UI")
    
    /// In-memory ring buffer of recent diagnostic events for user bug reporting
    public static var recentLogs: [String] = []
    private static let maxLogHistory = 200
    private static let logLock = NSLock()
    
    public static func log(_ message: String, category: String = "General") {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] [\(category)] \(message)"
        
        logLock.lock()
        recentLogs.append(line)
        if recentLogs.count > maxLogHistory {
            recentLogs.removeFirst(recentLogs.count - maxLogHistory)
        }
        logLock.unlock()
        
        switch category {
        case "DataManager": dataManager.info("\(message, privacy: .public)")
        case "SpeechTranscriber": speech.info("\(message, privacy: .public)")
        case "GemmaAI": gemmaAI.info("\(message, privacy: .public)")
        case "ReleaseUpdater": updater.info("\(message, privacy: .public)")
        default: general.info("\(message, privacy: .public)")
        }
    }
    
    /// Exports a formatted system diagnostics bundle for bug reporting
    public static func exportDiagnosticsBundle(notesCount: Int) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export WhispNotes System Diagnostics"
        savePanel.nameFieldStringValue = "whispnotes_diagnostics_\(Int(Date().timeIntervalSince1970)).txt"
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            let physicalMemory = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
            let processorCount = ProcessInfo.processInfo.processorCount
            
            var report = """
            ==================================================
            WHISPNOTES SYSTEM DIAGNOSTICS REPORT
            Generated: \(Date())
            ==================================================
            
            [SYSTEM INFO]
            - macOS Version: \(osVersion)
            - Total RAM: \(physicalMemory) GB
            - CPU Cores: \(processorCount)
            - Notes in Vault: \(notesCount)
            - App Version: 1.4.0
            
            [RECENT DIAGNOSTIC EVENT LOGS]
            """
            
            logLock.lock()
            for logLine in recentLogs {
                report += "\n" + logLine
            }
            logLock.unlock()
            
            report += "\n\n==================== END OF REPORT ====================\n"
            
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
