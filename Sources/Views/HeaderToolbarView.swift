import SwiftUI
import UniformTypeIdentifiers

// MARK: - Standardized Toolbar Icon Button Component
struct ToolbarIconButton: View {
    let icon: String
    let helpText: String
    var isActive: Bool = false
    var activeColor: Color = .blue
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? activeColor : (isHovered ? .primary : .secondary))
                .frame(width: 28, height: 28)
                .background(isActive ? activeColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                .cornerRadius(AppRadius.sm)
        }
        .buttonStyle(.plain)
        .help(helpText)
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
    
    var onAudioTranscribed: ([TranscriptSegment], String) -> Void
    @State private var showFolderPopover = false
    @State private var showAIAssistantPopover = false
    @State private var newFolderName = ""
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Trash Safety & Recovery Banner
            if let noteBinding = selectedNote, noteBinding.wrappedValue.folder == "Trash" {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.amber)
                    
                    Text("This note is currently in the Trash.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isDark ? .white : .black)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            let target = noteBinding.wrappedValue.originalFolder ?? "General"
                            noteBinding.wrappedValue.folder = target == "Trash" ? "General" : target
                            dataManager.saveNotes(notes)
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
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showDeleteAlert = true
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
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .alert("Permanently Delete Note?", isPresented: $showDeleteAlert) {
                        Button("Delete Permanently", role: .destructive) {
                            if let id = selectedNoteId {
                                notes.removeAll(where: { $0.id == id })
                                tabManager.closeTab(id)
                                selectedNoteId = notes.first?.id
                                dataManager.saveNotes(notes)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This note \"\(noteBinding.wrappedValue.title)\" will be removed permanently. This action cannot be undone.")
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSidebarOpen.toggle()
                        }
                    }

                    // Back & Forward History Navigation
                    HStack(spacing: 2) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                tabManager.goBack()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(tabManager.canGoBack ? (isDark ? .white : .black) : .secondary.opacity(0.35))
                                .frame(width: 22, height: 22)
                                .background(Color.clear)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(!tabManager.canGoBack)
                        .help("Navigate Back (⌘[)")

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                tabManager.goForward()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(tabManager.canGoForward ? (isDark ? .white : .black) : .secondary.opacity(0.35))
                                .frame(width: 22, height: 22)
                                .background(Color.clear)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(!tabManager.canGoForward)
                        .help("Navigate Forward (⌘])")
                    }
                    .padding(2)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                }

                // Vertical Cluster Divider
                Rectangle()
                    .fill(Color.subtleBorder(isDark))
                    .frame(width: 1, height: 16)
                    .padding(.horizontal, 2)

                // Group 2: Document Identity & Metadata
                if let noteBinding = selectedNote {
                    HStack(spacing: 6) {
                        // Title Editor
                        TextField("Untitled Note", text: noteBinding.title)
                            .font(.system(size: 13, weight: .semibold))
                            .textFieldStyle(.plain)
                            .frame(minWidth: 120, maxWidth: 200)
                        
                        // Pin / Unpin Note Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                noteBinding.wrappedValue.isPinned.toggle()
                                dataManager.saveNotes(notes)
                            }
                        }) {
                            Image(systemName: noteBinding.wrappedValue.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(noteBinding.wrappedValue.isPinned ? primaryAccent : .secondary)
                                .frame(width: 22, height: 22)
                                .background(noteBinding.wrappedValue.isPinned ? primaryAccent.opacity(0.12) : Color.clear)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help(noteBinding.wrappedValue.isPinned ? "Unpin Note (⌘⇧P)" : "Pin Note (⌘⇧P)")

                        // Save Status Indicator
                        HStack(spacing: 4) {
                            if dataManager.isSaving {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.55)
                                Text("Saving")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            } else {
                                Circle()
                                    .fill(SemanticColor.success.opacity(0.9))
                                    .frame(width: 5, height: 5)
                                Text("Saved")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .help("Vault automatic save state")
                        
                        // Folder Selector Pill
                        Button(action: { showFolderPopover.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(noteBinding.wrappedValue.folder)
                                   .font(.system(size: 11, weight: .medium))
                                   .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                   .font(.system(size: 7, weight: .semibold))
                                   .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showFolderPopover) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Move Note to Folder")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                TextField("New Folder name...", text: $newFolderName, onCommit: {
                                    if !newFolderName.isEmpty {
                                        noteBinding.wrappedValue.folder = newFolderName
                                        showFolderPopover = false
                                        newFolderName = ""
                                    }
                                })
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                            }
                            .padding()
                        }
                    }
                }
                
                Spacer()

                // Group 3: View Mode Picker Segmented Control
                if let noteBinding = selectedNote {
                    let availableModes: [EditModeType] = noteBinding.wrappedValue.pdfPath != nil ? EditModeType.allCases : [.edit, .split, .preview]
                    HStack(spacing: 1) {
                        ForEach(availableModes, id: \.self) { mode in
                            Button(action: { editMode = mode }) {
                                Text(mode.rawValue)
                                    .font(.system(size: 11, weight: editMode == mode ? .semibold : .regular))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3)
                                    .background(editMode == mode ? (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)) : Color.clear)
                                    .foregroundColor(editMode == mode ? .primary : .secondary)
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                    .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                    .cornerRadius(AppRadius.sm)
                }

                Spacer()
                
                // Group 4: Document Primary Actions
                if let noteBinding = selectedNote {
                    HStack(spacing: 6) {
                        // Live Waveform Visualizer
                        if recorderVM.isRecording {
                            WaveformVisualizerView(level: recorderVM.audioLevel, primaryColor: SemanticColor.record)
                        }

                        // Attach PDF / Document Action Button
                        ToolbarIconButton(
                            icon: noteBinding.wrappedValue.pdfPath != nil ? "doc.richtext.fill" : "paperclip",
                            helpText: noteBinding.wrappedValue.pdfPath != nil ? "View Attached PDF Document" : "Attach PDF Document...",
                            isActive: noteBinding.wrappedValue.pdfPath != nil,
                            activeColor: SemanticColor.pdfBadge
                        ) {
                            if noteBinding.wrappedValue.pdfPath != nil {
                                editMode = (editMode == .pdf ? .split : .pdf)
                            } else {
                                attachPDFDocument()
                            }
                        }

                        // Audio Record Button (Destructive / Dedicated Recording Red)
                        if noteBinding.wrappedValue.isStandalone {
                            Button(action: toggleRecording) {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(SemanticColor.record)
                                        .frame(width: 6, height: 6)
                                    Text(recorderVM.isRecording ? "Stop" : "Record")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(recorderVM.isRecording ? SemanticColor.record : .primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(recorderVM.isRecording ? SemanticColor.record.opacity(0.15) : Color.primary.opacity(0.05))
                                .cornerRadius(AppRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .stroke(recorderVM.isRecording ? SemanticColor.record.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(recorderVM.isRecording ? "Stop Recording Lecture Audio" : "Record Audio Note (⌘R)")
                        }

                        // AI Assistant Popover Button (Dedicated Purple/Violet)
                        Button(action: { showAIAssistantPopover.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(SemanticColor.aiAccent)
                                Text("AI Assistant")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(SemanticColor.aiAccent)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SemanticColor.aiAccentSurface)
                            .cornerRadius(AppRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .stroke(SemanticColor.aiAccent.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Open Gemma Local AI Assistant (Summarize, Q&A, Flashcards)")
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

                    // Vertical Cluster Divider
                    Rectangle()
                        .fill(Color.subtleBorder(isDark))
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 2)

                    // Group 5: Tools & Window Utilities
                    HStack(spacing: 4) {
                        // Knowledge Graph Canvas Toggle
                        ToolbarIconButton(icon: "circle.hexagonpath", helpText: "Knowledge Graph Canvas (⌘G)", isActive: isGraphViewOpen, activeColor: secondaryAccent) {
                            isGraphViewOpen = true
                        }

                        // Zen Focus Mode Toggle
                        ToolbarIconButton(icon: isFocusMode ? "viewfinder.circle.fill" : "viewfinder", helpText: "Zen Focus Mode (⌘Shift+F)", isActive: isFocusMode, activeColor: primaryAccent) {
                            isFocusMode.toggle()
                        }

                        // Move to Trash Button
                        ToolbarIconButton(icon: "trash", helpText: "Move Note to Trash", isActive: false) {
                            showDeleteAlert = true
                        }
                        .alert("Move Note to Trash?", isPresented: $showDeleteAlert) {
                            Button("Move to Trash", role: .destructive) {
                                noteBinding.wrappedValue.folder = "Trash"
                                selectedNoteId = notes.first(where: { $0.folder != "Trash" })?.id
                                NotesDataManager.shared.saveNotes(notes)
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Are you sure you want to move '\(noteBinding.wrappedValue.title)' to Trash?")
                        }

                        // Toggle Transcript Right Panel Button
                        if !noteBinding.wrappedValue.isStandalone {
                            ToolbarIconButton(icon: "sidebar.right", helpText: "Toggle Transcript View", isActive: isRightPanelOpen, activeColor: primaryAccent) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isRightPanelOpen.toggle()
                                }
                            }
                        }

                        // Settings Toggle Button
                        ToolbarIconButton(icon: "gearshape", helpText: "Preferences & Settings (⌘,)", isActive: isSettingsOpen, activeColor: primaryAccent) {
                            isSettingsOpen = true
                        }
                    }
                } else {
                    // When no note is selected, still provide settings button
                    ToolbarIconButton(icon: "gearshape", helpText: "Preferences & Settings (⌘,)", isActive: isSettingsOpen, activeColor: primaryAccent) {
                        isSettingsOpen = true
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.panelBackground(isDark))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.subtleBorder(isDark)),
                alignment: .bottom
            )
        }
    }
    
    private func toggleRecording() {
        if recorderVM.isRecording {
            if let tempURL = recorderVM.stopRecording() {
                if let noteBinding = selectedNote {
                    // Import into sandbox so the recording is never lost
                    if let (_, safeURL) = NotesDataManager.shared.importAttachment(from: tempURL, for: noteBinding.wrappedValue.id) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            LocalSpeechTranscriber.transcribe(url: safeURL) { segments in
                                onAudioTranscribed(segments, safeURL.path)
                            }
                        }
                        return
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    LocalSpeechTranscriber.transcribe(url: tempURL) { segments in
                        onAudioTranscribed(segments, tempURL.path)
                    }
                }
            }
        } else {
            recorderVM.startRecording()
        }
    }

    private func attachPDFDocument() {
        guard let noteBinding = selectedNote else { return }
        let panel = NSOpenPanel()
        panel.title = "Attach PDF Document"
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: noteBinding.wrappedValue.id) {
                    noteBinding.wrappedValue.pdfPath = relPath
                    editMode = .pdf
                    NotesDataManager.shared.saveNotes(notes)
                }
            }
        }
    }

    private func importAudioFile() {
        guard let noteBinding = selectedNote else { return }
        let panel = NSOpenPanel()
        panel.title = "Import Lecture Audio File"
        panel.allowedContentTypes = [UTType.audio, UTType.mp3, UTType.wav, UTType.mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let (_, safeURL) = NotesDataManager.shared.importAttachment(from: url, for: noteBinding.wrappedValue.id) {
                    LocalSpeechTranscriber.transcribe(url: safeURL) { segments in
                        onAudioTranscribed(segments, safeURL.path)
                    }
                }
            }
        }
    }
}
