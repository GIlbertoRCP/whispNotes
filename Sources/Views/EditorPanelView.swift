import SwiftUI

// MARK: - Editor Panel View
struct EditorPanelView: View {
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14.0
    @AppStorage("editorFontDesign") private var editorFontDesign: String = "Monospaced"
    
    @State private var editMode: EditModeType = .split
    @State private var localContent: String = ""
    @State private var saveTimer: Timer? = nil
    @State private var showBacklinks = true
    @State private var showAIAssistantPopover = false
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
            // Top Status Header Bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(primaryAccent)
                        .font(.subheadline)
                    Text("SHORTHAND NOTES")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.secondary)
                }
                
                // TOC Heading Outline Drawer Button
                if !headingOutline.isEmpty {
                    Button(action: { showTOCDrawer.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet.indent")
                                .font(.caption)
                                .foregroundColor(secondaryAccent)
                            Text("Outline (\(headingOutline.count))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(secondaryAccent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(secondaryAccent.opacity(0.15))
                        .cornerRadius(6)
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
                
                Spacer()
                
                Text("\(stats.words) words  |  \(stats.chars) chars")
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
                
                // AI Study Assistant Popover Button
                Button(action: { showAIAssistantPopover.toggle() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                        Text("AI Assistant")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(primaryAccent.opacity(0.12))
                    .foregroundColor(primaryAccent)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(primaryAccent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAIAssistantPopover) {
                    AIStudyAssistantView(note: note, isDark: isDark, primaryAccent: primaryAccent, secondaryAccent: secondaryAccent, onInsertSummary: { summaryBlock in
                        localContent += summaryBlock
                        note.content = localContent
                        NotesDataManager.shared.saveNotes(notes)
                        showAIAssistantPopover = false
                    })
                }

                // Edit | Split | Preview Mode Picker
                HStack(spacing: 0) {
                    ForEach(EditModeType.allCases, id: \.self) { mode in
                        Button(action: { editMode = mode }) {
                            Text(mode.rawValue)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(editMode == mode ? primaryAccent.opacity(0.18) : Color.clear)
                                .foregroundColor(editMode == mode ? primaryAccent : .secondary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.cardBackground(isDark))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                )

                Text("Auto-saves")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.panelBackground(isDark))
            
            Divider()
                .background(Color.subtleBorder(isDark))

            // Markdown Formatting Toolbar
            if editMode == .edit || editMode == .split {
                HStack(spacing: 12) {
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

                    Spacer()
                }
                .padding(.horizontal, 16)
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
                    .onChange(of: localContent) { _, newContent in
                        handleAutoSave(newContent)
                    }
            } else if editMode == .split {
                HStack(spacing: 0) {
                    TextEditor(text: $localContent)
                        .font(.system(size: CGFloat(editorFontSize), design: selectedFontDesign))
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .background(Color.panelBackground(isDark))
                        .onChange(of: localContent) { _, newContent in
                            handleAutoSave(newContent)
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
            if !incomingBacklinks.isEmpty || !outgoingWikiLinks.isEmpty {
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
}
