import SwiftUI

// MARK: - Transcript Panel View (With Real-time Search Filter)
struct TranscriptPanelView: View {
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    @ObservedObject var playerVM: AudioPlayerViewModel
    @Binding var width: Double
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @State private var renamingSpeaker: String? = nil
    @State private var newSpeakerName: String = ""
    @State private var searchQuery: String = ""

    var filteredTranscript: [TranscriptSegment] {
        let clean = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.isEmpty {
            return note.transcript
        }
        return note.transcript.filter {
            $0.text.lowercased().contains(clean) || $0.speaker.lowercased().contains(clean)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Diarized Transcript")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(filteredTranscript.count) segs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Real-time Transcript Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Search transcript keywords...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.caption)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.cardBackground(isDark))
                .cornerRadius(6)
            }
            .padding(14)
            .background(Color.panelBackground(isDark))

            Divider()
                .background(Color.subtleBorder(isDark))

            // Scroll list of segments
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(filteredTranscript.enumerated()), id: \.element.id) { idx, seg in
                            let isActive = idx == playerVM.activeSegmentIndex
                            let isMe = seg.speaker == "Speaker 1"
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    // Speaker tag with Popover Renamer
                                    Button(action: {
                                        renamingSpeaker = seg.speaker
                                        newSpeakerName = seg.speaker
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 11))
                                            Text(seg.speaker)
                                                .font(.system(size: 11, weight: .bold))
                                            Image(systemName: "pencil")
                                                .font(.system(size: 8))
                                        }
                                        .foregroundColor(isMe ? secondaryAccent : .emerald)
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: Binding(
                                        get: { renamingSpeaker == seg.speaker },
                                        set: { if !$0 { renamingSpeaker = nil } }
                                    )) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Rename Speaker Globally")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                            TextField("Speaker Name...", text: $newSpeakerName, onCommit: {
                                                renameSpeakerGlobally(oldName: seg.speaker, newName: newSpeakerName)
                                                renamingSpeaker = nil
                                            })
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 160)
                                            
                                            HStack {
                                                Spacer()
                                                Button("Save") {
                                                    renameSpeakerGlobally(oldName: seg.speaker, newName: newSpeakerName)
                                                    renamingSpeaker = nil
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.small)
                                            }
                                        }
                                        .padding()
                                    }
                                    
                                    Spacer()
                                    
                                    // Seek Moment Play button
                                    Button(action: { playerVM.seek(to: seg.startTime) }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 8))
                                            Text(formatTime(seg.startTime))
                                                .font(.system(size: 10, design: .monospaced))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Copy Quote to Editor Button
                                    Button(action: { insertQuoteAtCursor(text: seg.text, start: seg.startTime) }) {
                                        Image(systemName: "quote.bubble")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .padding(4)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy quote to editor")
                                }
                                
                                Text(seg.text)
                                    .font(.subheadline)
                                    .foregroundColor(isActive ? (isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255)) : .secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(isActive ? primaryAccent.opacity(0.12) : Color.cardBackground(isDark))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isActive ? primaryAccent.opacity(0.4) : Color.subtleBorder(isDark), lineWidth: 1)
                            )
                            .id(idx)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: playerVM.activeSegmentIndex) { _, newIndex in
                    if newIndex != -1 {
                        withAnimation {
                            scrollProxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color.sidebarBackground(isDark))
    }
    
    private func renameSpeakerGlobally(oldName: String, newName: String) {
        let cleanNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNew.isEmpty && cleanNew != oldName else { return }
        for i in 0..<note.transcript.count {
            if note.transcript[i].speaker == oldName {
                note.transcript[i].speaker = cleanNew
            }
        }
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
            NotesDataManager.shared.saveNotesImmediately(notes)
        }
    }

    private func insertQuoteAtCursor(text: String, start: Double) {
        let timestampStr = formatTime(start)
        let secondsStr = String(format: "%.1f", start)
        let quote = "\n> \"\(text)\" [\(timestampStr)](play://\(secondsStr))\n"
        note.content += quote
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}
