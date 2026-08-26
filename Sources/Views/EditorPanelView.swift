import SwiftUI

// MARK: - Editor Panel View
struct EditorPanelView: View {
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    @Binding var editMode: EditModeType
    var isFocusMode: Bool = false
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14.0
    @AppStorage("editorFontDesign") private var editorFontDesign: String = "Sans-Serif"
    @AppStorage("editorSplitRatio") private var splitRatio: Double = 0.5
    @AppStorage("enableVimMode") private var enableVimMode = false
    @AppStorage("enableEmacsMode") private var enableEmacsMode = false
    @AppStorage("enableOrgTableAlign") private var enableOrgTableAlign = true
    @AppStorage("enableOrgTaskCycle") private var enableOrgTaskCycle = true
    @AppStorage("enableTypewriterScroll") private var enableTypewriterScroll = false
    @AppStorage("enableAIAutoTagging") private var enableAIAutoTagging = false
    
    @ObservedObject private var vimController = VimController.shared
    @ObservedObject private var emacsController = EmacsController.shared
    @State private var showVimHelpModal = false
    @State private var showEmacsHelpModal = false
    
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

    @State private var docStats: DocumentStats = .zero
    @State private var showStatsPopover = false
    @State private var cachedHeadingOutline: [String] = []
    @State private var cachedIncomingBacklinks: [NoteItem] = []
    @State private var cachedUnlinkedMentions: [NoteItem] = []
    @State private var cachedOutgoingWikiLinks: [String] = []
    @State private var showWikiAutocomplete = false
    @State private var wikiQuery = ""
    @State private var showImagePastedToast = false

    private var stats: (words: Int, chars: Int) {
        (docStats.words, docStats.characters)
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

    var resolvedPPTXURL: URL? {
        NotesDataManager.shared.resolveAttachmentURL(note.pptxPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Streamlined Markdown Formatting & Document Stats Bar (Hidden in Zen Focus Mode)
            if !isFocusMode {
                HStack(spacing: 6) {
                    if editMode == .edit || editMode == .split {
                        HStack(spacing: 2) {
                            MarkdownToolbarButton(icon: "bold", help: "Bold", shortcut: "⌘B") { insertMarkdown("**", "**") }
                            MarkdownToolbarButton(icon: "italic", help: "Italic", shortcut: "⌘I") { insertMarkdown("*", "*") }
                            MarkdownToolbarButton(icon: "number", help: "Heading (#)") { insertMarkdown("\n# ", "") }

                            Rectangle()
                                .fill(Color.subtleBorder(isDark))
                                .frame(width: 1, height: 14)
                                .padding(.horizontal, 4)

                            MarkdownToolbarButton(icon: "list.bullet", help: "Bullet List (* Item)") { insertMarkdown("\n* ", "") }
                            MarkdownToolbarButton(icon: "checklist", help: "Checklist Task (- [ ] Task)") { insertMarkdown("\n- [ ] ", "") }
                            MarkdownToolbarButton(icon: "chevron.left.forwardslash.chevron.right", help: "Code Snippet (`code`)") { insertMarkdown("`", "`") }
                            MarkdownToolbarButton(icon: "link", help: "Wiki Link ([[Note Title]])") { insertMarkdown("[[", "]]") }
                            MarkdownToolbarButton(icon: "tablecells", help: "Insert Table Template") { insertMarkdown("\n| Header 1 | Header 2 |\n| --- | --- |\n| Item 1 | Item 2 |\n", "") }
                            MarkdownToolbarButton(icon: "quote.opening", help: "Blockquote (> Quote)") { insertMarkdown("\n> ", "") }
                            MarkdownToolbarButton(icon: "photo.badge.plus", help: "Paste Screenshot / Image", shortcut: "⌘⇧V") { pasteImageFromClipboard() }
                        }
                    }

                    Spacer()

                    // Document Outline Indicator
                    if !headingOutline.isEmpty {
                        Button(action: { showTOCDrawer.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet.indent")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(secondaryAccent)
                                Text("Outline (\(headingOutline.count))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(secondaryAccent)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(secondaryAccent.opacity(0.12))
                            .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                        .obsidianTooltip("Table of Contents Outline")
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
                    } else if let pptxURL = resolvedPPTXURL, editMode == .edit {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles.tv")
                                .font(.system(size: 10))
                                .foregroundColor(primaryAccent)
                            Text(pptxURL.lastPathComponent)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                            Button("View Slides") { editMode = .pptx }
                                .font(.system(size: 9, weight: .bold))
                                .buttonStyle(.plain)
                                .foregroundColor(primaryAccent)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(4)
                    }

                    // Interactive Document Live Word & Character Stats Inspector
                    Button(action: { showStatsPopover.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "character.cursor.ibeam")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.8))
                            Text("\(docStats.words) words • \(docStats.characters) chars")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(AppRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .help("Click for detailed document statistics and reading time")
                    .popover(isPresented: $showStatsPopover) {
                        DocumentStatsPopoverView(stats: docStats, isDark: isDark, primaryAccent: primaryAccent)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.sidebarBackground(isDark))

                Divider()
                    .background(Color.subtleBorder(isDark))
            }
            
            // Editor Body View (Single Edit, Split View, Full Preview, Native PDF Viewer, or Native PPTX Slide Viewer)
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
            } else if editMode == .pptx, let pptxURL = resolvedPPTXURL {
                PPTXDocumentViewerView(
                    pptxURL: pptxURL,
                    note: $note,
                    notes: $notes,
                    isDark: isDark,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    onDetachPPTX: {
                        note.pptxPath = nil
                        editMode = .edit
                        NotesDataManager.shared.saveNotes(notes)
                    },
                    onQuoteSelection: { _ in
                        localContent = note.content
                    }
                )
            } else if editMode == .edit {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 8)
                        MacMarkdownEditorView(
                            text: $localContent,
                            noteId: note.id,
                            fontSize: CGFloat(editorFontSize),
                            fontDesign: selectedFontDesign,
                            isDark: isDark,
                            enableVimMode: enableVimMode,
                            enableEmacsMode: enableEmacsMode,
                            enableOrgTableAlign: enableOrgTableAlign,
                            enableOrgTaskCycle: enableOrgTaskCycle,
                            enableTypewriterScroll: enableTypewriterScroll,
                            onVimAction: handleVimAction,
                            onEmacsAction: handleEmacsAction,
                            onImagePasted: {
                                withAnimation {
                                    showImagePastedToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation {
                                        showImagePastedToast = false
                                    }
                                }
                            },
                            onTextChanged: { formatted in
                                handleAutoSave(formatted)
                            }
                        )
                        .frame(maxWidth: 760)
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, isFocusMode ? 24 : 12)
                    .padding(.top, isFocusMode ? 16 : 8)
                    .background(Color.panelBackground(isDark))
                    
                    if enableVimMode {
                        VimBottomStatusBar(
                            vimController: vimController,
                            isDark: isDark,
                            primaryAccent: primaryAccent,
                            onHelpRequested: { showVimHelpModal = true }
                        )
                    }
                }
            } else if editMode == .split {
                VStack(spacing: 0) {
                    GeometryReader { splitGeo in
                        let totalWidth = splitGeo.size.width
                        let minPanelWidth: CGFloat = 200
                        let effectiveLeftWidth = max(minPanelWidth, min(totalWidth - minPanelWidth, totalWidth * CGFloat(splitRatio)))
                        let effectiveRightWidth = max(minPanelWidth, totalWidth - effectiveLeftWidth - 6)

                        HStack(spacing: 0) {
                            // Left: Native Markdown Text Editor
                            MacMarkdownEditorView(
                                text: $localContent,
                                noteId: note.id,
                                fontSize: CGFloat(editorFontSize),
                                fontDesign: selectedFontDesign,
                                isDark: isDark,
                                enableVimMode: enableVimMode,
                                enableEmacsMode: enableEmacsMode,
                                enableOrgTableAlign: enableOrgTableAlign,
                                enableOrgTaskCycle: enableOrgTaskCycle,
                                enableTypewriterScroll: enableTypewriterScroll,
                                onVimAction: handleVimAction,
                                onEmacsAction: handleEmacsAction,
                                onImagePasted: {
                                    withAnimation {
                                        showImagePastedToast = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        withAnimation {
                                            showImagePastedToast = false
                                        }
                                    }
                                },
                                onTextChanged: { formatted in
                                    handleAutoSave(formatted)
                                }
                            )
                            .padding(6)
                            .background(Color.panelBackground(isDark))
                            .frame(width: effectiveLeftWidth)
                            
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
                                    .onChanged { value in
                                        let newRatio = Double((effectiveLeftWidth + value.translation.width) / totalWidth)
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
                            
                            // Right: Real-Time Markdown & Diagram Live Preview
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
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(16)
                            }
                            .background(Color.panelBackground(isDark))
                            .frame(width: effectiveRightWidth)
                        }
                    }
                    
                    if enableVimMode {
                        VimBottomStatusBar(
                            vimController: vimController,
                            isDark: isDark,
                            primaryAccent: primaryAccent,
                            onHelpRequested: { showVimHelpModal = true }
                        )
                    }
                }
            } else {
                HStack(spacing: 0) {
                    Spacer()
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
                            .frame(maxWidth: isFocusMode ? 750 : 720, alignment: .leading)
                        }
                        .padding(isFocusMode ? 36 : 32)
                    }
                    Spacer()
                }
                .background(Color.panelBackground(isDark))
            }

            // Collapsible Obsidian-Style Backlinks Drawer (Hidden in Zen Focus Mode)
            if !isFocusMode && (!incomingBacklinks.isEmpty || !unlinkedMentions.isEmpty || !outgoingWikiLinks.isEmpty) {
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
        .overlay(alignment: .topTrailing) {
            if showImagePastedToast {
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                        .foregroundColor(primaryAccent)
                    Text("Image Pasted into Vault")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.panelBackground(isDark))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(primaryAccent.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            localContent = note.content.replacingOccurrences(of: "\\n", with: "\n")
            docStats = calculateDocumentStats(localContent)
            cachedHeadingOutline = localContent.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
            refreshMetadataAsync()
        }
        .task(id: note.id) {
            saveTimer?.invalidate()
            localContent = note.content.replacingOccurrences(of: "\\n", with: "\n")
            docStats = calculateDocumentStats(localContent)
            cachedHeadingOutline = localContent.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
            refreshMetadataAsync()
        }
        .onChange(of: note.content) { _, externalContent in
            let clean = externalContent.replacingOccurrences(of: "\\n", with: "\n")
            if localContent != clean && saveTimer == nil {
                localContent = clean
                docStats = calculateDocumentStats(clean)
                cachedHeadingOutline = clean.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
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
        .onReceive(NotificationCenter.default.publisher(for: .pasteImageAsAttachment)) { _ in
            pasteImageFromClipboard()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers: providers)
        }
        .sheet(isPresented: $showVimHelpModal) {
            VimHelpModalView(
                isPresented: $showVimHelpModal,
                isDark: isDark,
                primaryAccent: primaryAccent
            )
        }
        .sheet(isPresented: $showEmacsHelpModal) {
            EmacsHelpModalView(
                isPresented: $showEmacsHelpModal,
                isDark: isDark,
                primaryAccent: primaryAccent
            )
        }
    }

    private func handleEmacsAction(_ action: EmacsAction) {
        switch action {
        case .none:
            break
        case .message(let msg):
            emacsController.setStatus(msg)
        case .save:
            let clean = localContent.replacingOccurrences(of: "\\n", with: "\n")
            note.content = clean
            NotesDataManager.shared.saveNotesImmediately(notes)
            emacsController.setStatus("Wrote note to vault")
        case .openVaultSearch:
            NotificationCenter.default.post(name: .openVaultSearch, object: nil)
        case .switchTab:
            TabNavigationManager.shared.nextTab()
            selectedNoteId = TabNavigationManager.shared.activeTabId
        case .closeTab:
            TabNavigationManager.shared.closeTab(note.id)
            if let first = TabNavigationManager.shared.openTabIds.first {
                selectedNoteId = first
            }
        case .openCalendar:
            NotificationCenter.default.post(name: .openCalendarHub, object: nil)
        case .openGraph:
            NotificationCenter.default.post(name: .openKnowledgeGraph, object: nil)
        case .toggleFocus:
            NotificationCenter.default.post(name: NSNotification.Name("ToggleZenFocusMode"), object: nil)
        case .openTOC:
            withAnimation { showTOCDrawer.toggle() }
        case .openAI:
            NotificationCenter.default.post(name: NSNotification.Name("OpenAIAssistant"), object: nil)
        case .orgTableAlign:
            break
        case .orgCycleTask:
            break
        case .showHelp:
            showEmacsHelpModal = true
        case .newDailyNote:
            NotificationCenter.default.post(name: .createDailyNote, object: nil)
        case .newNoteFromTemplate:
            NotificationCenter.default.post(name: .openTemplatePicker, object: nil)
        case .exportPDF:
            break
        case .exportSRT:
            break
        }
    }

    private func handleVimAction(_ action: VimAction) {
        switch action {
        case .none, .message:
            break
        case .save:
            if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                notes[idx].content = localContent
                NotesDataManager.shared.saveNotes(notes)
            }
        case .closeTab:
            TabNavigationManager.shared.closeTab(note.id)
            if let first = TabNavigationManager.shared.openTabIds.first {
                selectedNoteId = first
            }
        case .saveAndClose:
            if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                notes[idx].content = localContent
                NotesDataManager.shared.saveNotes(notes)
            }
            TabNavigationManager.shared.closeTab(note.id)
            if let first = TabNavigationManager.shared.openTabIds.first {
                selectedNoteId = first
            }
        case .nextTab:
            TabNavigationManager.shared.nextTab()
            selectedNoteId = TabNavigationManager.shared.activeTabId
        case .prevTab:
            TabNavigationManager.shared.previousTab()
            selectedNoteId = TabNavigationManager.shared.activeTabId
        case .newTab:
            let newNote = NoteItem(
                title: "Untitled Note",
                folder: note.folder,
                content: "",
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
            notes.insert(newNote, at: 0)
            selectedNoteId = newNote.id
            TabNavigationManager.shared.openNote(newNote.id)
            NotesDataManager.shared.saveNotes(notes)
        case .toggleLineNumbers:
            break
        case .openGraph:
            NotificationCenter.default.post(name: NSNotification.Name("ToggleGraphView"), object: nil)
        case .toggleFocus:
            break
        case .openTOC:
            withAnimation { showTOCDrawer.toggle() }
        case .openAI:
            NotificationCenter.default.post(name: NSNotification.Name("OpenAIAssistant"), object: nil)
        case .showHelp:
            showVimHelpModal = true
        case .replaceText(let find, let replace, let isGlobal):
            if isGlobal {
                localContent = localContent.replacingOccurrences(of: find, with: replace)
                handleAutoSave(localContent)
                vimController.setStatus("Substituted all occurrences of '\(find)'")
            } else {
                if let range = localContent.range(of: find) {
                    localContent.replaceSubrange(range, with: replace)
                    handleAutoSave(localContent)
                    vimController.setStatus("Substituted 1 occurrence of '\(find)'")
                } else {
                    vimController.setStatus("Pattern not found: \(find)")
                }
            }
        }
    }

    private func pasteImageFromClipboard() {
        if let res = NotesDataManager.shared.saveClipboardImage(for: note.id) {
            localContent += "\n\n" + res.markdown + "\n"
            handleAutoSave(localContent)
            withAnimation {
                showImagePastedToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showImagePastedToast = false
                }
            }
        } else {
            NSSound.beep()
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
                } else if ext == "pptx" {
                    if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: note.id) {
                        note.pptxPath = relPath
                        editMode = .pptx
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
                } else if ["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic"].contains(ext) {
                    if let image = NSImage(contentsOf: url),
                       let res = NotesDataManager.shared.saveImageAttachment(image: image, originalFilename: url.lastPathComponent, for: note.id) {
                        localContent += "\n\n" + res.markdown + "\n"
                        handleAutoSave(localContent)
                        withAnimation {
                            showImagePastedToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                showImagePastedToast = false
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    private func handleAutoSave(_ newContent: String) {
        // Real-time synchronous calculation of live word/char count and headings
        docStats = calculateDocumentStats(newContent)
        cachedHeadingOutline = newContent.components(separatedBy: "\n").filter { $0.hasPrefix("#") }

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
            docStats = calculateDocumentStats(localContent)
            cachedHeadingOutline = localContent.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
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
            // Outline
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
                self.cachedHeadingOutline = ot
                self.cachedIncomingBacklinks = backlinks
                self.cachedUnlinkedMentions = unlinked
                self.cachedOutgoingWikiLinks = outgoing
            }
        }
    }

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        localContent += "\(prefix)text\(suffix)"
        docStats = calculateDocumentStats(localContent)
        cachedHeadingOutline = localContent.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
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
        guard let idx = notes.firstIndex(where: { $0.id == targetNote.id }) else { return }
        let currentTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "(?<!\\[\\[)(" + NSRegularExpression.escapedPattern(for: currentTitle) + ")(?!\\]\\])"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsRange = NSRange(notes[idx].content.startIndex..., in: notes[idx].content)
            notes[idx].content = regex.stringByReplacingMatches(in: notes[idx].content, range: nsRange, withTemplate: "[[$1]]")
            NotesDataManager.shared.saveNotes(notes)
            refreshMetadataAsync()
        }
    }

    private func insertMarkdown(prefix: String, suffix: String = "") {
        localContent += "\(prefix)\(suffix)"
        handleAutoSave(localContent)
    }
}

// MARK: - Native Mac Markdown Text Editor with Deep Image Paste, Vim & Emacs Interception
struct MacMarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    let noteId: UUID
    let fontSize: CGFloat
    let fontDesign: Font.Design
    let isDark: Bool
    var enableVimMode: Bool = false
    var enableEmacsMode: Bool = false
    var enableOrgTableAlign: Bool = true
    var enableOrgTaskCycle: Bool = true
    var enableTypewriterScroll: Bool = false
    var onVimAction: ((VimAction) -> Void)? = nil
    var onEmacsAction: ((EmacsAction) -> Void)? = nil
    var onImagePasted: (() -> Void)? = nil
    var onTextChanged: ((String) -> Void)? = nil

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacMarkdownEditorView
        var isUpdating = false

        init(_ parent: MacMarkdownEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            if parent.text != newText {
                parent.text = newText
                parent.onTextChanged?(newText)
            }
            if parent.enableVimMode {
                VimController.shared.updateCursorPosition(in: textView)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.enableVimMode {
                VimController.shared.updateCursorPosition(in: textView)
            }
        }
    }

    class CustomNSTextView: NSTextView {
        var noteId: UUID?
        var enableVimMode: Bool = false
        var enableEmacsMode: Bool = false
        var enableOrgTableAlign: Bool = true
        var enableOrgTaskCycle: Bool = true
        var enableTypewriterScroll: Bool = false
        var onVimAction: ((VimAction) -> Void)?
        var onEmacsAction: ((EmacsAction) -> Void)?
        var onImagePasted: (() -> Void)?

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Intercept ⌘V keyboard shortcut
            if flags == .command && event.charactersIgnoringModifiers == "v" {
                self.paste(self)
                return true
            }
            return super.performKeyEquivalent(with: event)
        }

        override func keyDown(with event: NSEvent) {
            // 1. Vim Mode Interception
            if enableVimMode {
                let handled = VimController.shared.handleKeyDown(event: event, in: self) { [weak self] action in
                    self?.onVimAction?(action)
                }
                if handled {
                    self.didChangeText()
                    return
                }
            }
            
            // 2. GNU Emacs Keybinding Interception
            if enableEmacsMode {
                let handled = EmacsController.shared.handleKeyDown(event: event, in: self) { [weak self] action in
                    self?.onEmacsAction?(action)
                }
                if handled {
                    self.didChangeText()
                    return
                }
            }
            
            // 3. Org-Table Auto-Alignment on TAB key (keyCode 48)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if enableOrgTableAlign && event.keyCode == 48 && flags.isEmpty {
                if OrgModeEngine.isInsideTable(in: self) {
                    if OrgModeEngine.alignTableAtCursor(in: self) {
                        self.didChangeText()
                        return
                    }
                }
            }
            
            // 4. Org-Mode Task State Cycling (Ctrl-C Ctrl-C or C-c)
            if enableOrgTaskCycle && event.modifierFlags.contains(.control) && (event.charactersIgnoringModifiers ?? "").lowercased() == "c" && !enableEmacsMode {
                if OrgModeEngine.cycleTaskState(in: self) {
                    self.didChangeText()
                    return
                }
            }

            super.keyDown(with: event)
            
            // 5. Typewriter Center Scrolling
            if enableTypewriterScroll {
                centerActiveLineInScrollView()
            }
        }
        
        private func centerActiveLineInScrollView() {
            guard let layoutManager = self.layoutManager,
                  let textContainer = self.textContainer,
                  let scrollView = self.enclosingScrollView else { return }
            
            let selectedRange = self.selectedRange()
            let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            let clipView = scrollView.contentView
            let visibleHeight = clipView.bounds.height
            let targetY = max(0, rect.midY - (visibleHeight / 2))
            
            clipView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
        }

        // MARK: - Smart Markdown List & Bullet Point Engine
        override func insertNewline(_ sender: Any?) {
            let currentText = self.string as NSString
            let selectedRange = self.selectedRange()
            guard selectedRange.length == 0, currentText.length > 0 else {
                super.insertNewline(sender)
                return
            }
            
            let lineRange = currentText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let currentLine = currentText.substring(with: lineRange)
            
            // 1. Checklist: ^([ \t]*)([-*+]) \[( |x|X)\] (.*)$
            if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)([-*+]) \\[( |x|X)\\] (.*)$", options: [.anchorsMatchLines]),
               let match = regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.utf16.count)) {
                let indentRange = match.range(at: 1)
                let markerRange = match.range(at: 2)
                let contentRange = match.range(at: 4)
                
                let indent = (currentLine as NSString).substring(with: indentRange)
                let marker = (currentLine as NSString).substring(with: markerRange)
                let content = (currentLine as NSString).substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if content.isEmpty {
                    let repRange = lineRange
                    if self.shouldChangeText(in: repRange, replacementString: "\n") {
                        self.replaceCharacters(in: repRange, with: "\n")
                        self.didChangeText()
                        return
                    }
                } else {
                    let nextItem = "\n\(indent)\(marker) [ ] "
                    if self.shouldChangeText(in: selectedRange, replacementString: nextItem) {
                        self.insertText(nextItem, replacementRange: selectedRange)
                        self.didChangeText()
                        return
                    }
                }
            }
            
            // 2. Numbered List: ^([ \t]*)(\d+)\. (.*)$
            if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)(\\d+)\\. (.*)$", options: [.anchorsMatchLines]),
               let match = regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.utf16.count)) {
                let indentRange = match.range(at: 1)
                let numRange = match.range(at: 2)
                let contentRange = match.range(at: 3)
                
                let indent = (currentLine as NSString).substring(with: indentRange)
                let numStr = (currentLine as NSString).substring(with: numRange)
                let content = (currentLine as NSString).substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                let num = Int(numStr) ?? 1
                
                if content.isEmpty {
                    let repRange = lineRange
                    if self.shouldChangeText(in: repRange, replacementString: "\n") {
                        self.replaceCharacters(in: repRange, with: "\n")
                        self.didChangeText()
                        return
                    }
                } else {
                    let nextItem = "\n\(indent)\(num + 1). "
                    if self.shouldChangeText(in: selectedRange, replacementString: nextItem) {
                        self.insertText(nextItem, replacementRange: selectedRange)
                        self.didChangeText()
                        return
                    }
                }
            }
            
            // 3. Bullet List: ^([ \t]*)([-*+]) (.*)$
            if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)([-*+]) (.*)$", options: [.anchorsMatchLines]),
               let match = regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.utf16.count)) {
                let indentRange = match.range(at: 1)
                let markerRange = match.range(at: 2)
                let contentRange = match.range(at: 3)
                
                let indent = (currentLine as NSString).substring(with: indentRange)
                let marker = (currentLine as NSString).substring(with: markerRange)
                let content = (currentLine as NSString).substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if content.isEmpty {
                    let repRange = lineRange
                    if self.shouldChangeText(in: repRange, replacementString: "\n") {
                        self.replaceCharacters(in: repRange, with: "\n")
                        self.didChangeText()
                        return
                    }
                } else {
                    let nextItem = "\n\(indent)\(marker) "
                    if self.shouldChangeText(in: selectedRange, replacementString: nextItem) {
                        self.insertText(nextItem, replacementRange: selectedRange)
                        self.didChangeText()
                        return
                    }
                }
            }
            
            // 4. Blockquote: ^([ \t]*)(>+) (.*)$
            if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)(>+) (.*)$", options: [.anchorsMatchLines]),
               let match = regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.utf16.count)) {
                let indentRange = match.range(at: 1)
                let markerRange = match.range(at: 2)
                let contentRange = match.range(at: 3)
                
                let indent = (currentLine as NSString).substring(with: indentRange)
                let marker = (currentLine as NSString).substring(with: markerRange)
                let content = (currentLine as NSString).substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if content.isEmpty {
                    let repRange = lineRange
                    if self.shouldChangeText(in: repRange, replacementString: "\n") {
                        self.replaceCharacters(in: repRange, with: "\n")
                        self.didChangeText()
                        return
                    }
                } else {
                    let nextItem = "\n\(indent)\(marker) "
                    if self.shouldChangeText(in: selectedRange, replacementString: nextItem) {
                        self.insertText(nextItem, replacementRange: selectedRange)
                        self.didChangeText()
                        return
                    }
                }
            }
            
            super.insertNewline(sender)
        }
        
        override func insertTab(_ sender: Any?) {
            let currentText = self.string as NSString
            let selectedRange = self.selectedRange()
            guard currentText.length > 0 else {
                super.insertTab(sender)
                return
            }
            let lineRange = currentText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let currentLine = currentText.substring(with: lineRange)
            
            if currentLine.range(of: "^[ \\t]*([\\*\\-\\+]|\\d+\\.|- \\[[ xX]\\]) ", options: .regularExpression) != nil {
                let insertRange = NSRange(location: lineRange.location, length: 0)
                if self.shouldChangeText(in: insertRange, replacementString: "  ") {
                    self.replaceCharacters(in: insertRange, with: "  ")
                    self.didChangeText()
                    return
                }
            }
            super.insertTab(sender)
        }
        
        override func insertBacktab(_ sender: Any?) {
            let currentText = self.string as NSString
            let selectedRange = self.selectedRange()
            guard currentText.length > 0 else {
                super.insertBacktab(sender)
                return
            }
            let lineRange = currentText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let currentLine = currentText.substring(with: lineRange)
            
            if currentLine.hasPrefix("  ") {
                let removeRange = NSRange(location: lineRange.location, length: 2)
                if self.shouldChangeText(in: removeRange, replacementString: "") {
                    self.replaceCharacters(in: removeRange, with: "")
                    self.didChangeText()
                    return
                }
            } else if currentLine.hasPrefix(" ") || currentLine.hasPrefix("\t") {
                let removeRange = NSRange(location: lineRange.location, length: 1)
                if self.shouldChangeText(in: removeRange, replacementString: "") {
                    self.replaceCharacters(in: removeRange, with: "")
                    self.didChangeText()
                    return
                }
            }
            super.insertBacktab(sender)
        }
        
        override func deleteBackward(_ sender: Any?) {
            let currentText = self.string as NSString
            let selectedRange = self.selectedRange()
            if selectedRange.length == 0 && selectedRange.location > 0 && currentText.length > 0 {
                let lineRange = currentText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
                let textBeforeCursor = currentText.substring(with: NSRange(location: lineRange.location, length: selectedRange.location - lineRange.location))
                
                if textBeforeCursor.range(of: "^[ \\t]*([\\*\\-\\+]|- \\[[ xX]\\]|\\d+\\.) $", options: .regularExpression) != nil {
                    let deleteRange = NSRange(location: lineRange.location, length: selectedRange.location - lineRange.location)
                    if self.shouldChangeText(in: deleteRange, replacementString: "") {
                        self.replaceCharacters(in: deleteRange, with: "")
                        self.didChangeText()
                        return
                    }
                }
            }
            super.deleteBackward(sender)
        }

        override func paste(_ sender: Any?) {
            // Check if clipboard contains image data (e.g. from ⌘⌃⇧4 screenshot or copied image)
            if let noteId = noteId, let res = NotesDataManager.shared.saveClipboardImage(for: noteId) {
                let markdownTag = "\n\n" + res.markdown + "\n\n"
                self.insertText(markdownTag, replacementRange: self.selectedRange())
                self.didChangeText()
                onImagePasted?()
                return
            }
            // Normal text paste
            super.paste(sender)
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            let pboard = sender.draggingPasteboard
            if let noteId = noteId {
                if let image = NSImage(pasteboard: pboard) {
                    if let res = NotesDataManager.shared.saveImageAttachment(image: image, originalFilename: nil, for: noteId) {
                        let markdownTag = "\n\n" + res.markdown + "\n\n"
                        self.insertText(markdownTag, replacementRange: self.selectedRange())
                        self.didChangeText()
                        onImagePasted?()
                        return true
                    }
                }
                if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                    let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic"]
                    for fileURL in urls {
                        if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                            if let img = NSImage(contentsOf: fileURL),
                               let res = NotesDataManager.shared.saveImageAttachment(image: img, originalFilename: fileURL.lastPathComponent, for: noteId) {
                                let markdownTag = "\n\n" + res.markdown + "\n\n"
                                self.insertText(markdownTag, replacementRange: self.selectedRange())
                                self.didChangeText()
                                onImagePasted?()
                                return true
                            }
                        }
                    }
                }
            }
            return super.performDragOperation(sender)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = CustomNSTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 14, height: 14)
        
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = context.coordinator
        textView.noteId = noteId
        textView.enableVimMode = enableVimMode
        textView.enableEmacsMode = enableEmacsMode
        textView.enableOrgTableAlign = enableOrgTableAlign
        textView.enableOrgTaskCycle = enableOrgTaskCycle
        textView.enableTypewriterScroll = enableTypewriterScroll
        textView.onVimAction = onVimAction
        textView.onEmacsAction = onEmacsAction
        textView.onImagePasted = onImagePasted
        
        applyFontAndColors(to: textView)
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomNSTextView else { return }
        context.coordinator.parent = self
        textView.noteId = noteId
        textView.enableVimMode = enableVimMode
        textView.enableEmacsMode = enableEmacsMode
        textView.enableOrgTableAlign = enableOrgTableAlign
        textView.enableOrgTaskCycle = enableOrgTaskCycle
        textView.enableTypewriterScroll = enableTypewriterScroll
        textView.onVimAction = onVimAction
        textView.onEmacsAction = onEmacsAction
        textView.onImagePasted = onImagePasted

        if textView.string != text {
            context.coordinator.isUpdating = true
            let selectedRange = textView.selectedRange()
            textView.string = text
            if selectedRange.location + selectedRange.length <= text.count {
                textView.setSelectedRange(selectedRange)
            }
            context.coordinator.isUpdating = false
        }
        applyFontAndColors(to: textView)
    }

    private func applyFontAndColors(to textView: NSTextView) {
        let nsFont: NSFont
        switch fontDesign {
        case .serif:
            nsFont = NSFont(name: "New York", size: fontSize) ?? NSFont(name: "Georgia", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        case .monospaced:
            nsFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        default:
            nsFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        }
        textView.font = nsFont
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5.0
        paragraphStyle.paragraphSpacing = 8.0
        textView.defaultParagraphStyle = paragraphStyle
        
        textView.textColor = isDark ? NSColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0) : NSColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
        textView.insertionPointColor = isDark ? NSColor.white : NSColor.black
    }
}

// MARK: - Vim Bottom Status Bar
struct VimBottomStatusBar: View {
    @ObservedObject var vimController: VimController
    let isDark: Bool
    let primaryAccent: Color
    let onHelpRequested: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Mode Badge
            Text("-- \(vimController.mode.rawValue) --")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(vimController.mode.accentColor)
                .cornerRadius(4)
            
            // Command Line Input or Status Message
            if vimController.mode == .command {
                HStack(spacing: 2) {
                    Text(":")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(primaryAccent)
                    Text(vimController.commandText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                    Rectangle()
                        .fill(primaryAccent)
                        .frame(width: 2, height: 12)
                }
            } else if !vimController.statusMessage.isEmpty {
                Text(vimController.statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Line and Column tracker
            Text("Ln \(vimController.cursorLine), Col \(vimController.cursorColumn)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            
            // Help Button
            Button(action: onHelpRequested) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Vim Keybindings & Commands (:help)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.sidebarBackground(isDark).opacity(0.9))
        .overlay(
            Rectangle()
                .fill(Color.subtleBorder(isDark))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Dedicated Sleek Markdown Toolbar Button
struct MarkdownToolbarButton: View {
    let icon: String
    let help: String
    var shortcut: String? = nil
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 26, height: 24)
                .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .cornerRadius(AppRadius.sm)
        }
        .buttonStyle(.plain)
        .obsidianTooltip(help, shortcut: shortcut)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Document Statistics Popover View
struct DocumentStatsPopoverView: View {
    let stats: DocumentStats
    let isDark: Bool
    let primaryAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(primaryAccent)
                Text("Document Inspector")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDark ? .white : .black)
            }

            Divider()

            VStack(spacing: 6) {
                statsRow(label: "Words", value: "\(stats.words)")
                statsRow(label: "Characters (with spaces)", value: "\(stats.characters)")
                statsRow(label: "Characters (no spaces)", value: "\(stats.charactersNoSpaces)")
                statsRow(label: "Paragraphs", value: "\(stats.paragraphs)")
                statsRow(label: "Lines", value: "\(stats.lines)")
                
                Divider()
                    .padding(.vertical, 2)
                
                HStack {
                    Text("Reading Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("~\(stats.readingTimeMinutes) min")
                        .font(.caption.weight(.bold))
                        .foregroundColor(primaryAccent)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 230)
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundColor(isDark ? .white : .black)
        }
    }
}
