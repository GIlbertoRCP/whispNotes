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
    @AppStorage("editorSplitRatio") private var splitRatio: Double = 0.5
    
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

    @State private var cachedStats: (words: Int, chars: Int) = (0, 0)
    @State private var cachedHeadingOutline: [String] = []
    @State private var cachedIncomingBacklinks: [NoteItem] = []
    @State private var cachedUnlinkedMentions: [NoteItem] = []
    @State private var cachedOutgoingWikiLinks: [String] = []
    @State private var showWikiAutocomplete = false
    @State private var wikiQuery = ""

    private var stats: (words: Int, chars: Int) {
        cachedStats
    }

    var headingOutline: [String] {
        cachedHeadingOutline
    }

    var incomingBacklinks: [NoteItem] {
        cachedIncomingBacklinks
    }

    var unlinkedMentions: [NoteItem] {
        cachedUnlinkedMentions
    }

    var outgoingWikiLinks: [String] {
        cachedOutgoingWikiLinks
    }

    var resolvedPDFURL: URL? {
        NotesDataManager.shared.resolveAttachmentURL(note.pdfPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Streamlined Markdown Formatting & Document Stats Bar
            if editMode == .edit || editMode == .split {
                HStack(spacing: 8) {
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

                    if let pdfURL = resolvedPDFURL, editMode == .edit {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.richtext.fill")
                                .font(.system(size: 10))
                                .foregroundColor(primaryAccent)
                            Text(pdfURL.lastPathComponent)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                            Button("View PDF") { editMode = .pdf }
                                .font(.system(size: 9, weight: .bold))
                                .buttonStyle(.plain)
                                .foregroundColor(primaryAccent)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(4)
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
            
            // Editor Body View (Single Edit, Split View, Full Preview, or Native PDF Viewer)
            if editMode == .pdf, let pdfURL = resolvedPDFURL {
                PDFDocumentViewerView(
                    pdfURL: pdfURL,
                    note: $note,
                    notes: $notes,
                    isDark: isDark,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    onDetachPDF: {
                        note.pdfPath = nil
                        editMode = .edit
                        NotesDataManager.shared.saveNotes(notes)
                    },
                    onQuoteSelection: { _ in
                        localContent = note.content
                    }
                )
            } else if editMode == .edit {
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
                GeometryReader { splitGeo in
                    let totalWidth = splitGeo.size.width
                    let minPanelWidth: CGFloat = 200
                    let effectiveLeftWidth = max(minPanelWidth, min(totalWidth - minPanelWidth, totalWidth * CGFloat(splitRatio)))
                    let effectiveRightWidth = max(minPanelWidth, totalWidth - effectiveLeftWidth - 6)

                    HStack(spacing: 0) {
                        // Left: Markdown Text Editor
                        TextEditor(text: $localContent)
                            .font(.system(size: CGFloat(editorFontSize), design: selectedFontDesign))
                            .scrollContentBackground(.hidden)
                            .padding(16)
                            .background(Color.panelBackground(isDark))
                            .frame(width: effectiveLeftWidth)
                            .onChange(of: localContent) { oldContent, newContent in
                                let formatted = processMarkdownAutoFormatting(oldText: oldContent, newText: newContent)
                                if formatted != newContent {
                                    localContent = formatted
                                }
                                handleAutoSave(formatted)
                            }
                        
                        // Interactive Draggable Split Divider
                        ZStack {
                            Rectangle()
                                .fill(Color.subtleBorder(isDark))
                                .frame(width: 1)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.cardBackground(isDark))
                                .frame(width: 6, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                                )
                        }
                        .frame(width: 6)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { val in
                                    let newRatio = Double(val.location.x + effectiveLeftWidth) / Double(totalWidth)
                                    splitRatio = max(0.2, min(0.8, newRatio))
                                }
                        )
                        .onHover { inside in
                            if inside {
                                NSCursor.resizeLeftRight.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        
                        // Right: Native PDF Document Viewer (if attached) or Markdown Preview
                        if let pdfURL = resolvedPDFURL {
                            PDFDocumentViewerView(
                                pdfURL: pdfURL,
                                note: $note,
                                notes: $notes,
                                isDark: isDark,
                                primaryAccent: primaryAccent,
                                secondaryAccent: secondaryAccent,
                                onDetachPDF: {
                                    note.pdfPath = nil
                                    NotesDataManager.shared.saveNotes(notes)
                                },
                                onQuoteSelection: { _ in
                                    localContent = note.content
                                }
                            )
                            .frame(width: effectiveRightWidth)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading) {
                                    MarkdownRendererView(
                                        markdown: localContent.replacingOccurrences(of: "\\n", with: "\n"),
                                        notes: $notes,
                                        selectedNoteId: $selectedNoteId,
                                        playerVM: playerVM,
                                        isDark: isDark,
                                        primaryAccent: primaryAccent,
                                        secondaryAccent: secondaryAccent
                                    )
                                    .frame(maxWidth: 720, alignment: .leading)
                                }
                                .padding(24)
                            }
                            .frame(width: effectiveRightWidth)
                            .background(Color.panelBackground(isDark))
                        }
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        MarkdownRendererView(
                            markdown: localContent.replacingOccurrences(of: "\\n", with: "\n"),
                            notes: $notes,
                            selectedNoteId: $selectedNoteId,
                            playerVM: playerVM,
                            isDark: isDark,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent
                        )
                        .frame(maxWidth: 720, alignment: .leading)
                    }
                    .padding(32)
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
        .overlay(alignment: .bottomLeading) {
            if showWikiAutocomplete {
                WikiLinkAutocompleteView(
                    query: wikiQuery,
                    notes: notes,
                    isDark: isDark,
                    primaryAccent: primaryAccent,
                    onSelect: { selectedTitle in
                        insertWikiLinkCompletion(selectedTitle)
                    }
                )
                .padding(.leading, 24)
                .padding(.bottom, 60)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onAppear {
            localContent = note.content.replacingOccurrences(of: "\\n", with: "\n")
            refreshMetadataAsync()
        }
        .task(id: note.id) {
            saveTimer?.invalidate()
            localContent = note.content.replacingOccurrences(of: "\\n", with: "\n")
            refreshMetadataAsync()
        }
        .onChange(of: note.content) { _, externalContent in
            let clean = externalContent.replacingOccurrences(of: "\\n", with: "\n")
            if localContent != clean && saveTimer == nil {
                localContent = clean
                refreshMetadataAsync()
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers: providers)
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
            var fileURL: URL? = nil
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                fileURL = url
            } else if let url = item as? URL {
                fileURL = url
            }
            
            guard let url = fileURL else { return }
            let ext = url.pathExtension.lowercased()
            
            DispatchQueue.main.async {
                if ext == "pdf" {
                    if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: note.id) {
                        note.pdfPath = relPath
                        editMode = .pdf
                        NotesDataManager.shared.saveNotes(notes)
                    }
                } else if ["mp3", "wav", "m4a", "aac", "ogg"].contains(ext) {
                    if let (relPath, fullURL) = NotesDataManager.shared.importAttachment(from: url, for: note.id) {
                        note.audioPath = relPath
                        note.isStandalone = false
                        NotesDataManager.shared.saveNotes(notes)
                        LocalSpeechTranscriber.transcribe(url: fullURL) { segments in
                            note.transcript = segments
                            NotesDataManager.shared.saveNotes(notes)
                            playerVM.loadAudio(url: fullURL, transcript: segments)
                        }
                    }
                }
            }
        }
        return true
    }

    private func handleAutoSave(_ newContent: String) {
        // Detect Wiki-Link [[ typing
        if let match = newContent.range(of: "\\[\\[([^\\]\\n]*)$", options: .regularExpression) {
            let sub = String(newContent[match]).dropFirst(2)
            wikiQuery = String(sub)
            showWikiAutocomplete = true
        } else if showWikiAutocomplete {
            showWikiAutocomplete = false
        }

        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
            Task { @MainActor in
                let clean = newContent.replacingOccurrences(of: "\\n", with: "\n")
                if note.content != clean {
                    note.content = clean
                    NotesDataManager.shared.saveNotes(notes)
                }
                refreshMetadataAsync()
            }
        }
    }

    private func insertWikiLinkCompletion(_ title: String) {
        if let range = localContent.range(of: "\\[\\[([^\\]\\n]*)$", options: .regularExpression) {
            localContent.replaceSubrange(range, with: "[[\(title)]] ")
            showWikiAutocomplete = false
            handleAutoSave(localContent)
        }
    }

    private func refreshMetadataAsync() {
        let currentText = localContent
        let currentTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentLower = currentTitle.lowercased()
        let noteId = note.id
        let allNotes = self.notes

        DispatchQueue.global(qos: .userInitiated).async {
            // Stats & Outline
            let st = calculateWordAndCharCount(currentText)
            let ot = currentText.components(separatedBy: "\n").filter { $0.hasPrefix("#") }

            // Backlinks
            var backlinks: [NoteItem] = []
            var unlinked: [NoteItem] = []
            if !currentLower.isEmpty {
                for n in allNotes {
                    if n.id == noteId { continue }
                    let lower = n.content.lowercased()
                    if lower.contains("[[\(currentLower)]]") {
                        backlinks.append(n)
                    } else if currentTitle.count > 2 && lower.contains(currentLower) {
                        unlinked.append(n)
                    }
                }
            }

            // Outgoing Wiki Links
            var outgoing: [String] = []
            let pattern = "\\[\\[(.*?)\\]\\]"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(currentText.startIndex..<currentText.endIndex, in: currentText)
                let matches = regex.matches(in: currentText, range: nsRange)
                for match in matches {
                    if let range = Range(match.range(at: 1), in: currentText) {
                        let link = String(currentText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !link.isEmpty && !outgoing.contains(link) {
                            outgoing.append(link)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.cachedStats = st
                self.cachedHeadingOutline = ot
                self.cachedIncomingBacklinks = backlinks
                self.cachedUnlinkedMentions = unlinked
                self.cachedOutgoingWikiLinks = outgoing
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
