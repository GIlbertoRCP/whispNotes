import SwiftUI

// MARK: - Command Palette (⌘K / ⌘O Quick Switcher)
struct CommandPaletteView: View {
    let notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @Binding var isOpen: Bool
    let isDark: Bool
    let primaryAccent: Color
    
    @State private var query = CommandLine.arguments.contains("--command-palette") ? "Machine Learning" : ""
    @State private var selectionIndex = 0
    
    /// Trashed notes stay out of the switcher, matching Vault Search; newest first.
    var filteredResults: [NoteItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let live = notes
            .filter { $0.folder != "Trash" }
            .sorted { $0.timestamp > $1.timestamp }
        if cleanQuery.isEmpty {
            return Array(live.prefix(8))
        }
        return live.filter { note in
            note.title.localizedCaseInsensitiveContains(cleanQuery) ||
            note.folder.localizedCaseInsensitiveContains(cleanQuery) ||
            note.content.localizedCaseInsensitiveContains(cleanQuery) ||
            note.transcript.contains(where: { $0.text.localizedCaseInsensitiveContains(cleanQuery) || $0.speaker.localizedCaseInsensitiveContains(cleanQuery) })
        }
    }

    private func iconName(for note: NoteItem) -> String {
        if note.pptxPath != nil { return "sparkles.tv" }
        if note.pdfPath != nil { return "doc.richtext" }
        if note.audioPath != nil { return "waveform" }
        return "doc.text"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(primaryAccent)
                    .font(.title3)
                TextField("Search notes, folders and transcripts", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onChange(of: query) { _, _ in
                        selectionIndex = 0
                    }
                Spacer()
                Button(action: { isOpen = false }) {
                    Text("Esc")
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(AppRadius.xs)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.sidebarBackground(isDark))

            Divider()
                .background(Color.subtleBorder(isDark))

            // Results List
            ScrollViewReader { scrollProxy in
                List {
                    if filteredResults.isEmpty {
                        WhispEmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Matching Notes",
                            description: query.isEmpty ? "Start typing to search your notes." : "No notes match “\(query)”."
                        )
                        .frame(height: 180)
                    } else {
                        ForEach(Array(filteredResults.enumerated()), id: \.element.id) { idx, note in
                            HStack {
                                Image(systemName: iconName(for: note))
                                    .foregroundColor(idx == selectionIndex ? primaryAccent : .secondary)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.appText(isDark))
                                        .lineLimit(1)
                                    Text("\(note.folder) · \(note.timestamp.formatted(.dateTime.month(.abbreviated).day().year()))")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.appTextSecondary(isDark))
                                    if let snippet = snippetMatch(for: note, query: query) {
                                        Text(snippet)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.appTextMuted(isDark))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                }
                                Spacer()
                                if idx == selectionIndex {
                                    Text("Open ↵")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(primaryAccent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(primaryAccent.opacity(0.15))
                                        .cornerRadius(AppRadius.xs)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(idx == selectionIndex ? primaryAccent.opacity(0.12) : Color.clear)
                            .cornerRadius(AppRadius.sm)
                            .contentShape(Rectangle())
                            .id(idx)
                            .onTapGesture {
                                selectedNoteId = note.id
                                isOpen = false
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .frame(height: 280)
                .onChange(of: selectionIndex) { _, newIdx in
                    scrollProxy.scrollTo(newIdx, anchor: .center)
                }
            }
            
            // Footer Navigation Hint
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("↑↓")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(AppRadius.xs)
                    Text("Navigate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Text("↵")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(AppRadius.xs)
                    Text("Select")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Text("esc")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(AppRadius.xs)
                    Text("Dismiss")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 540)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xl)
                        .fill(Color.panelBackground(isDark).opacity(0.85))
                )
        )
        .cornerRadius(AppRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
        .onKeyPress(.downArrow) {
            if !filteredResults.isEmpty {
                selectionIndex = min(selectionIndex + 1, filteredResults.count - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if !filteredResults.isEmpty {
                selectionIndex = max(selectionIndex - 1, 0)
            }
            return .handled
        }
        .onKeyPress(.return) {
            if selectionIndex >= 0 && selectionIndex < filteredResults.count {
                selectedNoteId = filteredResults[selectionIndex].id
                isOpen = false
            }
            return .handled
        }
        .onKeyPress(.escape) {
            isOpen = false
            return .handled
        }
    }

    /// The matching line, with markdown syntax stripped and trimmed to whole words around the match.
    private func snippetMatch(for note: NoteItem, query: String) -> String? {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !note.title.localizedCaseInsensitiveContains(clean) else { return nil }

        if let line = note.content
            .components(separatedBy: .newlines)
            .first(where: { $0.localizedCaseInsensitiveContains(clean) }) {
            return Self.excerpt(around: clean, in: Self.plainText(line))
        }

        if let seg = note.transcript.first(where: { $0.text.localizedCaseInsensitiveContains(clean) }) {
            return "\(formatTime(seg.startTime))  \(seg.speaker): \(Self.excerpt(around: clean, in: seg.text))"
        }

        return nil
    }

    private static func plainText(_ markdown: String) -> String {
        var text = markdown
        text = text.replacingOccurrences(of: #"\[\[([^\]]+)\]\]"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"^\s*(#{1,6}|>|[-*+]( \[[ xX]\])?|\d+\.)\s+"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[*_`|]"#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static func excerpt(around query: String, in text: String, radius: Int = 40) -> String {
        guard let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(text.prefix(radius * 2))
        }
        var start = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        var end = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        // Snap outward to word boundaries so words aren't cut in half.
        while start > text.startIndex, !text[text.index(before: start)].isWhitespace { start = text.index(before: start) }
        while end < text.endIndex, !text[end].isWhitespace { end = text.index(after: end) }
        let body = text[start..<end].trimmingCharacters(in: .whitespaces)
        return (start > text.startIndex ? "…" : "") + body + (end < text.endIndex ? "…" : "")
    }
}

// MARK: - Format Time Helper
func formatTime(_ seconds: Double) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", mins, secs)
}
