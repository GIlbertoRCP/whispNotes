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
    @StateObject private var updater = GitHubReleaseUpdater.shared
    @StateObject private var tabManager = TabNavigationManager.shared
    @Environment(\.undoManager) private var undoManager
    
    @State private var isRightPanelOpen = true
    @State private var isSidebarOpen = true
    @State private var isFocusMode = false
    @State private var isVaultSearchOpen = false
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
                if isFocusMode {
                    if let noteBinding = selectedNote {
                        ZenFocusTopBarView(
                            isFocusMode: $isFocusMode,
                            editMode: $editMode,
                            note: noteBinding.wrappedValue,
                            isDark: isDarkMode,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                } else {
                    // Multi-Tab Bar
                    NoteTabBarView(
                        tabManager: tabManager,
                        notes: $notes,
                        isDark: isDarkMode,
                        primaryAccent: primaryAccent,
                        secondaryAccent: secondaryAccent,
                        onNewTab: createNewNote
                    )

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
                }
                
                if let noteBinding = selectedNote {
                    HStack(spacing: 0) {
                        // Note text editor panel
                        EditorPanelView(
                            note: noteBinding,
                            notes: $notes,
                            selectedNoteId: $selectedNoteId,
                            playerVM: playerVM,
                            editMode: $editMode,
                            isFocusMode: isFocusMode,
                            isDark: isDarkMode,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
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
        .overlay(alignment: .top) {
            if let release = updater.latestRelease, case .updateAvailable = updater.status {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundColor(primaryAccent)
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("WhispNotes **\(release.tagName)** is available!")
                        .font(.caption)
                    
                    Button("View Update") {
                        updater.showUpdateModal = true
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(primaryAccent)
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: { updater.status = .idle }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.cardBackground(isDarkMode))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(primaryAccent.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
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
        .sheet(isPresented: $isVaultSearchOpen) {
            VaultSearchModalView(
                isOpen: $isVaultSearchOpen,
                notes: $notes,
                selectedNoteId: $selectedNoteId
            )
        }
        .sheet(isPresented: $updater.showUpdateModal) {
            AppUpdateModalView(updater: updater)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVaultSearch)) { _ in
            isVaultSearchOpen = true
        }
        .onChange(of: tabManager.activeTabId) { _, newActiveId in
            if let id = newActiveId, selectedNoteId != id {
                selectedNoteId = id
            }
        }
        .onChange(of: selectedNoteId) { _, newId in
            if let id = newId {
                if tabManager.activeTabId != id {
                    tabManager.openNote(id)
                }
                if let note = notes.first(where: { $0.id == id }) {
                    if note.pdfPath != nil {
                        editMode = .pdf
                    } else if editMode == .pdf {
                        editMode = .edit
                    }
                }
            }
        }
        .onAppear {
            NotesDataManager.shared.undoManager = undoManager
            if let id = selectedNoteId ?? notes.first?.id {
                tabManager.openNote(id)
                if let note = notes.first(where: { $0.id == id }), note.pdfPath != nil {
                    editMode = .pdf
                }
            }
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            }
            if updater.autoCheckForUpdates {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    updater.checkForUpdates(silent: true)
                }
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
        NotesDataManager.shared.saveNotes(notes)
        tabManager.openNote(newNote.id, inNewTab: true)
    }
}

// MARK: - Minimalist Zen Focus Top Bar
struct ZenFocusTopBarView: View {
    @Binding var isFocusMode: Bool
    @Binding var editMode: EditModeType
    let note: NoteItem
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Zen Mode Badge
            HStack(spacing: 5) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(primaryAccent)
                Text("ZEN FOCUS MODE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(primaryAccent)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(primaryAccent.opacity(0.12))
            .cornerRadius(6)
            
            Spacer()
            
            // Note Title
            HStack(spacing: 6) {
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Mode Selector & Exit Button
            HStack(spacing: 8) {
                Picker("", selection: $editMode) {
                    Text("Edit").tag(EditModeType.edit)
                    Text("Split").tag(EditModeType.split)
                    Text("Preview").tag(EditModeType.preview)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                
                Button(action: {
                    withAnimation(AppAnimation.panel) {
                        isFocusMode = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Exit Focus")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    .foregroundColor(.secondary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Exit Zen Focus Mode (⌘Shift+F or ESC)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(Color.sidebarBackground(isDark).opacity(0.85))
        .overlay(
            Rectangle()
                .fill(Color.subtleBorder(isDark))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
