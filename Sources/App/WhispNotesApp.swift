import SwiftUI

// MARK: - Main SwiftUI Application Entry
@main
struct WhispNotesSwiftApp: App {
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

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
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

                Button("Today's Daily Note") {
                    openOrCreateDailyNote()
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Import Lecture Audio File...") {
                    importAudioFile()
                }
                .keyboardShortcut("i", modifiers: .command)
                
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

                Button("Preferences...") {
                    isSettingsOpen = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Export Note") {
                Button("Export as PDF Document...") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportPDF(current)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

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
                LocalSpeechTranscriber.transcribe(url: url) { segments in
                    if let id = selectedNoteId, let idx = notes.firstIndex(where: { $0.id == id }) {
                        notes[idx].transcript = segments
                        notes[idx].audioPath = url.path
                        notes[idx].isStandalone = false
                        NotesDataManager.shared.saveNotes(notes)
                        playerVM.loadAudio(url: url, transcript: segments)
                    }
                }
            }
        }
    }
}
