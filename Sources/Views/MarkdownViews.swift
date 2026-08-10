import SwiftUI

// MARK: - Word & Character Count Helper
func calculateWordAndCharCount(_ text: String) -> (words: Int, chars: Int) {
    let cleanText = text.replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    let chars = text.replacingOccurrences(of: "\\n", with: "\n").count
    if cleanText.isEmpty {
        return (0, 0)
    }
    let words = cleanText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    return (words, chars)
}

// MARK: - Code Block Card Component
struct CodeBlockView: View {
    let code: String
    let isDark: Bool
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CODE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(copied ? "Copied!" : "Copy")
                            .font(.caption2)
                    }
                    .foregroundColor(copied ? .emerald : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isDark ? Color(red: 226/255, green: 232/255, blue: 240/255) : Color(red: 15/255, green: 23/255, blue: 42/255))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.cardBackground(isDark))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

// MARK: - Markdown Grid Table Renderer Component
struct MarkdownTableView: View {
    let lines: [String]
    let isDark: Bool
    
    var parsedRows: [[String]] {
        lines.compactMap { line in
            let parts = line.components(separatedBy: "|")
            if parts.count < 3 { return nil }
            return parts[1..<(parts.count - 1)].map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }
    
    var body: some View {
        let rows = parsedRows
        if let header = rows.first {
            let dataRows = rows.dropFirst().filter { row in
                !row.allSatisfy { $0.allSatisfy { $0 == "-" || $0 == ":" } }
            }
            
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    ForEach(Array(header.enumerated()), id: \.offset) { colIdx, cell in
                        Text(cell)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(Color.sidebarBackground(isDark))
                
                Divider()
                    .background(Color.subtleBorder(isDark))
                
                // Data Rows
                ForEach(Array(dataRows.enumerated()), id: \.offset) { rowIdx, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                            Text(cell)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .background(rowIdx % 2 == 0 ? Color.clear : Color.cardBackground(isDark))
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 1)
            )
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Tokenizer & Markdown Renderer View
struct TextToken: Identifiable {
    let id = UUID()
    enum TokenType {
        case text(String)
        case wikiLink(String)
        case hashtag(String)
        case playLink(timeLabel: String, seconds: Double)
    }
    let type: TokenType
}

func parseLineTokens(_ line: String) -> [TextToken] {
    var tokens: [TextToken] = []
    var currentIndex = line.startIndex

    let pattern = "\\[\\[(.*?)\\]\\]|\\[(.*?)\\]\\(play://([0-9.]+)\\)|#([a-zA-Z0-9_]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [.init(type: .text(line))]
    }

    let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
    let matches = regex.matches(in: line, range: nsRange)

    for match in matches {
        guard let matchRange = Range(match.range, in: line) else { continue }
        
        if currentIndex < matchRange.lowerBound {
            let prefixText = String(line[currentIndex..<matchRange.lowerBound])
            if !prefixText.isEmpty {
                tokens.append(.init(type: .text(prefixText)))
            }
        }

        if let wikiRange = Range(match.range(at: 1), in: line), !line[wikiRange].isEmpty {
            let wikiTitle = String(line[wikiRange])
            tokens.append(.init(type: .wikiLink(wikiTitle)))
        } else if let labelRange = Range(match.range(at: 2), in: line),
                  let secRange = Range(match.range(at: 3), in: line),
                  let seconds = Double(line[secRange]) {
            let label = String(line[labelRange])
            tokens.append(.init(type: .playLink(timeLabel: label, seconds: seconds)))
        } else if let tagRange = Range(match.range(at: 4), in: line), !line[tagRange].isEmpty {
            let tag = String(line[tagRange])
            tokens.append(.init(type: .hashtag(tag)))
        }

        currentIndex = matchRange.upperBound
    }

    if currentIndex < line.endIndex {
        let suffixText = String(line[currentIndex..<line.endIndex])
        if !suffixText.isEmpty {
            tokens.append(.init(type: .text(suffixText)))
        }
    }

    return tokens
}

struct FormattedTextLine: View {
    let text: String
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let currentFolder: String
    let primaryAccent: Color
    let secondaryAccent: Color

    var tokens: [TextToken] {
        parseLineTokens(text)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(tokens) { token in
                switch token.type {
                case .text(let plainStr):
                    Text(plainStr)
                case .hashtag(let tag):
                    Text("#\(tag)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(primaryAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(4)
                case .wikiLink(let targetTitle):
                    Button(action: {
                        openOrCreateWikiLinkNote(targetTitle)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 9))
                            Text(targetTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(secondaryAccent.opacity(0.2))
                        .foregroundColor(secondaryAccent)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(secondaryAccent.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                case .playLink(let label, let seconds):
                    Button(action: {
                        playerVM.seek(to: seconds)
                        if !playerVM.isPlaying {
                            playerVM.togglePlayPause()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            Text(label)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryAccent.opacity(0.2))
                        .foregroundColor(primaryAccent)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openOrCreateWikiLinkNote(_ targetTitle: String) {
        let cleanTarget = targetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = notes.first(where: { $0.title.caseInsensitiveCompare(cleanTarget) == .orderedSame }) {
            selectedNoteId = existing.id
        } else {
            let newNote = NoteItem(
                title: cleanTarget,
                folder: currentFolder,
                content: "# \(cleanTarget)\n\nCreated automatically from wiki-link `[[\(cleanTarget)]]`.\n",
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
            notes.insert(newNote, at: 0)
            selectedNoteId = newNote.id
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}

enum MarkdownBlockType {
    case line(String)
    case table([String])
    case code(String)
}

func parseMarkdownBlocks(_ text: String) -> [MarkdownBlockType] {
    let lines = text.components(separatedBy: "\n")
    var blocks: [MarkdownBlockType] = []
    
    var index = 0
    while index < lines.count {
        let line = lines[index]
        
        // Code block check
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            var codeLines: [String] = []
            index += 1
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[index])
                index += 1
            }
            blocks.append(.code(codeLines.joined(separator: "\n")))
            index += 1
            continue
        }
        
        // Table check
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            var tableLines: [String] = []
            while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                tableLines.append(lines[index])
                index += 1
            }
            blocks.append(.table(tableLines))
            continue
        }
        
        blocks.append(.line(line))
        index += 1
    }
    
    return blocks
}

struct MarkdownRendererView: View {
    let markdown: String
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color

    var currentNoteFolder: String {
        if let id = selectedNoteId, let note = notes.first(where: { $0.id == id }) {
            return note.folder
        }
        return "General"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parseMarkdownBlocks(markdown).enumerated()), id: \.offset) { _, block in
                switch block {
                case .line(let line):
                    renderLine(line)
                case .table(let tableLines):
                    MarkdownTableView(lines: tableLines, isDark: isDark)
                case .code(let codeStr):
                    CodeBlockView(code: codeStr, isDark: isDark)
                }
            }
        }
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        if line.hasPrefix("# ") {
            Text(line.replacingOccurrences(of: "# ", with: ""))
                .font(.title)
                .fontWeight(.bold)
        } else if line.hasPrefix("## ") {
            Text(line.replacingOccurrences(of: "## ", with: ""))
                .font(.title2)
                .fontWeight(.semibold)
        } else if line.hasPrefix("### ") {
            Text(line.replacingOccurrences(of: "### ", with: ""))
                .font(.headline)
                .fontWeight(.medium)
        } else if line.hasPrefix("> ") {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(primaryAccent)
                    .frame(width: 3)
                FormattedTextLine(
                    text: line.replacingOccurrences(of: "> ", with: ""),
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.cardBackground(true))
            .cornerRadius(6)
        } else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") {
            let isChecked = line.hasPrefix("- [x] ")
            let clean = line.replacingOccurrences(of: "- [ ] ", with: "").replacingOccurrences(of: "- [x] ", with: "")
            HStack(alignment: .top, spacing: 8) {
                Button(action: { toggleCheckbox(targetLine: line) }) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundColor(isChecked ? primaryAccent : .secondary)
                }
                .buttonStyle(.plain)
                
                FormattedTextLine(
                    text: clean,
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
                .strikethrough(isChecked, color: .secondary)
            }
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                FormattedTextLine(
                    text: line.replacingOccurrences(of: "- ", with: ""),
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
            }
        } else {
            FormattedTextLine(
                text: line,
                notes: $notes,
                selectedNoteId: $selectedNoteId,
                playerVM: playerVM,
                currentFolder: currentNoteFolder,
                primaryAccent: primaryAccent,
                secondaryAccent: secondaryAccent
            )
        }
    }

    private func toggleCheckbox(targetLine: String) {
        guard let id = selectedNoteId, let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let currentContent = notes[idx].content
        let replacement = targetLine.hasPrefix("- [x] ") ? targetLine.replacingOccurrences(of: "- [x] ", with: "- [ ] ") : targetLine.replacingOccurrences(of: "- [ ] ", with: "- [x] ")
        if let range = currentContent.range(of: targetLine) {
            notes[idx].content.replaceSubrange(range, with: replacement)
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}
