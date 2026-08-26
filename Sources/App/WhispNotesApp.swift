import SwiftUI

// MARK: - Main SwiftUI Application Entry
public struct WhispNotesSwiftApp: App {
    @StateObject private var recorderVM = AudioRecorderViewModel()
    @StateObject private var playerVM = AudioPlayerViewModel()
    
    @State private var notes: [NoteItem] = NotesDataManager.shared.loadNotes()
    @State private var selectedNoteId: UUID? = NotesDataManager.shared.loadNotes().first?.id
    @State private var isCommandPaletteOpen = CommandLine.arguments.contains("--command-palette")
    @State private var isSettingsOpen = false
    @State private var isGraphViewOpen = false

    var activeSelectedNote: NoteItem? {
        guard let id = selectedNoteId else { return notes.first }
        return notes.first(where: { $0.id == id })
    }

    public init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public var body: some Scene {
        WindowGroup {
            ContentView(
                notes: $notes,
                selectedNoteId: $selectedNoteId,
                recorderVM: recorderVM,
                playerVM: playerVM,
                isCommandPaletteOpen: $isCommandPaletteOpen,
                isSettingsOpen: $isSettingsOpen,
                isGraphViewOpen: $isGraphViewOpen
            )
            .frame(minWidth: 1020, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    createNewNote()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Tab") {
                    createNewNote()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    if let active = TabNavigationManager.shared.activeTabId {
                        TabNavigationManager.shared.closeTab(active)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Today's Daily Note") {
                    openOrCreateDailyNote()
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Import Obsidian Vault (Folder)...") {
                    importObsidianVault()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Import PDF Document as Note...") {
                    importPDFAsNewNote()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Attach PDF to Current Note...") {
                    attachPDFToActiveNote()
                }

                Button("Import Lecture Audio File...") {
                    importAudioFile()
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Button("Find in Vault (Full-Text)...") {
                    NotificationCenter.default.post(name: .openVaultSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Quick Search Palette...") {
                    isCommandPaletteOpen = true
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Knowledge Graph Canvas...") {
                    isGraphViewOpen = true
                }
                .keyboardShortcut("g", modifiers: .command)

                Divider()

                Button("Save Vault") {
                    NotesDataManager.shared.saveNotesImmediately(notes)
                }
                .keyboardShortcut("s", modifiers: .command)

                Divider()

                Button("Check for Updates...") {
                    GitHubReleaseUpdater.shared.checkForUpdates(silent: false)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Button("Preferences...") {
                    isSettingsOpen = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NotesDataManager.shared.undoManager?.undo()
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NotesDataManager.shared.undoManager?.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    GitHubReleaseUpdater.shared.checkForUpdates(silent: false)
                }
            }

            CommandMenu("Navigate") {
                Button("Back") {
                    TabNavigationManager.shared.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    TabNavigationManager.shared.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)

                Divider()

                Button("Select Next Tab") {
                    TabNavigationManager.shared.nextTab()
                }
                .keyboardShortcut(.tab, modifiers: .control)

                Button("Select Previous Tab") {
                    TabNavigationManager.shared.previousTab()
                }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])

                Divider()

                ForEach(1...9, id: \.self) { i in
                    Button("Select Tab \(i)") {
                        TabNavigationManager.shared.selectTab(at: i - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(i)")), modifiers: .command)
                }
            }

            CommandMenu("Edit Note") {
                Button("Pin / Unpin Note") {
                    if let activeId = TabNavigationManager.shared.activeTabId,
                       let idx = notes.firstIndex(where: { $0.id == activeId }) {
                        notes[idx].isPinned.toggle()
                        NotesDataManager.shared.saveNotes(notes)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Paste Screenshot / Image") {
                    NotificationCenter.default.post(name: .pasteImageAsAttachment, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }

            CommandMenu("Export Note") {
                Button("Export as PDF Document...") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportPDF(current)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .option])

                Button("Export as Markdown (.md)...") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportMarkdown(current)
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export as HTML Web Page...") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportHTML(current)
                    }
                }

                Button("Export as Plain Text...") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportPlainText(current)
                    }
                }

                Divider()

                Button("Export Full Vault to Folder...") {
                    exportFullVault()
                }
            }

            CommandMenu("Audio Controls") {
                Button("Play / Pause") {
                    playerVM.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button("Rewind 5 Seconds") {
                    playerVM.rewind5Seconds()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                
                Button("Forward 5 Seconds") {
                    playerVM.forward5Seconds()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Divider()

                Button("Playback Speed: 1.0x") { playerVM.setSpeed(1.0) }
                Button("Playback Speed: 1.25x") { playerVM.setSpeed(1.25) }
                Button("Playback Speed: 1.5x") { playerVM.setSpeed(1.5) }
                Button("Playback Speed: 2.0x") { playerVM.setSpeed(2.0) }
            }
        }
    }
    
    private func createNewNote() {
        let newNote = NoteItem(
            title: "Untitled Note",
            folder: "General",
            content: "# Untitled Note\n\nType your notes here...",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        notes.insert(newNote, at: 0)
        selectedNoteId = newNote.id
        NotesDataManager.shared.saveNotes(notes)
    }

    private func openOrCreateDailyNote() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        if let existing = notes.first(where: { $0.folder == "Daily Notes" && $0.title == dateString }) {
            selectedNoteId = existing.id
        } else {
            let dailyNote = NoteItem(
                title: dateString,
                folder: "Daily Notes",
                content: "# Daily Journal — \(dateString)\n\n### Morning Intentions\n- [ ] Review lecture notes\n- [ ] Focus study goals\n\n### Notes & Reflections\nType daily notes here...\n",
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
            notes.insert(dailyNote, at: 0)
            selectedNoteId = dailyNote.id
            NotesDataManager.shared.saveNotes(notes)
        }
    }

    private func exportFullVault() {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Destination for Full Vault"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                NotesDataManager.shared.exportVaultToFolder(targetDir: url, notes: notes)
            }
        }
    }

    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Lecture Audio File"
        panel.allowedContentTypes = [.audio, .mp3, .wav, .mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let id = selectedNoteId, let idx = notes.firstIndex(where: { $0.id == id }) {
                    if let (relPath, safeURL) = NotesDataManager.shared.importAttachment(from: url, for: notes[idx].id) {
                        notes[idx].audioPath = relPath
                        notes[idx].isStandalone = false
                        NotesDataManager.shared.saveNotes(notes)
                        LocalSpeechTranscriber.transcribe(url: safeURL) { segments in
                            notes[idx].transcript = segments
                            NotesDataManager.shared.saveNotes(notes)
                            playerVM.loadAudio(url: safeURL, transcript: segments)
                        }
                    }
                }
            }
        }
    }

    private func importPDFAsNewNote() {
        let panel = NSOpenPanel()
        panel.title = "Import PDF Document as New Note"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let noteId = UUID()
                let title = (url.lastPathComponent as NSString).deletingPathExtension
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: noteId) {
                    let newNote = NoteItem(
                        id: noteId,
                        title: title,
                        folder: "General",
                        content: "# \(title)\n\nAttached Document: `\(url.lastPathComponent)`",
                        timestamp: Date(),
                        audioPath: nil,
                        transcript: [],
                        isStandalone: true,
                        bookmarks: [],
                        pdfPath: relPath
                    )
                    notes.insert(newNote, at: 0)
                    selectedNoteId = newNote.id
                    NotesDataManager.shared.saveNotes(notes)
                }
            }
        }
    }

    private func attachPDFToActiveNote() {
        guard let id = selectedNoteId, let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel()
        panel.title = "Attach PDF Document to Note"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: notes[idx].id) {
                    notes[idx].pdfPath = relPath
                    NotesDataManager.shared.saveNotes(notes)
                }
            }
        }
    }

    private func importObsidianVault() {
        let panel = NSOpenPanel()
        panel.title = "Select Obsidian Vault Folder to Import"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let imported = NotesDataManager.shared.importObsidianVault(from: url)
                if !imported.isEmpty {
                    notes.insert(contentsOf: imported, at: 0)
                    selectedNoteId = imported.first?.id
                    NotesDataManager.shared.saveNotesImmediately(notes)
                }
            }
        }
    }
}
