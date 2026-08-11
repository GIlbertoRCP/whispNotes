import Foundation
import Combine

// MARK: - Data Manager (JSON Persistence, Rolling Backups & Vault Export)
class NotesDataManager: ObservableObject {
    static let shared = NotesDataManager()
    
    @Published var isSaving = false
    @Published var lastSavedAt: Date? = Date()
    
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let ioQueue = DispatchQueue(label: "com.whispnotes.datamanager.io", qos: .userInitiated)
    
    var appSupportDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("com.whispnotes.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var fileURL: URL {
        appSupportDir.appendingPathComponent("notes.json")
    }

    var backupsDir: URL {
        let dir = appSupportDir.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var attachmentsDir: URL {
        let dir = appSupportDir.appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func loadNotes() -> [NoteItem] {
        return ioQueue.sync {
            let decoder = JSONDecoder()
            if let data = try? Data(contentsOf: fileURL), let notes = try? decoder.decode([NoteItem].self, from: data) {
                return notes
            }
            
            // Corruption recovery: load latest backup snapshot
            if let recoveredNotes = recoverFromLatestBackup() {
                return recoveredNotes
            }
            
            return getSeedNotes()
        }
    }

    func saveNotes(_ notes: [NoteItem], debounce: Bool = true) {
        pendingSaveWorkItem?.cancel()
        
        DispatchQueue.main.async {
            self.isSaving = true
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.ioQueue.async {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(notes) {
                    try? data.write(to: self.fileURL, options: .atomic)
                    self.createRollingBackup(data: data)
                }
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.lastSavedAt = Date()
                }
            }
        }
        
        pendingSaveWorkItem = workItem
        if debounce {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        } else {
            workItem.perform()
        }
    }
    
    func saveNotesImmediately(_ notes: [NoteItem]) {
        saveNotes(notes, debounce: false)
    }

    // MARK: - Rolling Backups Management
    private func createRollingBackup(data: Data) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupURL = backupsDir.appendingPathComponent("notes_backup_\(timestamp).json")
        try? data.write(to: backupURL, options: .atomic)
        
        // Retain last 10 rolling snapshots
        if let files = try? FileManager.default.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: [.creationDateKey]) {
            let sortedFiles = files.filter { $0.pathExtension == "json" }.sorted { f1, f2 in
                let d1 = (try? f1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let d2 = (try? f2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return d1 > d2
            }
            if sortedFiles.count > 10 {
                for file in sortedFiles.dropFirst(10) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    private func recoverFromLatestBackup() -> [NoteItem]? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: [.creationDateKey]) else { return nil }
        let sortedFiles = files.filter { $0.pathExtension == "json" }.sorted { f1, f2 in
            let d1 = (try? f1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let d2 = (try? f2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return d1 > d2
        }
        let decoder = JSONDecoder()
        for file in sortedFiles {
            if let data = try? Data(contentsOf: file), let notes = try? decoder.decode([NoteItem].self, from: data) {
                return notes
            }
        }
        return nil
    }

    // MARK: - Full Vault Export
    func exportVaultToFolder(targetDir: URL, notes: [NoteItem]) {
        let fileManager = FileManager.default
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for note in notes {
            let safeFolderName = note.folder.replacingOccurrences(of: "/", with: "-")
            let folderURL = targetDir.appendingPathComponent(safeFolderName, isDirectory: true)
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            let safeTitle = note.title.replacingOccurrences(of: "/", with: "-")
            let fileURL = folderURL.appendingPathComponent("\(safeTitle).md")
            
            let frontmatter = """
            ---
            title: "\(note.title)"
            folder: "\(note.folder)"
            created: "\(formatter.string(from: note.timestamp))"
            standalone: \(note.isStandalone)
            ---
            
            \(note.content)
            """
            
            try? frontmatter.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    private func getSeedNotes() -> [NoteItem] {
        return [
            NoteItem(
                title: "Welcome to Native WhispNotes",
                folder: "General",
                content: "# Pure Native SwiftUI\n\nThis application runs 100% native on macOS with **zero background HTTP servers** or external API ports.\n\n### Markdown Table Example\n| Feature | Status | Quality |\n| --- | --- | --- |\n| Wiki Links | Active | 100% |\n| Diarization | Active | Native |\n\n### Code Block Example\n```swift\nfunc helloWorld() {\n    print(\"Hello WhispNotes!\")\n}\n```\n\n### Key Shortcuts\n- `⌘N` - New Standalone Note\n- `⌘D` - Today's Daily Note\n- `⌘K` or `⌘O` - Spotlight Search Palette\n- `⌘G` - Obsidian Knowledge Graph Canvas\n- `⌘⇧F` - Zen Focus Mode\n- `Space` - Play/Pause Audio (when player active)\n\n### Wiki-Links & Tags\nType `[[Lecture Notes]]` to link notes, or use `#ideas` and `#lecture` to tag notes!",
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            ),
            NoteItem(
                title: "Lecture Notes",
                folder: "General",
                content: "# Lecture Notes\n\nReferenced from [[Welcome to Native WhispNotes]] #lecture.\n\n- Diarized transcription audio synced automatically\n- High quality audio recording",
                timestamp: Date().addingTimeInterval(-3600),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
        ]
    }
}
