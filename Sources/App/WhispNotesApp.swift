import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main SwiftUI Application Entry
public struct WhispNotesSwiftApp: App {
    @StateObject private var recorderVM = AudioRecorderViewModel()
    @StateObject private var playerVM = AudioPlayerViewModel()
    
    @State private var notes: [NoteItem] = NotesDataManager.shared.loadNotes()
    @State private var selectedNoteId: UUID? = NotesDataManager.shared.loadNotes().first?.id
    @State private var isCommandPaletteOpen = CommandLine.arguments.contains("--command-palette")
    @State private var isSettingsOpen = false
    @State private var isGraphViewOpen = false
    @AppStorage(QuickRecordPreferenceKey.showInMenuBar) private var showQuickRecordInMenuBar = true
    @AppStorage(QuickRecordPreferenceKey.globalShortcut) private var quickRecordShortcutEnabled = true

    var activeSelectedNote: NoteItem? {
        guard let id = selectedNoteId else { return notes.first }
        return notes.first(where: { $0.id == id })
    }

    public init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Auto-migrate to the new default "Classic Minimal" theme if previously on the old default "Midnight Rose" or unmigrated
        let migrationKey = "hasMigratedToClassicMinimal_v140"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            let current = UserDefaults.standard.string(forKey: "colorTheme")
            if current == nil || current == "Midnight Rose" || current == "Default" {
                UserDefaults.standard.set("Classic Minimal", forKey: "colorTheme")
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }

    public var body: some Scene {
        WindowGroup(id: "main") {
            ZoomContainerView {
                ContentView(
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    recorderVM: recorderVM,
                    playerVM: playerVM,
                    isCommandPaletteOpen: $isCommandPaletteOpen,
                    isSettingsOpen: $isSettingsOpen,
                    isGraphViewOpen: $isGraphViewOpen
                )
            }
            // Small enough to tile beside a meeting app on a laptop; the layout adapts below ~1000pt.
            .frame(minWidth: 720, minHeight: 520)
            .onAppear { configureRecording() }
            .onChange(of: quickRecordShortcutEnabled) { _, _ in configureGlobalShortcut() }
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

                Button("Calendar & Daily Journal Hub…") {
                    NotificationCenter.default.post(name: .openCalendarHub, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])

                Button("Import Obsidian Vault (Folder)…") {
                    importObsidianVault()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Import PDF or Presentation (.pptx) as Note…") {
                    importDocumentAsNewNote()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Attach PDF or Presentation to Current Note…") {
                    attachDocumentToActiveNote()
                }

                // ⇧⌘I: plain ⌘I is Italic in the editor.
                Button("Import Lecture Audio File…") {
                    importAudioFile()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Button("Find in Vault (Full-Text)…") {
                    NotificationCenter.default.post(name: .openVaultSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Quick Search Palette…") {
                    isCommandPaletteOpen = true
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Knowledge Graph…") {
                    isGraphViewOpen = true
                }
                .keyboardShortcut("g", modifiers: .command)

                Divider()

                Button("Save Vault") {
                    NotesDataManager.shared.saveNotesImmediately(notes)
                }
                .keyboardShortcut("s", modifiers: .command)

                Divider()

                Button("Check for Updates…") {
                    GitHubReleaseUpdater.shared.checkForUpdates(silent: false)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Button("Settings…") {
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
                Button("Check for Updates…") {
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

            CommandMenu("View") {
                Button("Zoom In") {
                    ZoomManager.shared.zoomIn()
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Zoom In (Shift)") {
                    ZoomManager.shared.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    ZoomManager.shared.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size (Reset Zoom)") {
                    ZoomManager.shared.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                // ⇧⌘D: ⇧⌘F is Find in Vault.
                Button("Toggle Focus Mode") {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleZenFocusMode"), object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
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

                Button("Paste Raw Plain Text") {
                    // Standard responder-chain action, handled by the focused text view.
                    NSApp.sendAction(#selector(NSTextView.pasteAsPlainText(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .option, .shift])

                Divider()

                Button("Format & Beautify Note") {
                    NotificationCenter.default.post(name: NSNotification.Name("SmartFormatNoteRequested"), object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
            }

            CommandMenu("Export Note") {
                Button("Export Note…") {
                    NotificationCenter.default.post(name: .openExportModal, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command])

                Divider()

                Button("Export as PDF Document…") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportPDF(current)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .option])

                Button("Export as Markdown (.md)…") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportMarkdown(current)
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export as HTML Web Page…") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportHTML(current)
                    }
                }

                Button("Export as Plain Text…") {
                    if let current = activeSelectedNote {
                        NoteExporter.shared.exportPlainText(current)
                    }
                }

                Divider()

                Button("Export Full Vault to Folder…") {
                    exportFullVault()
                }
            }

            CommandMenu("Playback") {
                Button(recorderVM.isRecording ? "Stop Recording" : "Record Into This Note") {
                    if recorderVM.isRecording {
                        recorderVM.finishRecording()
                    } else if let id = activeSelectedNote?.id {
                        recorderVM.startRecording(for: id)
                    }
                }
                .disabled(!recorderVM.isRecording && !(activeSelectedNote.map { $0.isStandalone && !recorderVM.transcribingNoteIds.contains($0.id) } ?? false))
                Button("Record Into New Note") { recordIntoNewNote() }
                    .disabled(recorderVM.isRecording)

                Divider()

                // Disabled without audio so these never swallow keystrokes. ⌥⌘ arrows because
                // ⌘← / ⌘→ move to the start / end of the line in the editor.
                Button(playerVM.isPlaying ? "Pause" : "Play") {
                    playerVM.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(playerVM.duration <= 0)

                Button("Back 5 Seconds") {
                    playerVM.rewind5Seconds()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .disabled(playerVM.duration <= 0)

                Button("Forward 5 Seconds") {
                    playerVM.forward5Seconds()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .disabled(playerVM.duration <= 0)

                Divider()

                Picker("Speed", selection: Binding(get: { playerVM.playbackSpeed }, set: { playerVM.setSpeed($0) })) {
                    ForEach([1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        Text(AudioPlayerBarView.speedLabel(speed)).tag(speed)
                    }
                }
                .disabled(playerVM.duration <= 0)
            }
        }

        // Quick Record: start or stop a recording without bringing the window forward.
        MenuBarExtra(isInserted: $showQuickRecordInMenuBar) {
            QuickRecordMenu(
                recorder: recorderVM,
                currentNote: activeSelectedNote,
                recordingNoteTitle: recorderVM.recordingNoteId.flatMap { id in notes.first { $0.id == id }?.title },
                onRecordIntoCurrent: { if let id = activeSelectedNote?.id { recorderVM.startRecording(for: id) } },
                onRecordIntoNew: recordIntoNewNote,
                onStop: { recorderVM.finishRecording() }
            )
        } label: {
            QuickRecordMenuBarLabel(recorder: recorderVM)
        }
    }
    
    // MARK: - Recording

    /// Wires the recorder's completion and the global shortcut. Every entry point files recordings here.
    private func configureRecording() {
        recorderVM.onRecordingFinished = { noteId, segments, audioFileName in
            applyRecording(noteId: noteId, segments: segments, audioFileName: audioFileName)
        }
        GlobalHotKey.shared.onPress = { quickRecordToggle() }
        configureGlobalShortcut()
    }

    private func configureGlobalShortcut() {
        if quickRecordShortcutEnabled { GlobalHotKey.shared.register() } else { GlobalHotKey.shared.unregister() }
    }

    /// ⌃⌥⌘R. Stops a running recording; otherwise records into the open note when WhispNotes is in front
    /// and that note has no recording yet, and into a new note from anywhere else.
    private func quickRecordToggle() {
        if recorderVM.isRecording {
            recorderVM.finishRecording()
        } else if NSApp.isActive, let note = activeSelectedNote, note.isStandalone, note.folder != "Trash",
                  !recorderVM.transcribingNoteIds.contains(note.id) {
            recorderVM.startRecording(for: note.id)
        } else {
            recordIntoNewNote()
        }
    }

    private func recordIntoNewNote() {
        let started = Date()
        let note = NoteItem(
            title: "Recording \(started.formatted(.dateTime.month(.abbreviated).day().hour().minute()))",
            folder: "General",
            content: "",
            timestamp: started,
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        notes.insert(note, at: 0)
        NotesDataManager.shared.saveNotes(notes)
        selectedNoteId = note.id
        TabNavigationManager.shared.openNote(note.id, inNewTab: true)
        recorderVM.startRecording(for: note.id)
    }

    /// Attaches a finished recording to the note it was started in, found by id (never by position or selection).
    private func applyRecording(noteId: UUID, segments: [TranscriptSegment], audioFileName: String) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[idx].audioPath = audioFileName
        notes[idx].transcript = segments
        notes[idx].isStandalone = false
        NotesDataManager.shared.saveNotes(notes)
        if selectedNoteId == noteId, let url = NotesDataManager.shared.resolveAttachmentURL(audioFileName) {
            playerVM.loadAudio(url: url, transcript: segments)
        }
    }

    private func createNewNote() {
        let newNote = NoteItem(
            title: "Untitled Note",
            folder: "General",
            content: "",
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
                if let id = selectedNoteId, notes.contains(where: { $0.id == id }),
                   let (relPath, safeURL) = NotesDataManager.shared.importAttachment(from: url, for: id) {
                    LocalSpeechTranscriber.transcribe(url: safeURL) { segments in
                        // Looked up by id after transcription: the notes array may have changed meanwhile.
                        applyRecording(noteId: id, segments: segments, audioFileName: relPath)
                    }
                }
            }
        }
    }

    private func importDocumentAsNewNote() {
        let panel = NSOpenPanel()
        panel.title = "Import PDF or Presentation (.pptx) as New Note"
        var contentTypes: [UTType] = [.pdf]
        if let pptxType = UTType(filenameExtension: "pptx") {
            contentTypes.append(pptxType)
        }
        if let pptxTypeOrg = UTType("org.openxmlformats.presentationml.presentation") {
            contentTypes.append(pptxTypeOrg)
        }
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let noteId = UUID()
                let title = (url.lastPathComponent as NSString).deletingPathExtension
                let ext = url.pathExtension.lowercased()
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: noteId) {
                    let newNote = NoteItem(
                        id: noteId,
                        title: title,
                        folder: "General",
                        content: "# \(title)\n\nAttached \(ext == "pptx" ? "Presentation" : "Document"): `\(url.lastPathComponent)`",
                        timestamp: Date(),
                        audioPath: nil,
                        transcript: [],
                        isStandalone: true,
                        bookmarks: [],
                        pdfPath: ext == "pdf" ? relPath : nil,
                        pptxPath: ext == "pptx" ? relPath : nil
                    )
                    notes.insert(newNote, at: 0)
                    selectedNoteId = newNote.id
                    NotesDataManager.shared.saveNotes(notes)
                }
            }
        }
    }

    private func attachDocumentToActiveNote() {
        guard let id = selectedNoteId, let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel()
        panel.title = "Attach PDF or Presentation (.pptx) to Note"
        var contentTypes: [UTType] = [.pdf]
        if let pptxType = UTType(filenameExtension: "pptx") {
            contentTypes.append(pptxType)
        }
        if let pptxTypeOrg = UTType("org.openxmlformats.presentationml.presentation") {
            contentTypes.append(pptxTypeOrg)
        }
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let ext = url.pathExtension.lowercased()
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: notes[idx].id) {
                    if ext == "pptx" {
                        notes[idx].pptxPath = relPath
                    } else {
                        notes[idx].pdfPath = relPath
                    }
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
