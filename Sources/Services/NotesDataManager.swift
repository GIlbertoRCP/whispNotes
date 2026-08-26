import Foundation
import Combine
import PDFKit
import AppKit

extension Notification.Name {
    static let pasteImageAsAttachment = Notification.Name("pasteImageAsAttachment")
    static let notesRestoredFromUndo = Notification.Name("notesRestoredFromUndo")
    static let openTemplateModal = Notification.Name("openTemplateModal")
}

// MARK: - Data Manager (JSON Persistence, Rolling Backups & Vault Export)
class NotesDataManager: ObservableObject {
    static let shared = NotesDataManager()
    
    @Published var isSaving = false
    @Published var lastSavedAt: Date? = Date()
    
    /// Global UndoManager wired from the AppKit / SwiftUI environment
    public weak var undoManager: UndoManager?
    
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let ioQueue = DispatchQueue(label: "com.whispnotes.datamanager.io", qos: .userInitiated)
    
    /// Register a structural operation (Delete, Move, Rename, Pin, Restore) on the native undo stack
    func registerStructuralUndo(
        actionName: String,
        previousState: [NoteItem]
    ) {
        guard let undoManager = self.undoManager else { return }
        let snapshot = previousState
        undoManager.registerUndo(withTarget: self) { target in
            target.saveNotes(snapshot, debounce: false)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notesRestoredFromUndo, object: snapshot)
            }
        }
        undoManager.setActionName(actionName)
    }
    
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
            var loadedNotes: [NoteItem]
            if let data = try? Data(contentsOf: fileURL), let notes = try? decoder.decode([NoteItem].self, from: data) {
                loadedNotes = notes
            } else if let recoveredNotes = recoverFromLatestBackup() {
                loadedNotes = recoveredNotes
            } else {
                loadedNotes = getSeedNotes()
            }
            
            // Migrate and secure any external attachment paths so they are never lost
            if migrateAndSecureNotes(&loadedNotes) {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(loadedNotes) {
                    try? data.write(to: fileURL, options: .atomic)
                }
            }
            
            return loadedNotes
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
    
    // MARK: - Attachment & File Sandbox Management
    /// Securely imports any external file (PDF, audio, etc.) into the app's persistent Attachments sandbox.
    func importAttachment(from sourceURL: URL, for noteId: UUID, preferredFileName: String? = nil) -> (relativePath: String, fullURL: URL)? {
        let fileManager = FileManager.default
        let safeDir = attachmentsDir
        
        let originalName = preferredFileName ?? sourceURL.lastPathComponent
        let sanitizedOriginal = originalName.replacingOccurrences(of: " ", with: "_").filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }
        let fileName = "\(noteId.uuidString.prefix(8))_\(sanitizedOriginal.isEmpty ? "document.pdf" : sanitizedOriginal)"
        let destinationURL = safeDir.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return (relativePath: fileName, fullURL: destinationURL)
        } catch {
            print("Error importing attachment into sandbox: \(error)")
            // Fallback: try data write
            if let data = try? Data(contentsOf: sourceURL) {
                try? data.write(to: destinationURL, options: .atomic)
                return (relativePath: fileName, fullURL: destinationURL)
            }
            return nil
        }
    }

    /// Saves an NSImage to the vault attachments directory as PNG and returns markdown reference tag.
    func saveImageAttachment(image: NSImage, originalFilename: String? = nil, for noteId: UUID) -> (relativePath: String, fullURL: URL, markdown: String)? {
        // Try getting PNG data via CGImage first
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                return saveImageDataAttachment(data: pngData, originalFilename: originalFilename, for: noteId)
            }
        }
        // Fallback to TIFF representation
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return saveImageDataAttachment(data: pngData, originalFilename: originalFilename, for: noteId)
        }
        return nil
    }

    /// Saves raw image data into the persistent vault attachments folder.
    func saveImageDataAttachment(data: Data, originalFilename: String? = nil, for noteId: UUID) -> (relativePath: String, fullURL: URL, markdown: String)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let baseName = originalFilename ?? "pasted_image_\(timestamp)"
        let sanitized = (baseName as NSString).deletingPathExtension.replacingOccurrences(of: " ", with: "_").filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let fileName = "\(noteId.uuidString.prefix(8))_\(sanitized.isEmpty ? "image" : sanitized).png"
        let destinationURL = attachmentsDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: destinationURL, options: .atomic)
            let markdown = "![Pasted image \(timestamp)](attachment:\(fileName))"
            return (relativePath: fileName, fullURL: destinationURL, markdown: markdown)
        } catch {
            print("Failed to save image attachment: \(error)")
            return nil
        }
    }

    /// Inspects NSPasteboard.general for screenshots, copied images, or image files, saves to vault, and returns markdown.
    func saveClipboardImage(for noteId: UUID) -> (relativePath: String, fullURL: URL, markdown: String)? {
        let pasteboard = NSPasteboard.general

        // 1. Check for raw PNG data directly on clipboard (e.g. from macOS ⌘⌃⇧4 screenshot)
        if let pngData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.png")) {
            return saveImageDataAttachment(data: pngData, originalFilename: nil, for: noteId)
        }

        // 2. Check for TIFF data
        if let tiffData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.tiff")) {
            if let bitmap = NSBitmapImageRep(data: tiffData), let pngData = bitmap.representation(using: .png, properties: [:]) {
                return saveImageDataAttachment(data: pngData, originalFilename: nil, for: noteId)
            }
        }

        // 3. Check for JPEG data
        if let jpegData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
            return saveImageDataAttachment(data: jpegData, originalFilename: nil, for: noteId)
        }

        // 4. Check for direct NSImage objects
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let firstImg = images.first {
            return saveImageAttachment(image: firstImg, originalFilename: nil, for: noteId)
        }

        if let img = NSImage(pasteboard: pasteboard) {
            return saveImageAttachment(image: img, originalFilename: nil, for: noteId)
        }
        
        // 5. File URLs on pasteboard (e.g. copied image file from Finder)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic"]
            for fileURL in urls {
                if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                    if let data = try? Data(contentsOf: fileURL) {
                        return saveImageDataAttachment(data: data, originalFilename: fileURL.lastPathComponent, for: noteId)
                    }
                }
            }
        }
        
        return nil
    }

    /// Resolves an attachment filename or legacy path into a valid, secure URL within the persistent sandbox.
    func resolveAttachmentURL(_ pathOrName: String?) -> URL? {
        guard let raw = pathOrName, !raw.isEmpty else { return nil }
        let clean = raw.replacingOccurrences(of: "attachment://", with: "")
                       .replacingOccurrences(of: "attachment:", with: "")
                       .replacingOccurrences(of: "file://", with: "")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileManager = FileManager.default
        
        // 1. Direct match in persistent Attachments folder
        let inAttachments = attachmentsDir.appendingPathComponent(clean)
        if fileManager.fileExists(atPath: inAttachments.path) {
            return inAttachments
        }
        
        // 2. Strip any directory components and check if just the filename exists in Attachments
        let fileNameOnly = (clean as NSString).lastPathComponent
        let strippedInAttachments = attachmentsDir.appendingPathComponent(fileNameOnly)
        if fileManager.fileExists(atPath: strippedInAttachments.path) {
            return strippedInAttachments
        }
        
        // 3. Check if absolute path exists on disk (legacy path) -> auto-migrate into Attachments!
        let directURL = URL(fileURLWithPath: clean)
        if fileManager.fileExists(atPath: directURL.path) {
            let targetURL = attachmentsDir.appendingPathComponent(fileNameOnly)
            if !fileManager.fileExists(atPath: targetURL.path) {
                try? fileManager.copyItem(at: directURL, to: targetURL)
            }
            return fileManager.fileExists(atPath: targetURL.path) ? targetURL : directURL
        }
        
        return nil
    }

    /// Automatically scans all notes and secures external paths into sandbox storage so files are never lost.
    func migrateAndSecureNotes(_ notes: inout [NoteItem]) -> Bool {
        var modified = false
        let fileManager = FileManager.default
        
        for i in 0..<notes.count {
            // Secure Audio Path
            if let audio = notes[i].audioPath, !audio.isEmpty {
                let audioURL = URL(fileURLWithPath: audio)
                if !audio.contains(attachmentsDir.path) && fileManager.fileExists(atPath: audioURL.path) {
                    if let (rel, _) = importAttachment(from: audioURL, for: notes[i].id) {
                        notes[i].audioPath = rel
                        modified = true
                    }
                }
            }
            
            // Secure PDF Path
            if let pdf = notes[i].pdfPath, !pdf.isEmpty {
                let pdfURL = URL(fileURLWithPath: pdf)
                if !pdf.contains(attachmentsDir.path) && fileManager.fileExists(atPath: pdfURL.path) {
                    if let (rel, _) = importAttachment(from: pdfURL, for: notes[i].id) {
                        notes[i].pdfPath = rel
                        modified = true
                    }
                }
            }
        }
        return modified
    }

    /// Extracts plain text from a PDF document safely with maxPages limit and memory autoreleasepool.
    func extractTextFromPDF(url: URL, maxPages: Int = 10) -> String? {
        let document = PDFDocumentCache.shared.cachedDocument(for: url) ?? PDFDocument(url: url)
        guard let doc = document else { return nil }
        var fullText = ""
        let totalPages = doc.pageCount
        let limit = min(totalPages, maxPages)
        
        for i in 0..<limit {
            autoreleasepool {
                if let page = doc.page(at: i), let pageString = page.string {
                    fullText += "--- Page \(i + 1) ---\n" + pageString + "\n\n"
                }
            }
        }
        
        if totalPages > limit {
            fullText += "\n[... Document continues for \(totalPages - limit) more pages ...]\n"
        }
        
        let clean = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    /// Asynchronously extracts text from large PDF documents without blocking the main UI thread.
    func extractFullTextFromPDFAsync(url: URL, maxPages: Int = 50, progressHandler: ((Double) -> Void)? = nil) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let document = PDFDocument(url: url) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var fullText = ""
                let totalPages = document.pageCount
                let limit = min(totalPages, maxPages)
                
                for i in 0..<limit {
                    autoreleasepool {
                        if let page = document.page(at: i), let pageString = page.string {
                            fullText += "--- Page \(i + 1) of \(totalPages) ---\n" + pageString + "\n\n"
                        }
                    }
                    if let progress = progressHandler {
                        DispatchQueue.main.async {
                            progress(Double(i + 1) / Double(limit))
                        }
                    }
                }
                
                if totalPages > limit {
                    fullText += "\n[... Document contains \(totalPages) total pages. First \(limit) pages extracted ...]\n"
                }
                
                let clean = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: clean.isEmpty ? nil : clean)
            }
        }
    }

    // MARK: - Full Vault Export
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

    // MARK: - Full Vault Export & Obsidian Import
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

    /// Recursively imports an entire Obsidian vault directory of markdown files and folders.
    func importObsidianVault(from folderURL: URL) -> [NoteItem] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        var importedNotes: [NoteItem] = []
        let basePathLength = folderURL.path.count
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" || fileURL.pathExtension.lowercased() == "markdown" else {
                continue
            }
            
            // Determine relative folder name
            let parentDir = fileURL.deletingLastPathComponent()
            var folderName = "General"
            if parentDir.path.count > basePathLength {
                let relativeSubpath = String(parentDir.path.dropFirst(basePathLength))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if !relativeSubpath.isEmpty && !relativeSubpath.hasPrefix(".obsidian") {
                    folderName = relativeSubpath
                }
            }
            
            guard let rawContent = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            
            // Clean frontmatter if present
            var content = rawContent
            var title = (fileURL.lastPathComponent as NSString).deletingPathExtension
            
            if content.hasPrefix("---") {
                let components = content.components(separatedBy: "---")
                if components.count >= 3 {
                    let frontmatter = components[1]
                    content = components.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Try to parse title from frontmatter
                    for line in frontmatter.components(separatedBy: "\n") {
                        if line.lowercased().hasPrefix("title:") {
                            let parsed = line.dropFirst(6).trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                            if !parsed.isEmpty { title = parsed }
                        }
                    }
                }
            }
            
            let note = NoteItem(
                id: UUID(),
                title: title,
                folder: folderName,
                content: content,
                timestamp: (try? fileURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
            importedNotes.append(note)
        }
        
        return importedNotes
    }
    
    private func getSeedNotes() -> [NoteItem] {
        return [
            NoteItem(
                title: "Welcome to WhispNotes",
                folder: "General",
                content: """
                # 🚀 Welcome to WhispNotes

                WhispNotes is a **100% private, on-device intelligence workspace** designed for researchers, engineers, and students. Everything runs natively on Apple Silicon with **zero cloud dependencies** or background web servers.

                ---

                ## 🧠 Interactive Mermaid.js Architecture Diagrams
                WhispNotes automatically renders live vector diagrams directly from markdown:

                ```mermaid
                flowchart LR
                    Audio[🎙️ Lecture Audio] --> Whisper[Local Whisper AI]
                    PDF[📄 PDF Attachment] --> Reader[Native PDFKit]
                    Whisper --> Sync[Diarized Sync Engine]
                    Reader --> Graph[Obsidian Knowledge Graph]
                    Sync --> Vault[(Encrypted Local Vault)]
                    Graph --> Vault
                ```

                ---

                ## 📐 Native KaTeX LaTeX Math Rendering
                Write inline math like $E = mc^2$ or full display equations with live LaTeX typesetting:

                $$
                f(x) = \\int_{-\\infty}^{\\infty} \\hat{f}(\\xi) e^{2 \\pi i \\xi x} d\\xi
                $$

                $$
                \\nabla \\times \\mathbf{B} = \\mu_0 \\mathbf{J} + \\mu_0 \\epsilon_0 \\frac{\\partial \\mathbf{E}}{\\partial t}
                $$

                ---

                ## ⚡ Key Shortcuts & Features
                - **`⌘N`** — Create New Note
                - **`⌘T`** — New Note from Template (Meeting, Cornell, RFC, Podcast)
                - **`⌘K` / `⌘O`** — Fuzzy Vault Spotlight Search
                - **`⌘G`** — Obsidian Knowledge Graph Canvas
                - **`⌘⇧F`** — Zen Focus Mode
                - **`⌘[` / `⌘]`** — History Navigation
                - **`⌘,`** — Preferences & Color Themes

                ---

                ## 🔗 Knowledge Connections & Backlinks
                Connect ideas effortlessly using wiki-links: check out [[Lecture Notes]] and [[Technical Architecture]].
                Use hashtags like `#research`, `#ai`, and `#engineering` to organize topics across folders.
                """,
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            ),
            NoteItem(
                title: "Lecture Notes",
                folder: "Lectures",
                content: """
                # 🎓 Advanced Algorithms & Systems
                
                Connected to [[Welcome to WhispNotes]] and [[Technical Architecture]].
                
                ## 📝 Core Concepts
                - Dynamic Programming & Memoization
                - Graph Traversal (BFS / DFS / Dijkstra)
                - Local Speech Recognition & Diarization
                
                ### Complexity Analysis
                $$
                T(n) = 2 T\\left(\\frac{n}{2}\\right) + \\mathcal{O}(n) \\implies \\mathcal{O}(n \\log n)
                $$
                """,
                timestamp: Date().addingTimeInterval(-3600),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            ),
            NoteItem(
                title: "Technical Architecture",
                folder: "Engineering",
                content: """
                # 🏗️ Technical Architecture
                
                Referenced from [[Welcome to WhispNotes]].
                
                ```mermaid
                classDiagram
                    class NoteItem {
                        +UUID id
                        +String title
                        +String content
                        +String folder
                        +Date timestamp
                    }
                    class NotesDataManager {
                        +saveNotes()
                        +loadNotes()
                    }
                    NotesDataManager --> NoteItem
                ```
                """,
                timestamp: Date().addingTimeInterval(-7200),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
        ]
    }
}
