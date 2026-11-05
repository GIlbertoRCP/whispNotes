import SwiftUI

// MARK: - Resizable Divider
struct ResizableDivider: View {
    @Binding var width: Double
    let minWidth: Double
    let maxWidth: Double
    let isLeading: Bool
    let isDark: Bool
    let primaryColor: Color

    @State private var startLocationX: CGFloat? = nil
    @State private var startWidth: Double? = nil
    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isDragging || isHovering ? primaryColor.opacity(0.85) : Color.subtleBorder(isDark))
                .frame(width: 1)
        }
        .frame(width: 9)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if !isDragging {
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if startLocationX == nil {
                        startLocationX = value.startLocation.x
                        startWidth = width
                        isDragging = true
                    }
                    if let startX = startLocationX, let initialW = startWidth {
                        let delta = isLeading ? Double(value.location.x - startX) : Double(startX - value.location.x)
                        let newW = min(max(initialW + delta, minWidth), maxWidth)
                        if width != newW {
                            width = newW
                        }
                    }
                }
                .onEnded { _ in
                    startLocationX = nil
                    startWidth = nil
                    if isDragging {
                        isDragging = false
                        if !isHovering {
                            NSCursor.pop()
                        }
                    }
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
    
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 220.0
    @AppStorage("rightPanelWidth") private var rightPanelWidth: Double = 380.0
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @AppStorage("colorTheme") private var colorTheme: String = "Classic Minimal"
    @StateObject private var updater = GitHubReleaseUpdater.shared
    @StateObject private var tabManager = TabNavigationManager.shared
    @Environment(\.undoManager) private var undoManager
    
    @State private var isRightPanelOpen = true
    @State private var isSidebarOpen = true
    @State private var isFocusMode = false
    @State private var isVaultSearchOpen = false
    @State private var isTemplateModalOpen = false
    @State private var isCalendarOpen = false
    @State private var isExportModalOpen = false
    @State private var editMode: EditModeType = .split
    @AppStorage(EditorPreferenceKey.defaultViewMode) private var defaultViewModeRaw: String = EditModeType.split.rawValue

    /// The mode a note opens in: its attachment viewer if it has one, otherwise Settings › Editor › Default View.
    /// Empty notes open in Edit so there's somewhere to type.
    private func openingMode(for note: NoteItem) -> EditModeType {
        if note.pptxPath != nil { return .pptx }
        if note.pdfPath != nil { return .pdf }
        let preferred = EditModeType(rawValue: defaultViewModeRaw) ?? .split
        if preferred == .preview && note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .edit }
        return [.edit, .split, .preview].contains(preferred) ? preferred : .split
    }
    /// Panels the layout closed because the window got too narrow; they reopen once there's room again.
    @State private var sidebarAutoClosed = false
    @State private var transcriptAutoClosed = false

    // MARK: Responsive layout
    // Widths in points *after* GUI zoom (ZoomContainerView hands us the scaled size).
    private static let dividerWidth: CGFloat = 9
    private static let minEditorWidth: CGFloat = 420
    private static let minTranscriptWidth: CGFloat = 260
    private static let minSidebarWidth: CGFloat = 190
    /// Below this the sidebar closes itself so the note keeps a usable column.
    private static let sidebarCollapseWidth: CGFloat = 700

    private struct PanelLayout {
        var sidebar: CGFloat
        var transcript: CGFloat
        /// The transcript fits beside the editor; otherwise it floats over the editor's trailing edge.
        var transcriptInline: Bool
    }

    private func panelLayout(for width: CGFloat, sidebarShown: Bool) -> PanelLayout {
        let sidebar = sidebarShown ? min(CGFloat(sidebarWidth), max(Self.minSidebarWidth, width * 0.3)) : 0
        let middle = width - sidebar - (sidebarShown ? Self.dividerWidth : 0)
        let roomForTranscript = middle - Self.minEditorWidth - Self.dividerWidth
        let inline = roomForTranscript >= Self.minTranscriptWidth
        let transcript = inline
            ? min(CGFloat(rightPanelWidth), roomForTranscript)
            : min(CGFloat(rightPanelWidth), max(Self.minTranscriptWidth, middle * 0.85))
        return PanelLayout(sidebar: sidebar, transcript: transcript, transcriptInline: inline)
    }

    /// Closes panels that no longer fit and restores the ones the layout closed earlier.
    private func adaptPanels(to width: CGFloat) {
        if width < Self.sidebarCollapseWidth {
            if isSidebarOpen && !isFocusMode {
                sidebarAutoClosed = true
                withAnimation(AppAnimation.panel) { isSidebarOpen = false }
            }
        } else if sidebarAutoClosed {
            sidebarAutoClosed = false
            withAnimation(AppAnimation.panel) { isSidebarOpen = true }
        }

        let inline = panelLayout(for: width, sidebarShown: isSidebarOpen && !isFocusMode).transcriptInline
        if !inline {
            if isRightPanelOpen {
                transcriptAutoClosed = true
                withAnimation(AppAnimation.panel) { isRightPanelOpen = false }
            }
        } else if transcriptAutoClosed {
            transcriptAutoClosed = false
            withAnimation(AppAnimation.panel) { isRightPanelOpen = true }
        }
    }

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
        chrome(
            GeometryReader { geo in
                mainLayout(width: geo.size.width)
                    .onAppear { adaptPanels(to: geo.size.width) }
                    .onChange(of: geo.size.width) { _, newWidth in adaptPanels(to: newWidth) }
            }
            .background(Color.appBackground(isDarkMode))
            .preferredColorScheme(isDarkMode ? .dark : .light)
        )
    }

    @ViewBuilder
    private func mainLayout(width: CGFloat) -> some View {
        let layout = panelLayout(for: width, sidebarShown: !isFocusMode && isSidebarOpen)
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
                .frame(width: layout.sidebar)
                .transition(.move(edge: .leading))
                
                ResizableDivider(width: $sidebarWidth, minWidth: Double(Self.minSidebarWidth), maxWidth: 450, isLeading: true, isDark: isDarkMode, primaryColor: primaryAccent)
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
                        isSidebarOpen: isSidebarOpen,
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
                        playerVM: playerVM
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
                        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .trailing) {
                            // Narrow window: the transcript floats over the editor instead of squeezing it.
                            if !layout.transcriptInline && !isFocusMode && isRightPanelOpen && !noteBinding.wrappedValue.isStandalone {
                                transcriptPanel(for: noteBinding)
                                    .frame(width: layout.transcript)
                                    .overlay(alignment: .leading) {
                                        Rectangle().fill(Color.subtleBorder(isDarkMode)).frame(width: 1)
                                    }
                                    .shadow(color: Color.black.opacity(isDarkMode ? 0.4 : 0.12), radius: 16, x: -4, y: 0)
                                    .transition(.move(edge: .trailing))
                            }
                        }

                        // Right Transcript panel
                        if layout.transcriptInline && !isFocusMode && isRightPanelOpen && !noteBinding.wrappedValue.isStandalone {
                            ResizableDivider(width: $rightPanelWidth, minWidth: Double(Self.minTranscriptWidth), maxWidth: 550, isLeading: false, isDark: isDarkMode, primaryColor: primaryAccent)

                            transcriptPanel(for: noteBinding)
                                .frame(width: layout.transcript)
                                .transition(.move(edge: .trailing))
                        }
                    }
                    .clipped()
                } else {
                    ContentUnavailableView("No Note Selected", systemImage: "doc.text.fill", description: Text("Choose a note in the sidebar, or press ⌘N to start a new one."))
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
            // minWidth 0 lets the column shrink with the window instead of pushing the whole layout off-screen.
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .background(Color.panelBackground(isDarkMode))
        }
    }

    private func transcriptPanel(for noteBinding: Binding<NoteItem>) -> some View {
        TranscriptPanelView(
            note: noteBinding,
            notes: $notes,
            playerVM: playerVM,
            width: $rightPanelWidth,
            isDark: isDarkMode,
            primaryAccent: primaryAccent,
            secondaryAccent: secondaryAccent
        )
    }

    /// Sheets, overlays and notification handlers wrapped around the responsive layout.
    private func chrome<V: View>(_ content: V) -> some View {
        content
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
                .cornerRadius(AppRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
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
        .sheet(isPresented: $isTemplateModalOpen) {
            NoteTemplateModalView(
                isOpen: $isTemplateModalOpen,
                notes: $notes,
                selectedNoteId: $selectedNoteId,
                isDark: isDarkMode,
                primaryAccent: primaryAccent,
                secondaryAccent: secondaryAccent
            )
        }
        .sheet(isPresented: $isCalendarOpen) {
            CalendarModalView(
                isOpen: $isCalendarOpen,
                notes: $notes,
                selectedNoteId: $selectedNoteId
            )
        }
        .sheet(isPresented: $isExportModalOpen) {
            if let noteBinding = selectedNote {
                NoteExportModalView(
                    isOpen: $isExportModalOpen,
                    note: noteBinding.wrappedValue,
                    isDark: isDarkMode,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
            }
        }
        .overlay(alignment: .bottom) {
            EmacsMinibufferView(
                isDark: isDarkMode,
                primaryAccent: primaryAccent,
                onExecute: handleEmacsMinibufferAction
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVaultSearch)) { _ in
            isVaultSearchOpen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTemplatePicker)) { _ in
            isTemplateModalOpen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTemplateModal)) { _ in
            isTemplateModalOpen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCalendarHub)) { _ in
            isCalendarOpen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openKnowledgeGraph)) { _ in
            isGraphViewOpen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleGraphView"))) { _ in
            isGraphViewOpen.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExportModal)) { _ in
            if selectedNote != nil {
                isExportModalOpen = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createDailyNote)) { _ in
            openOrCreateDailyNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleZenFocusMode"))) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                isFocusMode.toggle()
            }
        }
        .onChange(of: tabManager.activeTabId) { _, newActiveId in
            guard let id = newActiveId, selectedNoteId != id else { return }
            DispatchQueue.main.async {
                self.selectedNoteId = id
            }
        }
        .onChange(of: selectedNoteId) { _, newId in
            guard let id = newId else { return }
            if tabManager.activeTabId != id {
                tabManager.openNote(id)
            }
            if let note = notes.first(where: { $0.id == id }) {
                let mode = openingMode(for: note)
                if editMode != mode { editMode = mode }
            }
        }
        .onAppear {
            if sidebarWidth > 260 {
                sidebarWidth = 220.0
            }
            NotesDataManager.shared.undoManager = undoManager
            if let id = selectedNoteId ?? notes.first?.id {
                tabManager.openNote(id)
                if let note = notes.first(where: { $0.id == id }) {
                    editMode = openingMode(for: note)
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
    
    private func handleEmacsMinibufferAction(_ action: EmacsAction) {
        switch action {
        case .none, .message:
            break
        case .save:
            NotesDataManager.shared.saveNotesImmediately(notes)
            EmacsController.shared.setStatus("Wrote note to vault")
        case .openVaultSearch:
            isVaultSearchOpen = true
        case .switchTab:
            tabManager.nextTab()
            selectedNoteId = tabManager.activeTabId
        case .closeTab:
            if let active = tabManager.activeTabId {
                tabManager.closeTab(active)
                selectedNoteId = tabManager.openTabIds.first
            }
        case .openCalendar:
            isCalendarOpen = true
        case .openGraph:
            isGraphViewOpen = true
        case .toggleFocus:
            withAnimation(.easeInOut(duration: 0.18)) {
                isFocusMode.toggle()
            }
        case .openTOC:
            break
        case .openAI:
            NotificationCenter.default.post(name: NSNotification.Name("OpenAIAssistant"), object: nil)
        case .orgTableAlign:
            break
        case .orgCycleTask:
            break
        case .showHelp:
            EmacsController.shared.showHelpModal = true
        case .newDailyNote:
            openOrCreateDailyNote()
        case .newNoteFromTemplate:
            isTemplateModalOpen = true
        case .exportPDF:
            if selectedNote != nil {
                isExportModalOpen = true
            }
        case .exportSRT:
            if let note = selectedNote?.wrappedValue {
                NoteExporter.shared.exportSRT(note)
            }
        }
    }
    
    private func openOrCreateDailyNote() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        if let existing = notes.first(where: { $0.folder == "Daily Notes" && $0.title == dateString }) {
            selectedNoteId = existing.id
            tabManager.openNote(existing.id)
        } else {
            let dailyNote = NoteItem(
                title: dateString,
                folder: "Daily Notes",
                content: "# Daily Journal — \(dateString)\n\n### Morning Focus & Intentions\n- [ ] Review lecture notes & priorities\n- [ ] Focus study goals\n\n### Daily Meeting & Study Notes\nType notes here...\n\n### Evening Reflections & Learnings\nKey takeaways from today:\n",
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
            notes.insert(dailyNote, at: 0)
            selectedNoteId = dailyNote.id
            tabManager.openNote(dailyNote.id)
            NotesDataManager.shared.saveNotes(notes)
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
            .cornerRadius(AppRadius.sm)
            
            Spacer()
            
            // Note Title
            HStack(spacing: 6) {
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appText(isDark))
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
                    .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .help("Exit Focus Mode (⇧⌘D)")
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
