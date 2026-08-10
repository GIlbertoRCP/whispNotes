import SwiftUI
import UniformTypeIdentifiers

// MARK: - Header Toolbar View
struct HeaderToolbarView: View {
    @Binding var isSidebarOpen: Bool
    @Binding var isRightPanelOpen: Bool
    @Binding var isSettingsOpen: Bool
    @Binding var isGraphViewOpen: Bool
    @Binding var isFocusMode: Bool
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var selectedNote: Binding<NoteItem>?
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    
    @ObservedObject var recorderVM: AudioRecorderViewModel
    @ObservedObject var playerVM: AudioPlayerViewModel
    
    var onAudioTranscribed: ([TranscriptSegment], String) -> Void
    @State private var showFolderPopover = false
    @State private var newFolderName = ""
    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isSidebarOpen.toggle() }) {
                Image(systemName: "sidebar.left")
                    .font(.title3)
                    .foregroundColor(isSidebarOpen ? primaryAccent : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Sidebar")

            if let noteBinding = selectedNote {
                // Rename Input In-place
                TextField("Untitled Note", text: noteBinding.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 280)
                
                // Folder Selection pill
                Button(action: { showFolderPopover.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .foregroundColor(primaryAccent)
                            .font(.caption)
                        Text(noteBinding.wrappedValue.folder)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cardBackground(isDark))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
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
                
                // Import Audio File Button (.mp3, .wav, .m4a)
                Button(action: importAudioFile) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.body)
                        .foregroundColor(secondaryAccent)
                }
                .buttonStyle(.plain)
                .help("Import Audio File (.wav, .mp3, .m4a)")

                // Export Note Menu Button
                Menu {
                    Button(action: { NoteExporter.shared.exportPDF(noteBinding.wrappedValue) }) {
                        Label("Export as PDF Document (.pdf)", systemImage: "doc.richtext")
                    }
                    Button(action: { NoteExporter.shared.exportMarkdown(noteBinding.wrappedValue) }) {
                        Label("Export as Markdown (.md)", systemImage: "doc.text")
                    }
                    Button(action: { NoteExporter.shared.exportHTML(noteBinding.wrappedValue) }) {
                        Label("Export as Web Page (.html)", systemImage: "globe")
                    }
                    Button(action: { NoteExporter.shared.exportPlainText(noteBinding.wrappedValue) }) {
                        Label("Export as Plain Text (.txt)", systemImage: "doc.plaintext")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(primaryAccent)
                }
                .menuStyle(.borderlessButton)
                .help("Export Note (PDF / Markdown / HTML / Text)")
                
                // Delete Note Trash Icon
                Button(action: { showDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Move Note to Trash")
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
                
                Spacer()
                
                // Live Recording Waveform
                if recorderVM.isRecording {
                    WaveformVisualizerView(level: recorderVM.audioLevel, primaryColor: primaryAccent)
                }

                // Knowledge Graph Canvas Button (⌘G)
                Button(action: { isGraphViewOpen = true }) {
                    Image(systemName: "network")
                        .font(.title3)
                        .foregroundColor(secondaryAccent)
                }
                .buttonStyle(.plain)
                .help("Knowledge Graph Canvas (⌘G)")

                // Zen Focus Mode Toggle
                Button(action: { isFocusMode.toggle() }) {
                    Image(systemName: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundColor(isFocusMode ? .amber : .secondary)
                }
                .buttonStyle(.plain)
                .help("Zen Focus Mode (⌘Shift+F)")
                
                // Record Audio in-place controller
                if noteBinding.wrappedValue.isStandalone {
                    Button(action: toggleRecording) {
                        HStack(spacing: 6) {
                            Image(systemName: recorderVM.isRecording ? "stop.circle.fill" : "mic.fill")
                                .foregroundColor(.white)
                            Text(recorderVM.isRecording ? "Stop" : "Record")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(recorderVM.isRecording ? Color.red : primaryAccent)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
                
                if !noteBinding.wrappedValue.isStandalone {
                    Button(action: { isRightPanelOpen.toggle() }) {
                        Image(systemName: "sidebar.right")
                            .font(.title3)
                            .foregroundColor(isRightPanelOpen ? primaryAccent : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Transcript View")
                }
                
                // Top-Right Settings Toggle Button
                Button(action: { isSettingsOpen = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(primaryAccent)
                }
                .buttonStyle(.plain)
                .help("Preferences & Settings")
            } else {
                Spacer()
                
                Button(action: { isSettingsOpen = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(primaryAccent)
                }
                .buttonStyle(.plain)
                .help("Preferences & Settings")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
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

    private func exportNoteMarkdown(_ note: NoteItem) {
        let panel = NSSavePanel()
        panel.title = "Export Note as Markdown"
        panel.nameFieldStringValue = "\(note.title).md"
        panel.allowedContentTypes = [UTType.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                var markdownExport = "# \(note.title)\n\n\(note.content)\n\n"
                if !note.transcript.isEmpty {
                    markdownExport += "## Diarized Transcript\n\n"
                    for seg in note.transcript {
                        let timestampStr = formatTime(seg.startTime)
                        markdownExport += "**\(seg.speaker)** [\(timestampStr)]: \(seg.text)\n\n"
                    }
                }
                try? markdownExport.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func exportNoteHTML(_ note: NoteItem) {
        let panel = NSSavePanel()
        panel.title = "Export Note as HTML"
        panel.nameFieldStringValue = "\(note.title).html"
        panel.allowedContentTypes = [UTType.html]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let html = generateFormattedHTML(for: note)
                try? html.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func generateFormattedHTML(for note: NoteItem) -> String {
        let bodyHTML = note.content
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "- [ ]", with: "<span>&#9633;</span>")
            .replacingOccurrences(of: "- [x]", with: "<span>&#9745;</span>")
        
        var transcriptHTML = ""
        if !note.transcript.isEmpty {
            transcriptHTML += "2>Diarized Transcript</h2><div class='transcript'>"
            for seg in note.transcript {
                let timeStr = formatTime(seg.startTime)
                transcriptHTML += "<div class='segment'><span class='speaker'>\(seg.speaker)</span> <span class='time'>[\(timeStr)]</span>: \(seg.text)</div>"
            }
            transcriptHTML += "</div>"
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>\(note.title)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0f172a; color: #f8fafc; padding: 40px; max-width: 800px; margin: 0 auto; line-height: 1.6; }
                h1 { color: #38bdf8; border-bottom: 1px solid #334155; padding-bottom: 10px; }
                h2 { color: #818cf8; margin-top: 30px; }
                .content { background: #1e293b; padding: 24px; border-radius: 12px; border: 1px solid #334155; margin-bottom: 24px; }
                .transcript { background: #1e293b; padding: 24px; border-radius: 12px; border: 1px solid #334155; }
                .segment { margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid #334155; }
                .speaker { font-weight: bold; color: #34d399; }
                .time { font-family: monospace; color: #94a3b8; font-size: 0.85em; }
            </style>
        </head>
        <body>
            <h1>\(note.title)</h1>
            <div class='content'>\(bodyHTML)</div>
            \(transcriptHTML)
        </body>
        </html>
        """
    }
}
