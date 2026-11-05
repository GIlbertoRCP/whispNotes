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
        let clean = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return note.transcript
        }
        return note.transcript.filter {
            $0.text.localizedCaseInsensitiveContains(clean) || $0.speaker.localizedCaseInsensitiveContains(clean)
        }
    }

    /// The playing segment's id. activeSegmentIndex points into the full transcript, not the filtered list.
    private var activeSegmentId: UUID? {
        let index = playerVM.activeSegmentIndex
        return note.transcript.indices.contains(index) ? note.transcript[index].id : nil
    }

    /// Speakers in order of first appearance, so colors survive a rename.
    private var speakerOrder: [String] {
        var seen: [String] = []
        for seg in note.transcript where !seen.contains(seg.speaker) { seen.append(seg.speaker) }
        return seen
    }

    private func speakerColor(_ speaker: String) -> Color {
        let palette: [Color] = [
            secondaryAccent,
            isDark ? Color(red: 52/255, green: 211/255, blue: 153/255) : Color(red: 5/255, green: 150/255, blue: 105/255),
            isDark ? Color(red: 96/255, green: 165/255, blue: 250/255) : Color(red: 37/255, green: 99/255, blue: 235/255),
            isDark ? Color(red: 251/255, green: 191/255, blue: 36/255) : Color(red: 180/255, green: 83/255, blue: 9/255)
        ]
        let index = speakerOrder.firstIndex(of: speaker) ?? 0
        return palette[index % palette.count]
    }

    private var segmentCountLabel: String {
        let count = filteredTranscript.count
        if searchQuery.isEmpty { return count == 1 ? "1 segment" : "\(count) segments" }
        return "\(count) of \(note.transcript.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Transcript")
                        .font(.headline)

                    Spacer()

                    Text(segmentCountLabel)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(Color.appTextSecondary(isDark))
                }
                
                // Real-time Transcript Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Search transcript", text: $searchQuery)
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
                .cornerRadius(AppRadius.sm)
            }
            .padding(AppSpacing.md)
            .background(Color.panelBackground(isDark))

            Divider()
                .background(Color.subtleBorder(isDark))

            // Scroll list of segments
            if note.transcript.isEmpty {
                WhispEmptyStateView(
                    icon: "waveform.slash",
                    title: "No Transcript",
                    description: "The recording is saved, but no speech was transcribed. You can still play it back."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTranscript.isEmpty {
                WhispEmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Matches",
                    description: "No segment mentions “\(searchQuery)”."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                segmentList
            }
        }
        .background(Color.sidebarBackground(isDark))
    }
    
    private var segmentList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(filteredTranscript) { seg in
                        segmentRow(seg, isActive: seg.id == activeSegmentId)
                            .id(seg.id)
                    }
                }
                .padding(AppSpacing.md)
            }
            .onChange(of: playerVM.activeSegmentIndex) { _, _ in
                guard let id = activeSegmentId, filteredTranscript.contains(where: { $0.id == id }) else { return }
                withAnimation(AppAnimation.panel) {
                    scrollProxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    func segmentRow(_ seg: TranscriptSegment, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                // Speaker tag with popover renamer
                Button(action: {
                    renamingSpeaker = seg.speaker
                    newSpeakerName = seg.speaker
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Circle()
                            .fill(speakerColor(seg.speaker))
                            .frame(width: 6, height: 6)
                        Text(seg.speaker)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(speakerColor(seg.speaker))
                }
                .buttonStyle(.plain)
                .help("Rename speaker")
                .popover(isPresented: Binding(
                    get: { renamingSpeaker == seg.speaker },
                    set: { if !$0 { renamingSpeaker = nil } }
                )) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Rename Speaker")
                            .font(.headline)
                        Text("Updates every segment by “\(seg.speaker)” in this note.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Speaker name", text: $newSpeakerName, onCommit: {
                            renameSpeakerGlobally(oldName: seg.speaker, newName: newSpeakerName)
                            renamingSpeaker = nil
                        })
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)

                        HStack {
                            Spacer()
                            Button("Cancel") { renamingSpeaker = nil }
                                .keyboardShortcut(.cancelAction)
                            Button("Rename") {
                                renameSpeakerGlobally(oldName: seg.speaker, newName: newSpeakerName)
                                renamingSpeaker = nil
                            }
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.borderedProminent)
                        }
                        .controlSize(.small)
                    }
                    .padding(AppSpacing.lg)
                }

                Spacer(minLength: 0)

                // Play from this moment (matches timestamp chips in the preview)
                Button(action: {
                    playerVM.seek(to: seg.startTime)
                    if !playerVM.isPlaying { playerVM.togglePlayPause() }
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: isActive && playerVM.isPlaying ? "speaker.wave.2.fill" : "play.fill")
                            .font(.system(size: 9))
                        Text(formatTime(seg.startTime))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(primaryAccent.opacity(isActive ? 0.2 : 0.1))
                    .foregroundColor(primaryAccent)
                    .cornerRadius(AppRadius.xs)
                }
                .buttonStyle(.plain)
                .help("Play from \(formatTime(seg.startTime))")

                // Insert quote into the note
                Button(action: { insertQuoteAtCursor(text: seg.text, start: seg.startTime) }) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary(isDark))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Add as a quote at the end of the note")
            }

            Text(seg.text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundColor(isActive ? Color.appText(isDark) : Color.appTextBody(isDark))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.md)
        .background(isActive ? primaryAccent.opacity(0.08) : Color.cardBackground(isDark))
        .overlay(alignment: .leading) {
            // Drawn as an overlay so the text doesn't shift when a segment becomes active.
            if isActive {
                Rectangle()
                    .fill(primaryAccent)
                    .frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(isActive ? primaryAccent.opacity(0.3) : Color.subtleBorder(isDark), lineWidth: 1)
        )
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
