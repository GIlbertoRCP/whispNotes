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
    
    var filteredResults: [NoteItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanQuery.isEmpty {
            return Array(notes.prefix(8))
        }
        return notes.filter { note in
            note.title.lowercased().contains(cleanQuery) ||
            note.folder.lowercased().contains(cleanQuery) ||
            note.content.lowercased().contains(cleanQuery) ||
            note.transcript.contains(where: { $0.text.lowercased().contains(cleanQuery) || $0.speaker.lowercased().contains(cleanQuery) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(primaryAccent)
                    .font(.title3)
                TextField("Search notes, folders, or transcript keywords...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onChange(of: query) { _, _ in
                        selectionIndex = 0
                    }
                Spacer()
                Button(action: { isOpen = false }) {
                    Text("Esc")
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(4)
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
                            description: query.isEmpty ? "Start typing to search notes..." : "No notes matched \"\(query)\"."
                        )
                        .frame(height: 180)
                    } else {
                        ForEach(Array(filteredResults.enumerated()), id: \.element.id) { idx, note in
                            HStack {
                                Image(systemName: note.isStandalone ? "doc.text" : "waveform")
                                    .foregroundColor(idx == selectionIndex ? primaryAccent : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text("Folder: \(note.folder) • \(note.timestamp, style: .date)")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    if let snippet = snippetMatch(for: note, query: query) {
                                        Text(snippet)
                                            .font(.system(size: 9))
                                            .italic()
                                            .foregroundColor(primaryAccent.opacity(0.8))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if idx == selectionIndex {
                                    Text("Jump ↵")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(primaryAccent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(primaryAccent.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(idx == selectionIndex ? primaryAccent.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
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
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(3)
                    Text("Navigate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Text("↵")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(3)
                    Text("Select")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Text("esc")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(3)
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
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .fill(Color.panelBackground(isDark).opacity(0.85))
                )
        )
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
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

    private func snippetMatch(for note: NoteItem, query: String) -> String? {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        
        if let range = note.content.lowercased().range(of: clean) {
            let start = note.content.index(range.lowerBound, offsetBy: -15, limitedBy: note.content.startIndex) ?? note.content.startIndex
            let end = note.content.index(range.upperBound, offsetBy: 35, limitedBy: note.content.endIndex) ?? note.content.endIndex
            let excerpt = String(note.content[start..<end]).replacingOccurrences(of: "\n", with: " ")
            return "... \(excerpt) ..."
        }
        
        if let seg = note.transcript.first(where: { $0.text.lowercased().contains(clean) }) {
            return "\(seg.speaker): \"\(seg.text)\""
        }
        
        return nil
    }
}

// MARK: - Format Time Helper
func formatTime(_ seconds: Double) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", mins, secs)
}
