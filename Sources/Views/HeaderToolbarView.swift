import SwiftUI
import UniformTypeIdentifiers

// MARK: - Standardized Toolbar Icon Button Component
struct ToolbarIconButton: View {
    let icon: String
    let helpText: String
    var shortcut: String? = nil
    var isActive: Bool = false
    var activeColor: Color = .blue
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? activeColor : (isHovered ? .primary : .secondary))
                .frame(width: 24, height: 24)
                .background(isActive ? activeColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                .cornerRadius(AppRadius.sm)
        }
        .buttonStyle(.plain)
        .obsidianTooltip(helpText, shortcut: shortcut)
        .accessibilityLabel(helpText)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Header Toolbar View
struct HeaderToolbarView: View {
    @Binding var isSidebarOpen: Bool
    @Binding var isRightPanelOpen: Bool
    @Binding var isSettingsOpen: Bool
    @Binding var isGraphViewOpen: Bool
    @Binding var isFocusMode: Bool
    @Binding var editMode: EditModeType
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var selectedNote: Binding<NoteItem>?
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    
    @ObservedObject var recorderVM: AudioRecorderViewModel
    @ObservedObject var playerVM: AudioPlayerViewModel
    @ObservedObject private var dataManager = NotesDataManager.shared
    @ObservedObject private var tabManager = TabNavigationManager.shared
    
    @State private var showFolderPopover = false
    @State private var showAIAssistantPopover = false
    @State private var newFolderName = ""
    @State private var showTrashAlert = false
    @State private var showPermanentDeleteAlert = false
    /// Width the toolbar actually gets; drives how much it condenses.
    @State private var availableWidth: CGFloat = 1200

    /// 0 = everything shown with labels … 4 = only essentials. Thresholds are the measured widths each tier needs.
    private var density: Int {
        switch availableWidth {
        case 1040...: return 0
        case 900..<1040: return 1
        case 760..<900: return 2
        case 600..<760: return 3
        default: return 4
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Trash Safety & Recovery Banner
            if let noteBinding = selectedNote, noteBinding.wrappedValue.folder == "Trash" {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.amber)
                    
                    Text("This note is in the Trash.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isDark ? .white : .black)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            let previous = notes
                            let target = noteBinding.wrappedValue.originalFolder ?? "General"
                            noteBinding.wrappedValue.folder = target == "Trash" ? "General" : target
                            dataManager.saveNotes(notes)
                            dataManager.registerStructuralUndo(actionName: "Restore Note", previousState: previous)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 10, weight: .bold))
                            Text("Restore Note")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.emerald.opacity(0.2))
                        .foregroundColor(.emerald)
                        .cornerRadius(AppRadius.xs)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showPermanentDeleteAlert = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.slash.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Delete Permanently")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.18))
                        .foregroundColor(.red)
                        .cornerRadius(AppRadius.xs)
                    }
                    .buttonStyle(.plain)
                    .alert("Delete Note Permanently?", isPresented: $showPermanentDeleteAlert) {
                        Button("Delete Permanently", role: .destructive) {
                            if let id = selectedNoteId {
                                let previous = notes
                                notes.removeAll(where: { $0.id == id })
                                tabManager.closeTab(id)
                                selectedNoteId = notes.first(where: { $0.folder != "Trash" })?.id
                                dataManager.saveNotes(notes)
                                dataManager.registerStructuralUndo(actionName: "Delete Note", previousState: previous)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("“\(noteBinding.wrappedValue.title)” will be deleted. You can still undo this with ⌘Z until you quit.")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.12))
                
                Divider()
                    .background(Color.red.opacity(0.25))
            }

            HStack(spacing: 8) {
                // Group 1: Navigation Controls
                HStack(spacing: 4) {
                    ToolbarIconButton(icon: "sidebar.left", helpText: "Toggle Sidebar", isActive: isSidebarOpen, activeColor: primaryAccent) {
                        withAnimation(AppAnimation.panel) {
                            isSidebarOpen.toggle()
                        }
                    }

                    // Back & forward (still on ⌘[ / ⌘] when hidden in tight windows)
                    if density < 3 {
                        HStack(spacing: 2) {
                            historyButton(icon: "chevron.left", enabled: tabManager.canGoBack, help: "Back (⌘[)") { tabManager.goBack() }
                            historyButton(icon: "chevron.right", enabled: tabManager.canGoForward, help: "Forward (⌘])") { tabManager.goForward() }
                        }
                        .padding(2)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(AppRadius.sm)
                    }
                }

                if let noteBinding = selectedNote, density < 4 {
                    clusterDivider

                    // Group 2: Document Identity & Metadata
                    HStack(spacing: 6) {
                        TextField("Untitled Note", text: noteBinding.title)
                            .font(.system(size: 13, weight: .semibold))
                            .textFieldStyle(.plain)
                            .lineLimit(1)
                            .frame(minWidth: 80, maxWidth: 220)
                            .layoutPriority(1)

                        if density < 3 {
                            pinButton(noteBinding)
                        }

                        saveStatus

                        folderMenu(noteBinding)
                    }
                }

                Spacer(minLength: 8)

                // Group 3: View Mode Picker
                if let noteBinding = selectedNote {
                    modePicker(availableModes(for: noteBinding.wrappedValue))
                }

                Spacer(minLength: 8)

                // Group 4: Document Primary Actions
                if let noteBinding = selectedNote {
                    HStack(spacing: 6) {
                        if recorderVM.isRecording && density < 2 {
                            WaveformVisualizerView(level: recorderVM.audioLevel, primaryColor: SemanticColor.record)
                        }

                        documentButton(noteBinding)

                        if recorderVM.transcribingNoteIds.contains(noteBinding.wrappedValue.id) {
                            HStack(spacing: 5) {
                                ProgressView().controlSize(.small).scaleEffect(0.6).frame(width: 12, height: 12)
                                if density < 2 {
                                    Text("Transcribing…")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .fixedSize()
                                }
                            }
                            .help("Transcribing the recording on this Mac")
                        }

                        // Stop stays reachable from any note while a recording runs.
                        if recorderVM.isRecording
                            || (noteBinding.wrappedValue.isStandalone && !recorderVM.transcribingNoteIds.contains(noteBinding.wrappedValue.id)) {
                            recordButton
                        }

                        aiAssistantButton(noteBinding)
                    }

                    clusterDivider

                    // Group 5: Tools & Window Utilities
                    HStack(spacing: 4) {
                        if density < 2 {
                            ToolbarIconButton(icon: "calendar", helpText: "Calendar & Daily Notes (⌘⌥C)", shortcut: "⌘⌥C", isActive: false, activeColor: primaryAccent) {
                                NotificationCenter.default.post(name: .openCalendarHub, object: nil)
                            }
                            ToolbarIconButton(icon: "circle.hexagonpath", helpText: "Knowledge Graph (⌘G)", shortcut: "⌘G", isActive: isGraphViewOpen, activeColor: secondaryAccent) {
                                isGraphViewOpen = true
                            }
                            ToolbarIconButton(icon: "trash", helpText: "Move Note to Trash", isActive: false) {
                                showTrashAlert = true
                            }
                        } else {
                            overflowMenu(noteBinding)
                        }

                        if !noteBinding.wrappedValue.isStandalone {
                            ToolbarIconButton(icon: "sidebar.right", helpText: "Toggle Transcript", isActive: isRightPanelOpen, activeColor: primaryAccent) {
                                withAnimation(AppAnimation.panel) {
                                    isRightPanelOpen.toggle()
                                }
                            }
                        }

                        settingsButton
                    }
                    .alert("Move Note to Trash?", isPresented: $showTrashAlert) {
                        Button("Move to Trash", role: .destructive) { moveToTrash(noteBinding) }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("“\(noteBinding.wrappedValue.title)” moves to the Trash. You can restore it from there at any time.")
                    }
                } else {
                    settingsButton
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(Color.panelBackground(isDark))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.subtleBorder(isDark)),
                alignment: .bottom
            )
            .background(
                // Measures the width offered to the toolbar (not its content), so density reacts to the window.
                GeometryReader { geo in
                    Color.clear
                        .onAppear { availableWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, width in availableWidth = width }
                }
            )
        }
    }

    // MARK: - Toolbar pieces

    private var clusterDivider: some View {
        Rectangle()
            .fill(Color.subtleBorder(isDark))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 2)
    }

    private func historyButton(icon: String, enabled: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(AppAnimation.micro) { action() } }) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(enabled ? Color.appText(isDark) : .secondary.opacity(0.35))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }

    private func pinButton(_ noteBinding: Binding<NoteItem>) -> some View {
        Button(action: {
            withAnimation(AppAnimation.micro) {
                noteBinding.wrappedValue.isPinned.toggle()
                dataManager.saveNotes(notes)
            }
        }) {
            Image(systemName: noteBinding.wrappedValue.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(noteBinding.wrappedValue.isPinned ? primaryAccent : .secondary)
                .frame(width: 22, height: 22)
                .background(noteBinding.wrappedValue.isPinned ? primaryAccent.opacity(0.12) : Color.clear)
                .cornerRadius(AppRadius.xs)
        }
        .buttonStyle(.plain)
        .help(noteBinding.wrappedValue.isPinned ? "Unpin Note (⇧⌘P)" : "Pin Note (⇧⌘P)")
    }

    private var saveStatus: some View {
        HStack(spacing: 4) {
            if dataManager.isSaving {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.55)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(SemanticColor.success.opacity(0.9))
                    .frame(width: 5, height: 5)
            }
            if density < 1 {
                Text(dataManager.isSaving ? "Saving" : "Saved")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .help(dataManager.isSaving ? "Saving…" : "All changes saved")
    }

    private func folderMenu(_ noteBinding: Binding<NoteItem>) -> some View {
        Menu {
            Section("Move to Folder") {
                ForEach(Array(Set(notes.map { $0.folder }).subtracting(["Trash"])).sorted(), id: \.self) { folderName in
                    Button(action: {
                        noteBinding.wrappedValue.folder = folderName
                        dataManager.saveNotes(notes)
                    }) {
                        if noteBinding.wrappedValue.folder == folderName {
                            Label(folderName, systemImage: "checkmark")
                        } else {
                            Label(folderName, systemImage: "folder")
                        }
                    }
                }
            }

            Divider()

            Button(action: { showFolderPopover = true }) {
                Label("New Folder…", systemImage: "folder.badge.plus")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Text(noteBinding.wrappedValue.folder)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: density < 2 ? 140 : 90, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(AppRadius.sm)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Move to folder")
        .popover(isPresented: $showFolderPopover) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("New Folder")
                    .font(.headline)
                Text("The note moves into the new folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Folder name", text: $newFolderName, onCommit: { createFolderAndMove(noteBinding) })
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                HStack {
                    Spacer()
                    Button("Cancel") { showFolderPopover = false; newFolderName = "" }
                        .keyboardShortcut(.cancelAction)
                    Button("Move Note") { createFolderAndMove(noteBinding) }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .controlSize(.small)
            }
            .padding(AppSpacing.lg)
        }
    }

    private func createFolderAndMove(_ noteBinding: Binding<NoteItem>) {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "Trash" else { return }
        noteBinding.wrappedValue.folder = trimmed
        dataManager.saveNotes(notes)
        showFolderPopover = false
        newFolderName = ""
    }

    private func availableModes(for note: NoteItem) -> [EditModeType] {
        if note.pptxPath != nil { return [.edit, .split, .preview, .pptx] }
        if note.pdfPath != nil { return [.edit, .split, .preview, .pdf] }
        return [.edit, .split, .preview]
    }

    @ViewBuilder
    private func modePicker(_ modes: [EditModeType]) -> some View {
        if density < 3 {
            HStack(spacing: 1) {
                ForEach(modes, id: \.self) { mode in
                    Button(action: { editMode = mode }) {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: editMode == mode ? .semibold : .regular))
                            .fixedSize()
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(editMode == mode ? (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)) : Color.clear)
                            .foregroundColor(editMode == mode ? .primary : .secondary)
                            .cornerRadius(AppRadius.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            .cornerRadius(AppRadius.sm)
        } else {
            Menu {
                Picker("View", selection: $editMode) {
                    ForEach(modes, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 4) {
                    Text(editMode.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                .cornerRadius(AppRadius.sm)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("View mode")
        }
    }

    private func documentButton(_ noteBinding: Binding<NoteItem>) -> some View {
        let note = noteBinding.wrappedValue
        let icon = note.pptxPath != nil ? "sparkles.tv" : (note.pdfPath != nil ? "doc.richtext.fill" : "paperclip")
        let help = note.pptxPath != nil ? "View Attached Slides" : (note.pdfPath != nil ? "View Attached PDF" : "Attach PDF or Presentation…")
        return ToolbarIconButton(
            icon: icon,
            helpText: help,
            isActive: note.hasAttachedDocument,
            activeColor: note.pptxPath != nil ? primaryAccent : SemanticColor.pdfBadge
        ) {
            if note.pptxPath != nil {
                editMode = (editMode == .pptx ? .split : .pptx)
            } else if note.pdfPath != nil {
                editMode = (editMode == .pdf ? .split : .pdf)
            } else {
                attachDocument()
            }
        }
    }

    private var recordButton: some View {
        Button(action: toggleRecording) {
            HStack(spacing: 5) {
                Circle()
                    .fill(SemanticColor.record)
                    .frame(width: 6, height: 6)
                if density < 1 || recorderVM.isRecording {
                    Text(recorderVM.isRecording ? "Stop" : "Record")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(recorderVM.isRecording ? SemanticColor.record : .primary)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(recorderVM.isRecording ? SemanticColor.record.opacity(0.15) : Color.primary.opacity(0.05))
            .cornerRadius(AppRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(recorderVM.isRecording ? SemanticColor.record.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(recorderVM.isRecording ? "Stop Recording and Transcribe (⌃⌥⌘R)" : "Record Into This Note (⌃⌥⌘R)")
        .accessibilityLabel(recorderVM.isRecording ? "Stop Recording" : "Record")
    }

    private func aiAssistantButton(_ noteBinding: Binding<NoteItem>) -> some View {
        Button(action: { showAIAssistantPopover.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                if density < 1 {
                    Text("AI Assistant")
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize()
                }
            }
            .foregroundColor(SemanticColor.aiAccent)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(SemanticColor.aiAccentSurface)
            .cornerRadius(AppRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(SemanticColor.aiAccent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("AI Assistant: summarize, Q&A and flashcards with local Gemma")
        .accessibilityLabel("AI Assistant")
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAIAssistant"))) { _ in
            showAIAssistantPopover = true
        }
        .popover(isPresented: $showAIAssistantPopover) {
            AIStudyAssistantView(
                note: noteBinding.wrappedValue,
                isDark: isDark,
                primaryAccent: SemanticColor.aiAccent,
                secondaryAccent: secondaryAccent,
                onInsertSummary: { summaryBlock in
                    noteBinding.wrappedValue.content += summaryBlock
                    NotesDataManager.shared.saveNotes(notes)
                    showAIAssistantPopover = false
                }
            )
        }
    }

    /// Tools that fold away when the window is narrow.
    private func overflowMenu(_ noteBinding: Binding<NoteItem>) -> some View {
        Menu {
            Button(action: { NotificationCenter.default.post(name: .openCalendarHub, object: nil) }) {
                Label("Calendar & Daily Notes", systemImage: "calendar")
            }
            Button(action: { isGraphViewOpen = true }) {
                Label("Knowledge Graph", systemImage: "circle.hexagonpath")
            }
            if density >= 3 {
                Divider()
                Button(action: {
                    noteBinding.wrappedValue.isPinned.toggle()
                    dataManager.saveNotes(notes)
                }) {
                    Label(noteBinding.wrappedValue.isPinned ? "Unpin Note" : "Pin Note", systemImage: "pin")
                }
                Button(action: { withAnimation(AppAnimation.micro) { tabManager.goBack() } }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(!tabManager.canGoBack)
                Button(action: { withAnimation(AppAnimation.micro) { tabManager.goForward() } }) {
                    Label("Forward", systemImage: "chevron.right")
                }
                .disabled(!tabManager.canGoForward)
            }
            Divider()
            Button(role: .destructive, action: { showTrashAlert = true }) {
                Label("Move to Trash…", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
        .accessibilityLabel("More")
    }

    private var settingsButton: some View {
        ToolbarIconButton(icon: "gearshape", helpText: "Settings (⌘,)", shortcut: "⌘,", isActive: isSettingsOpen, activeColor: primaryAccent) {
            isSettingsOpen = true
        }
    }

    /// Same behaviour as the sidebar's Move to Trash: remembers the folder for Restore, unpins, and is undoable.
    private func moveToTrash(_ noteBinding: Binding<NoteItem>) {
        let previous = notes
        let id = noteBinding.wrappedValue.id
        noteBinding.wrappedValue.originalFolder = noteBinding.wrappedValue.folder
        noteBinding.wrappedValue.isPinned = false
        noteBinding.wrappedValue.folder = "Trash"
        tabManager.closeTab(id)
        selectedNoteId = notes.first(where: { $0.folder != "Trash" && $0.id != id })?.id
        dataManager.saveNotes(notes)
        dataManager.registerStructuralUndo(actionName: "Move to Trash", previousState: previous)
    }

    private func toggleRecording() {
        if recorderVM.isRecording {
            recorderVM.finishRecording()
        } else if let id = selectedNote?.wrappedValue.id {
            recorderVM.startRecording(for: id)
        }
    }

    private func attachDocument() {
        guard let noteBinding = selectedNote else { return }
        let panel = NSOpenPanel()
        panel.title = "Attach PDF or Presentation (PPTX)"
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
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: noteBinding.wrappedValue.id) {
                    if ext == "pptx" {
                        noteBinding.wrappedValue.pptxPath = relPath
                        editMode = .pptx
                    } else {
                        noteBinding.wrappedValue.pdfPath = relPath
                        editMode = .pdf
                    }
                    NotesDataManager.shared.saveNotes(notes)
                }
            }
        }
    }
}
