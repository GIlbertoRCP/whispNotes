import SwiftUI

// MARK: - Resizable Divider
struct ResizableDivider: View {
    @Binding var width: Double
    let minWidth: Double
    let maxWidth: Double
    let isLeading: Bool
    let isDark: Bool
    let primaryColor: Color

    @State private var initialWidth: Double? = nil
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? primaryColor.opacity(0.6) : Color.subtleBorder(isDark))
            .frame(width: 1)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if initialWidth == nil {
                            initialWidth = width
                        }
                        if let start = initialWidth {
                            let delta = isLeading ? Double(value.translation.width) : -Double(value.translation.width)
                            width = min(max(start + delta, minWidth), maxWidth)
                        }
                    }
                    .onEnded { _ in
                        initialWidth = nil
                    }
            )
    }
}

// MARK: - Main Content View (With Dynamic Themes & Zen Focus)
struct ContentView: View {
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    
    @ObservedObject var recorderVM: AudioRecorderViewModel
    @ObservedObject var playerVM: AudioPlayerViewModel
    @Binding var isCommandPaletteOpen: Bool
    @Binding var isSettingsOpen: Bool
    @Binding var isGraphViewOpen: Bool
    
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 280.0
    @AppStorage("rightPanelWidth") private var rightPanelWidth: Double = 380.0
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @AppStorage("colorTheme") private var colorTheme: String = "Midnight Rose"
    
    @State private var isRightPanelOpen = true
    @State private var isSidebarOpen = true
    @State private var isFocusMode = false
    @State private var editMode: EditModeType = .split

    var primaryAccent: Color {
        ThemeColors.primary(colorTheme, isDark: isDarkMode)
    }

    var secondaryAccent: Color {
        ThemeColors.secondary(colorTheme, isDark: isDarkMode)
    }
    
    var selectedNote: Binding<NoteItem>? {
        guard let id = selectedNoteId, let index = notes.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { notes[index] },
            set: {
                notes[index] = $0
                NotesDataManager.shared.saveNotes(notes)
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar List
            if !isFocusMode && isSidebarOpen {
                SidebarView(
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    width: $sidebarWidth,
                    isDark: isDarkMode,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    createNewNote: createNewNote
                )
                .frame(width: CGFloat(sidebarWidth))
                .transition(.move(edge: .leading))
                
                ResizableDivider(width: $sidebarWidth, minWidth: 200, maxWidth: 450, isLeading: true, isDark: isDarkMode, primaryColor: primaryAccent)
            }
            
            // Middle Main Editor Panel
            VStack(spacing: 0) {
                HeaderToolbarView(
                    isSidebarOpen: $isSidebarOpen,
                    isRightPanelOpen: $isRightPanelOpen,
                    isSettingsOpen: $isSettingsOpen,
                    isGraphViewOpen: $isGraphViewOpen,
                    isFocusMode: $isFocusMode,
                    editMode: $editMode,
                    isDark: isDarkMode,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    selectedNote: selectedNote,
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    recorderVM: recorderVM,
                    playerVM: playerVM,
                    onAudioTranscribed: { segments, path in
                        if let note = selectedNote {
                            note.wrappedValue.transcript = segments
                            note.wrappedValue.audioPath = path
                            note.wrappedValue.isStandalone = false
                            NotesDataManager.shared.saveNotes(notes)
                            let audioFileURL = URL(fileURLWithPath: path)
                            playerVM.loadAudio(url: audioFileURL, transcript: segments)
                        }
                    }
                )
                
                if let noteBinding = selectedNote {
                    HStack(spacing: 0) {
                        // Note text editor panel
                        EditorPanelView(
                            note: noteBinding,
                            notes: $notes,
                            selectedNoteId: $selectedNoteId,
                            playerVM: playerVM,
                            editMode: $editMode,
                            isDark: isDarkMode,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent
                        )
                        .frame(maxWidth: isFocusMode ? 820 : .infinity, maxHeight: .infinity)
                        
                        // Right Transcript panel
                        if !isFocusMode && isRightPanelOpen && !noteBinding.wrappedValue.isStandalone {
                            ResizableDivider(width: $rightPanelWidth, minWidth: 260, maxWidth: 550, isLeading: false, isDark: isDarkMode, primaryColor: primaryAccent)
                            
                            TranscriptPanelView(
                                note: noteBinding,
                                notes: $notes,
                                playerVM: playerVM,
                                width: $rightPanelWidth,
                                isDark: isDarkMode,
                                primaryAccent: primaryAccent,
                                secondaryAccent: secondaryAccent
                            )
                            .frame(width: CGFloat(rightPanelWidth))
                            .transition(.move(edge: .trailing))
                        }
                    }
                } else {
                    ContentUnavailableView("No Note Selected", systemImage: "doc.text.fill", description: Text("Select a note or press ⌘N to build a new draft."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Bottom Audio Player Bar
                if !isFocusMode, let noteBinding = selectedNote, let audioPath = noteBinding.wrappedValue.audioPath {
                    AudioPlayerBarView(
                        note: noteBinding,
                        notes: $notes,
                        playerVM: playerVM,
                        audioPath: audioPath,
                        isDark: isDarkMode,
                        primaryAccent: primaryAccent
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.panelBackground(isDarkMode))
        }
        .background(Color.appBackground(isDarkMode))
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $isCommandPaletteOpen) {
            CommandPaletteView(
                notes: notes,
                selectedNoteId: $selectedNoteId,
                isOpen: $isCommandPaletteOpen,
                isDark: isDarkMode,
                primaryAccent: primaryAccent
            )
        }
        .sheet(isPresented: $isSettingsOpen) {
            SettingsModalView(isOpen: $isSettingsOpen, notes: $notes)
        }
        .sheet(isPresented: $isGraphViewOpen) {
            GraphViewModal(
                notes: notes,
                selectedNoteId: $selectedNoteId,
                isOpen: $isGraphViewOpen,
                isDark: isDarkMode,
                primaryAccent: primaryAccent,
                secondaryAccent: secondaryAccent
            )
        }
        .onChange(of: selectedNoteId) { _, newId in
            if let id = newId, let note = notes.first(where: { $0.id == id }) {
                if note.pdfPath != nil {
                    editMode = .pdf
                } else if editMode == .pdf {
                    editMode = .edit
                }
            }
        }
        .onAppear {
            if let id = selectedNoteId, let note = notes.first(where: { $0.id == id }), note.pdfPath != nil {
                editMode = .pdf
            }
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
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
}
