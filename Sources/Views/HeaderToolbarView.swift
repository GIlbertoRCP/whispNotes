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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? activeColor : (isHovered ? .primary : .secondary))
                .frame(width: 28, height: 28)
                .background(isHovered ? Color.primary.opacity(0.08) : (isActive ? activeColor.opacity(0.12) : Color.clear))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(helpText)
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
    
    var onAudioTranscribed: ([TranscriptSegment], String) -> Void
    @State private var showFolderPopover = false
    @State private var showAIAssistantPopover = false
    @State private var newFolderName = ""
    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: 10) {
            // Left Section: Navigation & Document Controls
            HStack(spacing: 8) {
                ToolbarIconButton(icon: "sidebar.left", helpText: "Toggle Sidebar", isActive: isSidebarOpen, activeColor: primaryAccent) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarOpen.toggle()
                    }
                }

                if let noteBinding = selectedNote {
                    // Title Editor
                    TextField("Untitled Note", text: noteBinding.title)
                        .font(.system(size: 14, weight: .bold))
                        .textFieldStyle(.plain)
                        .frame(minWidth: 120, maxWidth: 240)
                    
                    // Save Status Indicator Pill
                    HStack(spacing: 3) {
                        if dataManager.isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                            Text("Saving...")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Saved ✓")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.emerald.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.cardBackground(isDark))
                    .cornerRadius(4)
                    .help("Vault automatic save state")
                    
                    // Folder Selector Pill
                    Button(action: { showFolderPopover.toggle() }) {
                        HStack(spacing: 4) {
                            Text(noteBinding.wrappedValue.folder)
                               .font(.system(size: 11, weight: .semibold))
                               .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                               .font(.system(size: 8, weight: .bold))
                               .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                        )
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

            // Center Section: Mode Picker Segmented Control
            if selectedNote != nil {
                HStack(spacing: 2) {
                    ForEach(EditModeType.allCases, id: \.self) { mode in
                        Button(action: { editMode = mode }) {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: editMode == mode ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(editMode == mode ? primaryAccent.opacity(0.18) : Color.clear)
                                .foregroundColor(editMode == mode ? primaryAccent : .secondary)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.cardBackground(isDark))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                )
            }

            Spacer()
            
            // Right Section: Tools & Action Buttons
            HStack(spacing: 6) {
                if let noteBinding = selectedNote {
                    // Live Waveform Visualizer
                    if recorderVM.isRecording {
                        WaveformVisualizerView(level: recorderVM.audioLevel, primaryColor: primaryAccent)
                    }

                    // Audio Record Pill Button
                    if noteBinding.wrappedValue.isStandalone {
                        Button(action: toggleRecording) {
                            HStack(spacing: 5) {
                                Image(systemName: recorderVM.isRecording ? "stop.circle.fill" : "mic.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                Text(recorderVM.isRecording ? "Stop" : "Record")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(recorderVM.isRecording ? Color.red : primaryAccent)
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .help(recorderVM.isRecording ? "Stop Recording" : "Record Audio Note")
                    }

                    // AI Assistant Popover Button
                    Button(action: { showAIAssistantPopover.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(primaryAccent)
                            Text("AI Assistant")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(primaryAccent)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(primaryAccent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open Gemma Local AI Assistant")
                    .popover(isPresented: $showAIAssistantPopover) {
                        AIStudyAssistantView(
                            note: noteBinding.wrappedValue,
                            isDark: isDark,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent,
                            onInsertSummary: { summaryBlock in
                                noteBinding.wrappedValue.content += summaryBlock
                                NotesDataManager.shared.saveNotes(notes)
                                showAIAssistantPopover = false
                            }
                        )
                    }

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
                }

                // Settings Toggle Button
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
    
    private func toggleRecording() {
        if recorderVM.isRecording {
            if let url = recorderVM.stopRecording() {
                LocalSpeechTranscriber.transcribe(url: url) { segments in
                    onAudioTranscribed(segments, url.path)
                }
            }
        } else {
            recorderVM.startRecording()
        }
    }

    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Lecture Audio File"
        panel.allowedContentTypes = [UTType.audio, UTType.mp3, UTType.wav, UTType.mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                LocalSpeechTranscriber.transcribe(url: url) { segments in
                    onAudioTranscribed(segments, url.path)
                }
            }
        }
    }
}
