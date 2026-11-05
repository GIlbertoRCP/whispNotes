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
    @AppStorage(EditorPreferenceKey.readingWidth) private var readingWidthRaw: String = ReadingWidth.standard.rawValue
    private var readingWidth: CGFloat { (ReadingWidth(rawValue: readingWidthRaw) ?? .standard).maxWidth }
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
    /// The user's choice, remembered across launches.
    @AppStorage("showBacklinksDrawer") private var showBacklinks = true
    /// True while the panel is too short for the expanded drawer; it reopens on its own when there's room.
    @State private var backlinksAutoCollapsed = false
    private static let backlinksMinPanelHeight: CGFloat = 560
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
    /// Width the formatting bar gets; less-used buttons fold into a menu when it's narrow.
    @State private var formatBarWidth: CGFloat = 900
    /// Split ratio when a divider drag began, so the drag follows the pointer instead of compounding.
    @State private var splitDragStartRatio: Double? = nil
    /// Below this the split stacks editor over preview rather than squeezing two columns.
    private static let sideBySideSplitMinWidth: CGFloat = 560
    @State private var cachedHeadingOutline: [String] = []
    @State private var cachedIncomingBacklinks: [NoteItem] = []
    @State private var cachedUnlinkedMentions: [NoteItem] = []
    @State private var cachedOutgoingWikiLinks: [String] = []
    @State private var showWikiAutocomplete = false
    @State private var wikiQuery = ""
    @State private var showImagePastedToast = false
    @State private var pasteToastMessage: String? = nil

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
                        formattingButtons
                    }

                    Spacer(minLength: 4)

                    // Document Outline Indicator
                    if !headingOutline.isEmpty {
                        Button(action: { showTOCDrawer.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet.indent")
                                    .font(.system(size: 10, weight: .medium))
                                Text(formatBarWidth >= 520 ? "Outline (\(headingOutline.count))" : "\(headingOutline.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .monospacedDigit()
                                    .fixedSize()
                            }
                            .foregroundColor(secondaryAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(secondaryAccent.opacity(0.12))
                            .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                        .obsidianTooltip("Outline")
                        .popover(isPresented: $showTOCDrawer) {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Outline")
                                    .font(.headline)
                                ForEach(Array(headingOutline.enumerated()), id: \.offset) { _, heading in
                                    let level = heading.prefix(while: { $0 == "#" }).count
                                    Text(heading.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 12, weight: level <= 1 ? .semibold : .regular))
                                        .padding(.leading, CGFloat(max(0, level - 1)) * 12)
                                }
                            }
                            .padding(AppSpacing.md)
                            .frame(minWidth: 200, alignment: .leading)
                        }
                    }

                    if let pdfURL = resolvedPDFURL, editMode == .edit, formatBarWidth >= 640 {
                        attachmentChip(icon: "doc.richtext.fill", name: pdfURL.lastPathComponent, action: "View PDF") { editMode = .pdf }
                    } else if let pptxURL = resolvedPPTXURL, editMode == .edit, formatBarWidth >= 640 {
                        attachmentChip(icon: "sparkles.tv", name: pptxURL.lastPathComponent, action: "View Slides") { editMode = .pptx }
                    }

                    // Live word & character count (details in the popover)
                    Button(action: { showStatsPopover.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "character.cursor.ibeam")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.8))
                            Text(formatBarWidth >= 600
                                 ? "\(docStats.words.formatted()) words · \(docStats.characters.formatted()) chars"
                                 : "\(docStats.words.formatted()) words")
                                .font(.system(size: 10, weight: .medium))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .fixedSize()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(AppRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .help("Word count, characters and reading time")
                    .popover(isPresented: $showStatsPopover) {
                        DocumentStatsPopoverView(stats: docStats, isDark: isDark, primaryAccent: primaryAccent)
                    }
                }
                .frame(height: 26)
                .frame(minWidth: 0, maxWidth: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { formatBarWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, width in formatBarWidth = width }
                    }
                )
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
                        .frame(maxWidth: readingWidth)
                        .overlay(alignment: .topLeading) {
                            if localContent.isEmpty {
                                // Matches the text view's container inset (22 × 18) plus line-fragment padding (5).
                                Text("Start writing, or press \(GlobalHotKey.displayString) to record")
                                    .font(.system(size: CGFloat(editorFontSize), design: selectedFontDesign))
                                    .foregroundColor(Color.appTextSecondary(isDark).opacity(0.7))
                                    .padding(.leading, 27)
                                    .padding(.top, 18)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                        }
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
                        let minPanelWidth: CGFloat = 240
                        let effectiveLeftWidth = max(minPanelWidth, min(totalWidth - minPanelWidth - 6, totalWidth * CGFloat(splitRatio)))
                        let effectiveRightWidth = max(0, totalWidth - effectiveLeftWidth - 6)

                        if totalWidth < Self.sideBySideSplitMinWidth {
                            // Narrow pane: editor on top, live preview underneath.
                            VStack(spacing: 0) {
                                splitEditor
                                    .frame(height: splitGeo.size.height * 0.55)
                                Rectangle()
                                    .fill(Color.subtleBorder(isDark))
                                    .frame(height: 1)
                                splitPreview
                            }
                        } else {
                        HStack(spacing: 0) {
                            // Left: Native Markdown Text Editor
                            splitEditor
                                .frame(width: effectiveLeftWidth)
                            
                            // Interactive Draggable Split Divider
                            ZStack {
                                Rectangle()
                                    .fill(Color.subtleBorder(isDark))
                                    .frame(width: 1)
                                
                                RoundedRectangle(cornerRadius: AppRadius.xs)
                                    .fill(Color.cardBackground(isDark))
                                    .frame(width: 6, height: 32)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.xs)
                                            .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                                    )
                            }
                            .frame(width: 6)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        let start = splitDragStartRatio ?? splitRatio
                                        if splitDragStartRatio == nil { splitDragStartRatio = start }
                                        let newRatio = start + Double(value.translation.width / max(totalWidth, 1))
                                        splitRatio = max(0.2, min(0.8, newRatio))
                                    }
                                    .onEnded { _ in splitDragStartRatio = nil }
                            )
                            .onHover { inside in
                                if inside {
                                    NSCursor.resizeLeftRight.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            // Right: Real-Time Markdown & Diagram Live Preview
                            splitPreview
                                .frame(width: effectiveRightWidth)
                        }
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
                            .frame(maxWidth: readingWidth, alignment: .leading)
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
                    Button(action: {
                        withAnimation(AppAnimation.panel) {
                            if backlinksAutoCollapsed {
                                // Collapsed only for space: open it without changing the saved preference.
                                backlinksAutoCollapsed = false
                                showBacklinks = true
                            } else {
                                showBacklinks.toggle()
                            }
                        }
                    }) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "network")
                                .foregroundColor(secondaryAccent)
                            Text("Connections")
                                .font(.caption)
                                .fontWeight(.bold)
                            if !backlinksExpanded {
                                Text(connectionsSummary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: backlinksExpanded ? "chevron.down" : "chevron.up")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(backlinksExpanded ? "Hide connections" : "Show connections")

                    if backlinksExpanded {
                        HStack(alignment: .top, spacing: 20) {
                            if !incomingBacklinks.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("LINKED REFERENCES (\(incomingBacklinks.count))")
                                        .font(.system(size: 10, weight: .bold))
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
                                            .cornerRadius(AppRadius.sm)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if !unlinkedMentions.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("UNLINKED MENTIONS (\(unlinkedMentions.count))")
                                        .font(.system(size: 10, weight: .bold))
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
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(primaryAccent.opacity(0.18))
                                                    .foregroundColor(primaryAccent)
                                                    .cornerRadius(AppRadius.xs)
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
                                        .font(.system(size: 10, weight: .bold))
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
                                            .cornerRadius(AppRadius.sm)
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
                .cornerRadius(AppRadius.md)
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
            VStack(alignment: .trailing, spacing: 8) {
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
                    .cornerRadius(AppRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(primaryAccent.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                if let message = pasteToastMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(primaryAccent)
                        Text(message)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.panelBackground(isDark))
                    .cornerRadius(AppRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(primaryAccent.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { adaptBacklinks(toPanelHeight: geo.size.height) }
                    .onChange(of: geo.size.height) { _, height in adaptBacklinks(toPanelHeight: height) }
            }
        )
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SmartPasteApplied"))) { notif in
            let type = notif.object as? String ?? "Markdown"
            withAnimation {
                pasteToastMessage = "✨ \(type) Pasted (⌘Z to undo)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    pasteToastMessage = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SmartFormatNoteRequested"))) { _ in
            smartFormatCurrentNote()
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
            NotificationCenter.default.post(name: .openExportModal, object: nil)
        case .exportSRT:
            NoteExporter.shared.exportSRT(note)
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

    private var backlinksExpanded: Bool { showBacklinks && !backlinksAutoCollapsed }

    private var connectionsSummary: String {
        var parts: [String] = []
        if !incomingBacklinks.isEmpty { parts.append("\(incomingBacklinks.count) linked here") }
        if !outgoingWikiLinks.isEmpty { parts.append("\(outgoingWikiLinks.count) outgoing") }
        if !unlinkedMentions.isEmpty { parts.append("\(unlinkedMentions.count) unlinked") }
        return parts.joined(separator: " · ")
    }

    private func adaptBacklinks(toPanelHeight height: CGFloat) {
        let tooShort = height < Self.backlinksMinPanelHeight
        if tooShort != backlinksAutoCollapsed {
            withAnimation(AppAnimation.panel) { backlinksAutoCollapsed = tooShort }
        }
    }

    private var splitEditor: some View {
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
                withAnimation { showImagePastedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation { showImagePastedToast = false }
                }
            },
            onTextChanged: { formatted in
                handleAutoSave(formatted)
            }
        )
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .background(Color.panelBackground(isDark))
    }

    private var splitPreview: some View {
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
            .padding(AppSpacing.lg)
        }
        .background(Color.panelBackground(isDark))
    }

    private struct FormatAction: Identifiable {
        let id: String
        let icon: String
        let help: String
        var shortcut: String? = nil
        let run: () -> Void
    }

    /// In priority order: the first ones stay visible longest as the bar narrows.
    private var formatActions: [FormatAction] {
        [
            FormatAction(id: "bold", icon: "bold", help: "Bold", shortcut: "⌘B") { insertMarkdown("**", "**") },
            FormatAction(id: "italic", icon: "italic", help: "Italic", shortcut: "⌘I") { insertMarkdown("*", "*") },
            FormatAction(id: "check", icon: "checklist", help: "Checklist item") { insertMarkdown("\n- [ ] ", "") },
            FormatAction(id: "bullet", icon: "list.bullet", help: "Bulleted list") { insertMarkdown("\n* ", "") },
            FormatAction(id: "link", icon: "link", help: "Link to note ([[Title]])") { insertMarkdown("[[", "]]") },
            FormatAction(id: "heading", icon: "number", help: "Heading") { insertMarkdown("\n# ", "") },
            FormatAction(id: "quote", icon: "quote.opening", help: "Quote") { insertMarkdown("\n> ", "") },
            FormatAction(id: "code", icon: "chevron.left.forwardslash.chevron.right", help: "Inline code") { insertMarkdown("`", "`") },
            FormatAction(id: "table", icon: "tablecells", help: "Insert table") { insertMarkdown("\n| Header 1 | Header 2 |\n| --- | --- |\n| Item 1 | Item 2 |\n", "") },
            FormatAction(id: "image", icon: "photo.badge.plus", help: "Paste image from clipboard", shortcut: "⇧⌘V") { pasteImageFromClipboard() },
            FormatAction(id: "format", icon: "wand.and.stars", help: "Clean up formatting", shortcut: "⌥⌘F") { smartFormatCurrentNote() },
        ]
    }

    /// How many formatting buttons fit inline; the rest go in the More menu.
    private var visibleFormatCount: Int {
        switch formatBarWidth {
        case 720...: return formatActions.count
        case 600..<720: return 7
        case 480..<600: return 5
        default: return 3
        }
    }

    private var formattingButtons: some View {
        let actions = formatActions
        let visible = min(visibleFormatCount, actions.count)
        return HStack(spacing: 2) {
            ForEach(actions.prefix(visible)) { action in
                MarkdownToolbarButton(icon: action.icon, help: action.help, shortcut: action.shortcut, action: action.run)
            }
            if visible < actions.count {
                Menu {
                    ForEach(actions.dropFirst(visible)) { action in
                        Button(action: action.run) {
                            Label(action.help, systemImage: action.icon)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More formatting")
            }
        }
    }

    private func attachmentChip(icon: String, name: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(primaryAccent)
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 160)
            Button(action, action: perform)
                .font(.system(size: 10, weight: .bold))
                .buttonStyle(.plain)
                .foregroundColor(primaryAccent)
                .fixedSize()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(primaryAccent.opacity(0.12))
        .cornerRadius(AppRadius.xs)
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

    private func smartFormatCurrentNote() {
        let cleaned = SmartPasteEngine.shared.cleanClutteredPlainText(localContent)
        if cleaned != localContent {
            localContent = cleaned
            handleAutoSave(cleaned)
            withAnimation {
                pasteToastMessage = "✨ Note Formatted & Cleaned"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    pasteToastMessage = nil
                }
            }
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
            // Intercept ⌥⇧⌘V: Paste as raw unformatted plain text
            if flags == [.command, .option, .shift] && (event.charactersIgnoringModifiers ?? "").lowercased() == "v" {
                self.pasteAsPlainText(self)
                return true
            }
            // Intercept ⌘V keyboard shortcut: Smart Paste
            if flags == .command && event.charactersIgnoringModifiers == "v" {
                self.paste(self)
                return true
            }
            // ⌘B / ⌘I: wrap the selection in markdown bold / italic (press again to unwrap)
            if flags == .command, window?.firstResponder === self {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "b": toggleMarkdownWrap("**"); return true
                case "i": toggleMarkdownWrap("*"); return true
                default: break
                }
            }
            return super.performKeyEquivalent(with: event)
        }

        /// Wraps the selection in `marker` (e.g. ** for bold) or removes it if already wrapped. Undoable.
        func toggleMarkdownWrap(_ marker: String) {
            let text = string as NSString
            let range = selectedRange()
            let m = (marker as NSString).length
            let before = NSRange(location: range.location - m, length: m)
            let after = NSRange(location: NSMaxRange(range), length: m)
            let isWrapped = before.location >= 0 && NSMaxRange(after) <= text.length
                && text.substring(with: before) == marker && text.substring(with: after) == marker
                // "**bold**" seen through the italic marker is bold, not italic.
                && !(marker == "*" && before.location > 0 && text.substring(with: NSRange(location: before.location - 1, length: 1)) == "*")

            if isWrapped {
                let full = NSRange(location: before.location, length: range.length + 2 * m)
                let inner = text.substring(with: range)
                guard shouldChangeText(in: full, replacementString: inner) else { return }
                replaceCharacters(in: full, with: inner)
                didChangeText()
                setSelectedRange(NSRange(location: before.location, length: range.length))
            } else {
                let inner = text.substring(with: range)
                let wrapped = marker + inner + marker
                guard shouldChangeText(in: range, replacementString: wrapped) else { return }
                replaceCharacters(in: range, with: wrapped)
                didChangeText()
                setSelectedRange(NSRange(location: range.location + m, length: range.length))
            }
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
                    if self.shouldChangeText(in: repRange, replacementString: "") {
                        self.replaceCharacters(in: repRange, with: "")
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
                    if self.shouldChangeText(in: repRange, replacementString: "") {
                        self.replaceCharacters(in: repRange, with: "")
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
                    if self.shouldChangeText(in: repRange, replacementString: "") {
                        self.replaceCharacters(in: repRange, with: "")
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
                    if self.shouldChangeText(in: repRange, replacementString: "") {
                        self.replaceCharacters(in: repRange, with: "")
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
            
            if currentLine.range(of: "^[ \\t]*([\\*\\-\\+]|\\d+\\.|[-*+] \\[[ xX]\\]) ", options: .regularExpression) != nil {
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
                
                if textBeforeCursor.range(of: "^[ \\t]*([\\*\\-\\+]|[-*+] \\[[ xX]\\]|\\d+\\.) $", options: .regularExpression) != nil {
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
            // 1. Check if clipboard contains image data (e.g. from ⌘⌃⇧4 screenshot or copied image)
            if let noteId = noteId, let res = NotesDataManager.shared.saveClipboardImage(for: noteId) {
                let markdownTag = "\n\n" + res.markdown + "\n\n"
                self.insertText(markdownTag, replacementRange: self.selectedRange())
                self.didChangeText()
                onImagePasted?()
                return
            }
            // 2. Smart Paste: convert HTML rich text to Markdown or clean cluttered plain text
            if let result = SmartPasteEngine.shared.processPasteboard(NSPasteboard.general) {
                self.insertText(result.text, replacementRange: self.selectedRange())
                self.didChangeText()
                if result.wasFormatted {
                    NotificationCenter.default.post(name: NSNotification.Name("SmartPasteApplied"), object: result.formatType)
                }
                return
            }
            // 3. Fallback to normal text paste
            super.paste(sender)
        }

        override func pasteAsPlainText(_ sender: Any?) {
            if let plainText = NSPasteboard.general.string(forType: .string) {
                self.insertText(plainText, replacementRange: self.selectedRange())
                self.didChangeText()
            } else {
                super.pasteAsPlainText(sender)
            }
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
        textView.textContainerInset = NSSize(width: 22, height: 18)
        
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
        paragraphStyle.lineSpacing = 6.0
        paragraphStyle.paragraphSpacing = 10.0
        textView.defaultParagraphStyle = paragraphStyle
        
        textView.textColor = isDark ? NSColor(red: 232/255, green: 238/255, blue: 246/255, alpha: 1.0) : NSColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
        textView.insertionPointColor = isDark ? NSColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0) : NSColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
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
                .cornerRadius(AppRadius.xs)
            
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
