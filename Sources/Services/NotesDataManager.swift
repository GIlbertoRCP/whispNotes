import Foundation

// MARK: - Data Manager (JSON Persistence)
class NotesDataManager {
    static let shared = NotesDataManager()
    private var pendingSaveWorkItem: DispatchWorkItem?
    
    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("com.whispnotes.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }

    func loadNotes() -> [NoteItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return getSeedNotes() }
        let decoder = JSONDecoder()
        return (try? decoder.decode([NoteItem].self, from: data)) ?? getSeedNotes()
    }

    func saveNotes(_ notes: [NoteItem], debounce: Bool = true) {
        pendingSaveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(notes) {
                try? data.write(to: self.fileURL, options: .atomic)
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
    
    private func getSeedNotes() -> [NoteItem] {
        return [
            NoteItem(
                title: "Welcome to Native WhispNotes",
                folder: "General",
                content: "# Pure Native SwiftUI\n\nThis application runs 100% native on macOS with **zero background HTTP servers** or external API ports.\n\n### Markdown Table Example\n| Feature | Status | Quality |\n| --- | --- | --- |\n| Wiki Links | Active | 100% |\n| Diarization | Active | Native |\n\n### Code Block Example\n```swift\nfunc helloWorld() {\n    print(\"Hello WhispNotes!\")\n}\n```\n\n### Key Shortcuts\n- `⌘N` - New Standalone Note\n- `⌘K` or `⌘O` - Spotlight Search Palette\n- `⌘G` - Obsidian Knowledge Graph Canvas\n- `⌘⇧F` - Zen Focus Mode\n- `Space` - Play/Pause Audio (when player active)\n\n### Wiki-Links & Tags\nType `[[Lecture Notes]]` to link notes, or use `#ideas` and `#lecture` to tag notes!",
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
