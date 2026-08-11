import SwiftUI

// MARK: - Editor Panel View
struct EditorPanelView: View {
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    @Binding var editMode: EditModeType
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14.0
    @AppStorage("editorFontDesign") private var editorFontDesign: String = "Monospaced"
    
    @State private var localContent: String = ""
    @State private var saveTimer: Timer? = nil
    @State private var showBacklinks = true
    @State private var showTOCDrawer = false

    private var selectedFontDesign: Font.Design {
        switch editorFontDesign {
        case "Sans-Serif": return .default
        case "Serif": return .serif
        default: return .monospaced
        }
    }

    private var stats: (words: Int, chars: Int) {
        calculateWordAndCharCount(localContent)
    }

    var headingOutline: [String] {
        localContent.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
    }

    var incomingBacklinks: [NoteItem] {
        let currentTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !currentTitle.isEmpty else { return [] }
        return notes.filter { n in
            n.id != note.id && n.content.lowercased().contains("[[\(currentTitle)]]")
        }
    }

    var unlinkedMentions: [NoteItem] {
        let currentTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentTitle.count > 2 else { return [] }
        let currentLower = currentTitle.lowercased()
        return notes.filter { n in
            if n.id == note.id { return false }
            let lowerContent = n.content.lowercased()
            let hasPlain = lowerContent.contains(currentLower)
            let hasWiki = lowerContent.contains("[[\(currentLower)]]")
            return hasPlain && !hasWiki
        }
    }

    var outgoingWikiLinks: [String] {
        let pattern = "\\[\\[(.*?)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let line = note.content
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: nsRange)
        var links: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: line) {
                let link = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !link.isEmpty && !links.contains(link) {
                    links.append(link)
                }
            }
        }
        return links
    }

    var body: some View {
        VStack(spacing: 0) {
            // Streamlined Markdown Formatting & Document Stats Bar
            if editMode == .edit || editMode == .split {
                HStack(spacing: 10) {
                    Group {
                        Button(action: { insertMarkdown("**", "**") }) {
                            Text("B")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Bold (**text**)")

                        Button(action: { insertMarkdown("*", "*") }) {
                            Text("I")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .italic()
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Italic (*text*)")

                        Button(action: { insertMarkdown("\n# ", "") }) {
                            Text("#")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Heading (# Heading)")

                        Rectangle()
                            .fill(Color.subtleBorder(isDark))
                            .frame(width: 1, height: 16)

                        Button(action: { insertMarkdown("\n- ", "") }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Bullet List (- Item)")

                        Button(action: { insertMarkdown("\n- [ ] ", "") }) {
                            Image(systemName: "checkmark.square")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Checklist Task (- [ ] Task)")

                        Button(action: { insertMarkdown("`", "`") }) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 11))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Code Snippet (`code`)")

                        Button(action: { insertMarkdown("[[", "]]") }) {
                            Text("[ [ ] ]")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Wiki Link ([[Note Title]])")

                        Button(action: { insertMarkdown("\n| Header 1 | Header 2 |\n| --- | --- |\n| Item 1 | Item 2 |\n", "") }) {
                            Image(systemName: "tablecells")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Insert Table Template")

                        Button(action: { insertMarkdown("\n> ", "") }) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Blockquote (> Quote)")
                    }

                    Spacer()

                    // Document Outline & Word Counter
                    if !headingOutline.isEmpty {
                        Button(action: { showTOCDrawer.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet.indent")
                                    .font(.caption2)
                                    .foregroundColor(secondaryAccent)
                                Text("Outline (\(headingOutline.count))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(secondaryAccent)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(secondaryAccent.opacity(0.15))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showTOCDrawer) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Table of Contents")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                ForEach(headingOutline, id: \.self) { heading in
                                    Text(heading)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(12)
                        }
                    }

                    Text("\(stats.words) words • \(stats.chars) chars")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.sidebarBackground(isDark))

                Divider()
                    .background(Color.subtleBorder(isDark))
            }
            
            // Editor Body View (Single Edit, Split View, or Full Preview)
            if editMode == .edit {
                TextEditor(text: $localContent)
                    .font(.system(size: CGFloat(editorFontSize), design: selectedFontDesign))
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .background(Color.panelBackground(isDark))
                    .onChange(of: localContent) { oldContent, newContent in
                        let formatted = processMarkdownAutoFormatting(oldText: oldContent, newText: newContent)
                        if formatted != newContent {
                            localContent = formatted
                        }
                        handleAutoSave(formatted)
                    }
            } else if editMode == .split {
                HStack(spacing: 0) {
                    TextEditor(text: $localContent)
                        .font(.system(size: CGFloat(editorFontSize), design: selectedFontDesign))
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .background(Color.panelBackground(isDark))
                        .onChange(of: localContent) { oldContent, newContent in
                            let formatted = processMarkdownAutoFormatting(oldText: oldContent, newText: newContent)
                            if formatted != newContent {
                                localContent = formatted
                            }
                            handleAutoSave(formatted)
                        }
                    
                    Divider()
                        .background(Color.subtleBorder(isDark))
                    
                    ScrollView {
                        MarkdownRendererView(
                            markdown: localContent.replacingOccurrences(of: "\\n", with: "\n"),
                            notes: $notes,
                            selectedNoteId: $selectedNoteId,
                            playerVM: playerVM,
                            isDark: isDark,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                    .background(Color.panelBackground(isDark))
                }
            } else {
                ScrollView {
                    MarkdownRendererView(
                        markdown: localContent.replacingOccurrences(of: "\\n", with: "\n"),
                        notes: $notes,
                        selectedNoteId: $selectedNoteId,
                        playerVM: playerVM,
                        isDark: isDark,
                        primaryAccent: primaryAccent,
                        secondaryAccent: secondaryAccent
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .background(Color.panelBackground(isDark))
            }

            // Collapsible Obsidian-Style Backlinks Drawer
            if !incomingBacklinks.isEmpty || !unlinkedMentions.isEmpty || !outgoingWikiLinks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(secondaryAccent)
                        Text("Knowledge Connections & Backlinks")
                            .font(.caption)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: { showBacklinks.toggle() }) {
                            Image(systemName: showBacklinks ? "chevron.down" : "chevron.up")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showBacklinks {
                        HStack(alignment: .top, spacing: 20) {
                            if !incomingBacklinks.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("LINKED REFERENCES (\(incomingBacklinks.count))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(incomingBacklinks) { backlinkNote in
                                        Button(action: { selectedNoteId = backlinkNote.id }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "link")
                                                    .font(.system(size: 9))
                                                Text(backlinkNote.title)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(secondaryAccent.opacity(0.15))
                                            .foregroundColor(secondaryAccent)
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if !unlinkedMentions.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("UNLINKED MENTIONS (\(unlinkedMentions.count))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(unlinkedMentions) { unlinkedNote in
                                        HStack(spacing: 6) {
                                            Button(action: { selectedNoteId = unlinkedNote.id }) {
                                                Text(unlinkedNote.title)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button(action: { linkUnlinkedMention(in: unlinkedNote) }) {
                                                Text("+ Link")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(primaryAccent.opacity(0.18))
                                                    .foregroundColor(primaryAccent)
                                                    .cornerRadius(4)
                                            }
                                            .buttonStyle(.plain)
                                            .help("Convert text mention in '\(unlinkedNote.title)' into [[link]]")
                                        }
                                    }
                                }
                            }
                            
                            if !outgoingWikiLinks.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("OUTGOING LINKS (\(outgoingWikiLinks.count))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(outgoingWikiLinks, id: \.self) { linkTitle in
                                        Button(action: { openOrCreateWikiLinkNote(linkTitle) }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.up.right.square")
                                                    .font(.system(size: 9))
                                                Text(linkTitle)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(primaryAccent.opacity(0.15))
                                            .foregroundColor(primaryAccent)
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.sidebarBackground(isDark))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            localContent = note.content.replacingOccurrences(of: "\\n", with: "\n")
        }
        .onChange(of: note.id) { _, _ in
            saveTimer?.invalidate()
            localContent = note.content.replacingOccurrences(of: "\\n", with: "\n")
        }
        .onChange(of: note.content) { _, externalContent in
            let clean = externalContent.replacingOccurrences(of: "\\n", with: "\n")
            if localContent != clean {
                localContent = clean
            }
        }
        .onDisappear {
            saveTimer?.invalidate()
            let clean = localContent.replacingOccurrences(of: "\\n", with: "\n")
            if note.content != clean {
                note.content = clean
                NotesDataManager.shared.saveNotes(notes)
            }
        }
    }

    private func handleAutoSave(_ newContent: String) {
        if newContent != note.content {
            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                Task { @MainActor in
                    let clean = newContent.replacingOccurrences(of: "\\n", with: "\n")
                    if note.content != clean {
                        note.content = clean
                        NotesDataManager.shared.saveNotes(notes)
                    }
                }
            }
        }
    }

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        localContent += "\(prefix)text\(suffix)"
        let clean = localContent.replacingOccurrences(of: "\\n", with: "\n")
        note.content = clean
        NotesDataManager.shared.saveNotes(notes)
    }

    private func openOrCreateWikiLinkNote(_ targetTitle: String) {
        let cleanTarget = targetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = notes.first(where: { $0.title.caseInsensitiveCompare(cleanTarget) == .orderedSame }) {
            selectedNoteId = existing.id
        } else {
            let newNote = NoteItem(
                title: cleanTarget,
                folder: note.folder,
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

    private func processMarkdownAutoFormatting(oldText: String, newText: String) -> String {
        guard newText.count > oldText.count else { return newText }
        
        var formatted = newText
        
        if formatted.hasPrefix("* ") {
            formatted = "• " + String(formatted.dropFirst(2))
        }
        formatted = formatted.replacingOccurrences(of: "\n* ", with: "\n• ")
        
        if newText.hasSuffix("\n") && !oldText.hasSuffix("\n") {
            let lines = oldText.components(separatedBy: "\n")
            if let lastLine = lines.last {
                let trimmed = lastLine.trimmingCharacters(in: .whitespaces)
                if trimmed == "•" || trimmed == "• " || trimmed == "-" || trimmed == "- " || trimmed == "- [ ]" || trimmed == "- [ ] " || trimmed == "- [x]" || trimmed == "- [x] " {
                    var modifiedLines = lines
                    modifiedLines.removeLast()
                    formatted = modifiedLines.joined(separator: "\n") + "\n"
                } else if lastLine.hasPrefix("• ") {
                    formatted += "• "
                } else if lastLine.hasPrefix("- [ ] ") || lastLine.hasPrefix("- [x] ") {
                    formatted += "- [ ] "
                } else if lastLine.hasPrefix("- ") {
                    formatted += "- "
                } else if let match = parseNumberedListPrefix(trimmed) {
                    if trimmed == "\(match.number)." || trimmed == "\(match.number). " {
                        var modifiedLines = lines
                        modifiedLines.removeLast()
                        formatted = modifiedLines.joined(separator: "\n") + "\n"
                    } else {
                        formatted += "\(match.number + 1). "
                    }
                }
            }
        }
        
        return formatted
    }

    private func parseNumberedListPrefix(_ line: String) -> (number: Int, prefix: String)? {
        let pattern = "^(\\d+)\\.\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let numberRange = Range(match.range(at: 1), in: line),
              let num = Int(line[numberRange]) else {
            return nil
        }
        return (num, "\(num). ")
    }

    private func linkUnlinkedMention(in targetNote: NoteItem) {
        let currentTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = notes.firstIndex(where: { $0.id == targetNote.id }) else { return }
        let pattern = "(?<!\\[\\[)(" + NSRegularExpression.escapedPattern(for: currentTitle) + ")(?!\\]\\])"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsRange = NSRange(notes[idx].content.startIndex..., in: notes[idx].content)
            notes[idx].content = regex.stringByReplacingMatches(in: notes[idx].content, range: nsRange, withTemplate: "[[$1]]")
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}
