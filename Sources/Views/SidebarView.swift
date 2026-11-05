import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sidebar View (With Dynamic Accents & Trash Bin)
struct SidebarView: View {
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @Binding var width: Double
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var createNewNote: () -> Void

    @State private var selectedTag: String? = nil
    @State private var searchText = ""
    @State private var showNewFolderPopover = false
    @State private var newFolderName = ""
    @State private var renamingFolder: String? = nil
    @State private var renameFolderInput = ""
    @State private var expandedFolders: [String: Bool] = [:]
    @State private var showEmptyTrashAlert = false
    @State private var targetedFolder: String? = nil
    @State private var isTrashTargeted = false

    var activeNotes: [NoteItem] {
        notes.filter { $0.folder != "Trash" }
    }

    var trashNotes: [NoteItem] {
        notes.filter { $0.folder == "Trash" }
    }

    var allTagsWithCount: [(tag: String, count: Int)] {
        VaultSearchEngine.extractAllTags(from: notes)
    }

    var filteredNotes: [NoteItem] {
        var result = activeNotes
        if let tag = selectedTag {
            result = result.filter { $0.content.lowercased().contains("#\(tag.lowercased())") }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { $0.title.lowercased().contains(query) || $0.content.lowercased().contains(query) }
        }
        return result
    }

    var pinnedNotes: [NoteItem] {
        filteredNotes.filter { $0.isPinned }
    }

    var unpinnedNotes: [NoteItem] {
        filteredNotes.filter { !$0.isPinned }
    }

    var groupedNotes: [String: [NoteItem]] {
        Dictionary(grouping: unpinnedNotes, by: { $0.folder })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            HStack(spacing: 6) {
                if let nsImg = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImg)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .cornerRadius(AppRadius.xs)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.xs)
                            .fill(
                                LinearGradient(
                                    colors: [primaryAccent, primaryAccent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 17, height: 17)
                        Image(systemName: "note.text")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text("whispNotes")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appText(isDark))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Spacer(minLength: 2)
                
                if width >= 265 {
                    // Full button cluster when wide
                    Button(action: { showNewFolderPopover.toggle() }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(AppRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .obsidianTooltip("New Folder")

                    Button(action: importNewPDFNote) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(AppRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .obsidianTooltip("Import Document (PDF / PPTX)")

                    Button(action: {
                        NotificationCenter.default.post(name: .openTemplatePicker, object: nil)
                    }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(AppRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .obsidianTooltip("New Note from Template", shortcut: "⌘T")
                } else {
                    // Compact dropdown menu for secondary actions when sidebar is slim
                    Menu {
                        Button(action: {
                            showNewFolderPopover = true
                        }) {
                            Label("New Folder…", systemImage: "folder.badge.plus")
                        }
                        Button(action: importNewPDFNote) {
                            Label("Import Document (PDF / PPTX)…", systemImage: "doc.badge.plus")
                        }
                        Button(action: {
                            NotificationCenter.default.post(name: .openTemplatePicker, object: nil)
                        }) {
                            Label("New Note from Template…", systemImage: "square.grid.2x2")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(AppRadius.sm)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20, height: 20)
                    .obsidianTooltip("More Note Actions")
                }

                // Calendar & Daily Notes Hub Button
                Button(action: {
                    NotificationCenter.default.post(name: .openCalendarHub, object: nil)
                }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .obsidianTooltip("Calendar & Daily Journal Hub", shortcut: "⌘⌥C")

                // + New Note Button (always prominent)
                Button(action: createNewNote) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(primaryAccent)
                        .frame(width: 20, height: 20)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .obsidianTooltip("New Note", shortcut: "⌘N")
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.sidebarBackground(isDark))
            .popover(isPresented: $showNewFolderPopover) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create New Folder")
                        .font(.caption)
                        .fontWeight(.bold)
                    TextField("Folder name", text: $newFolderName, onCommit: {
                        createFolder()
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    
                    Button("Create") { createFolder() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding()
            }
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.subtleBorder(isDark)),
                alignment: .bottom
            )
            
            // Real-Time Note Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("Search notes", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            .cornerRadius(AppRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .background(Color.subtleBorder(isDark))

            // Tags Cloud Selector
            if !allTagsWithCount.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("TAGS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedTag != nil {
                            Button("Clear") { selectedTag = nil }
                                .font(.caption2)
                                .foregroundColor(primaryAccent)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(allTagsWithCount, id: \.tag) { item in
                                Button(action: {
                                    if selectedTag == item.tag {
                                        selectedTag = nil
                                    } else {
                                        selectedTag = item.tag
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        Text("#\(item.tag)")
                                            .font(.system(size: 11, weight: .medium))
                                        Text("\(item.count)")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(selectedTag == item.tag ? .white.opacity(0.8) : .secondary)
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(selectedTag == item.tag ? primaryAccent : (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                                    .foregroundColor(selectedTag == item.tag ? .white : .primary)
                                    .cornerRadius(AppRadius.sm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 6)

                Divider()
                    .background(Color.subtleBorder(isDark))
            }

            // Sidebar accordion files list
            List {
                // 📌 Pinned Notes Section
                if !pinnedNotes.isEmpty {
                    Section(header:
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(primaryAccent)
                            Text("PINNED")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(pinnedNotes.count)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    ) {
                        ForEach(pinnedNotes) { note in
                            SidebarNoteRowView(
                                note: note,
                                isSelected: selectedNoteId == note.id,
                                isDark: isDark,
                                primaryAccent: primaryAccent,
                                secondaryAccent: secondaryAccent,
                                isPinned: true,
                                onSelect: {
                                    selectedNoteId = note.id
                                    TabNavigationManager.shared.openNote(note.id)
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                            .listRowBackground(Color.clear)
                            .onDrag {
                                NSItemProvider(object: note.id.uuidString as NSString)
                            }
                            .contextMenu {
                                Button(action: { togglePin(note) }) {
                                    Label("Unpin Note", systemImage: "pin.slash")
                                }

                                Button(action: {
                                    TabNavigationManager.shared.openNote(note.id, inNewTab: true)
                                }) {
                                    Label("Open in New Tab", systemImage: "plus.rectangle.on.rectangle")
                                }

                                Button(action: { duplicateNote(note) }) {
                                    Label("Duplicate Note", systemImage: "doc.on.doc")
                                }
                                
                                Menu("Move to Folder...") {
                                    ForEach(groupedNotes.keys.sorted(), id: \.self) { targetFolder in
                                        Button(targetFolder) {
                                            moveNote(note, to: targetFolder)
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                Button(role: .destructive, action: { moveToTrash(note) }) {
                                    Label("Move to Trash", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Regular Folders Section
                ForEach(groupedNotes.keys.sorted(), id: \.self) { folder in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedFolders[folder] ?? true },
                            set: { expandedFolders[folder] = $0 }
                        ),
                        content: {
                            let folderNotes = groupedNotes[folder] ?? []
                            if folderNotes.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text("No notes in \(folder)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .padding(.leading, 18)
                                .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                                .listRowBackground(Color.clear)
                            } else {
                                ForEach(folderNotes) { note in
                                    SidebarNoteRowView(
                                        note: note,
                                        isSelected: selectedNoteId == note.id,
                                        isDark: isDark,
                                        primaryAccent: primaryAccent,
                                        secondaryAccent: secondaryAccent,
                                        isPinned: false,
                                        onSelect: {
                                            selectedNoteId = note.id
                                            TabNavigationManager.shared.openNote(note.id)
                                        }
                                    )
                                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                                    .listRowBackground(Color.clear)
                                    .onDrag {
                                        NSItemProvider(object: note.id.uuidString as NSString)
                                    }
                                    .contextMenu {
                                        Button(action: { togglePin(note) }) {
                                            Label("Pin Note", systemImage: "pin.fill")
                                        }

                                        Button(action: {
                                            TabNavigationManager.shared.openNote(note.id, inNewTab: true)
                                        }) {
                                            Label("Open in New Tab", systemImage: "plus.rectangle.on.rectangle")
                                        }

                                        Button(action: { duplicateNote(note) }) {
                                            Label("Duplicate Note", systemImage: "doc.on.doc")
                                        }
                                        
                                        if note.pptxPath != nil {
                                            Button(action: {
                                                if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                                                    notes[idx].pptxPath = nil
                                                    NotesDataManager.shared.saveNotes(notes)
                                                }
                                            }) {
                                                Label("Detach Presentation", systemImage: "sparkles.tv")
                                            }
                                        } else if note.pdfPath != nil {
                                            Button(action: {
                                                if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                                                    notes[idx].pdfPath = nil
                                                    NotesDataManager.shared.saveNotes(notes)
                                                }
                                            }) {
                                                Label("Detach PDF Document", systemImage: "doc.badge.ellipsis")
                                            }
                                        } else {
                                            Button(action: { attachDocumentToNote(note) }) {
                                                Label("Attach PDF or Presentation…", systemImage: "paperclip")
                                            }
                                        }
                                        
                                        Menu("Move to Folder...") {
                                            ForEach(groupedNotes.keys.sorted(), id: \.self) { targetFolder in
                                                Button(targetFolder) {
                                                    moveNote(note, to: targetFolder)
                                                }
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        Button(role: .destructive, action: { moveToTrash(note) }) {
                                            Label("Move to Trash", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        },
                        label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(secondaryAccent)
                                Text(folder)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.appText(isDark))
                                
                                Spacer()
                                
                                let noteCount = (groupedNotes[folder] ?? []).count
                                Text("\(noteCount)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.appTextSecondary(isDark))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .fill(targetedFolder == folder ? secondaryAccent.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .stroke(targetedFolder == folder ? secondaryAccent.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], isTargeted: Binding(
                                get: { targetedFolder == folder },
                                set: { if $0 { targetedFolder = folder } else if targetedFolder == folder { targetedFolder = nil } }
                            )) { providers in
                                handleDrop(providers: providers, targetFolder: folder)
                            }
                            .contextMenu {
                                Button(action: {
                                    renamingFolder = folder
                                    renameFolderInput = folder
                                }) {
                                    Label("Rename Folder", systemImage: "pencil")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive, action: { deleteFolder(folder) }) {
                                    Label("Delete Folder", systemImage: "trash")
                                }
                            }
                        }
                    )
                }

                // Dedicated Trash Folder Bin
                if !trashNotes.isEmpty {
                    DisclosureGroup(
                        content: {
                            ForEach(trashNotes) { note in
                                SidebarTrashNoteRowView(
                                    note: note,
                                    isSelected: selectedNoteId == note.id,
                                    isDark: isDark,
                                    primaryAccent: primaryAccent,
                                    onSelect: {
                                        selectedNoteId = note.id
                                        TabNavigationManager.shared.openNote(note.id)
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                                .listRowBackground(Color.clear)
                                .onDrag {
                                    NSItemProvider(object: note.id.uuidString as NSString)
                                }
                                .contextMenu {
                                    Button(action: { restoreFromTrash(note) }) {
                                        Label("Restore Note (to \(note.originalFolder ?? "General"))", systemImage: "arrow.uturn.backward")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: { deletePermanently(note) }) {
                                        Label("Delete Permanently", systemImage: "trash.slash")
                                    }
                                }
                            }
                        },
                        label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.appTextSecondary(isDark))
                                Text("Trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.appTextBody(isDark))
                                Text("(\(trashNotes.count))")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.appTextSecondary(isDark))
                                
                                Spacer()
                                
                                Button(action: {
                                    showEmptyTrashAlert = true
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "trash.slash")
                                            .font(.system(size: 9))
                                        Text("Empty Trash")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.12))
                                    .foregroundColor(SemanticColor.destructive)
                                    .cornerRadius(AppRadius.xs)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Empty Trash Bin")
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .fill(isTrashTargeted ? primaryAccent.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .stroke(isTrashTargeted ? primaryAccent.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], isTargeted: $isTrashTargeted) { providers in
                                handleDrop(providers: providers, targetFolder: "Trash")
                            }
                            .alert("Empty Trash Permanently?", isPresented: $showEmptyTrashAlert) {
                                Button("Empty Trash", role: .destructive) {
                                    emptyTrashPermanently()
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("This will permanently delete all \(trashNotes.count) items in the trash. This action cannot be undone.")
                            }
                        }
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color.sidebarBackground(isDark))
        .popover(isPresented: Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rename Folder")
                    .font(.caption)
                    .fontWeight(.bold)
                TextField("New folder name", text: $renameFolderInput, onCommit: {
                    if let old = renamingFolder {
                        renameFolder(old, to: renameFolderInput)
                        renamingFolder = nil
                    }
                })
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                
                Button("Save") {
                    if let old = renamingFolder {
                        renameFolder(old, to: renameFolderInput)
                        renamingFolder = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .filterNotesByTag)) { notif in
            if let tag = notif.object as? String {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedTag = tag
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notesRestoredFromUndo)) { notif in
            if let restored = notif.object as? [NoteItem] {
                withAnimation(.easeInOut(duration: 0.15)) {
                    notes = restored
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], targetFolder: String) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            var targetIdStr: String? = nil
            if let data = item as? Data {
                targetIdStr = String(data: data, encoding: .utf8)
            } else if let str = item as? String {
                targetIdStr = str
            } else if let nsStr = item as? NSString {
                targetIdStr = nsStr as String
            }
            
            if let idStr = targetIdStr, let noteId = UUID(uuidString: idStr) {
                DispatchQueue.main.async {
                    let previous = self.notes
                    if let idx = self.notes.firstIndex(where: { $0.id == noteId }) {
                        if targetFolder == "Trash" {
                            self.notes[idx].originalFolder = self.notes[idx].folder
                            self.notes[idx].isPinned = false
                        }
                        self.notes[idx].folder = targetFolder
                        NotesDataManager.shared.saveNotes(self.notes)
                        NotesDataManager.shared.registerStructuralUndo(actionName: "Move Note", previousState: previous)
                    }
                }
            }
        }
        return true
    }

    private func createFolder() {
        let clean = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let newNote = NoteItem(
            title: "Untitled Note",
            folder: clean,
            content: "# Untitled Note\n\nNotes in \(clean)...",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        notes.insert(newNote, at: 0)
        selectedNoteId = newNote.id
        NotesDataManager.shared.saveNotes(notes)
        showNewFolderPopover = false
        newFolderName = ""
    }

    private func renameFolder(_ oldName: String, to newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty && clean != oldName else { return }
        let previous = notes
        for i in 0..<notes.count {
            if notes[i].folder == oldName {
                notes[i].folder = clean
            }
        }
        NotesDataManager.shared.saveNotes(notes)
        NotesDataManager.shared.registerStructuralUndo(actionName: "Rename Folder", previousState: previous)
    }

    private func deleteFolder(_ folder: String) {
        let previous = notes
        for i in 0..<notes.count {
            if notes[i].folder == folder {
                notes[i].folder = "General"
            }
        }
        NotesDataManager.shared.saveNotes(notes)
        NotesDataManager.shared.registerStructuralUndo(actionName: "Delete Folder", previousState: previous)
    }

    private func togglePin(_ note: NoteItem) {
        let previous = notes
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isPinned.toggle()
            NotesDataManager.shared.saveNotes(notes)
            NotesDataManager.shared.registerStructuralUndo(actionName: "Toggle Pin", previousState: previous)
        }
    }

    private func duplicateNote(_ note: NoteItem) {
        let previous = notes
        var copy = note
        copy.id = UUID()
        copy.title = "\(note.title) (Copy)"
        copy.timestamp = Date()
        notes.insert(copy, at: 0)
        selectedNoteId = copy.id
        NotesDataManager.shared.saveNotes(notes)
        NotesDataManager.shared.registerStructuralUndo(actionName: "Duplicate Note", previousState: previous)
    }

    private func emptyTrashPermanently() {
        let previous = notes
        notes.removeAll(where: { $0.folder == "Trash" })
        if let id = selectedNoteId, !notes.contains(where: { $0.id == id }) {
            selectedNoteId = notes.first?.id
        }
        NotesDataManager.shared.saveNotesImmediately(notes)
        NotesDataManager.shared.registerStructuralUndo(actionName: "Empty Trash", previousState: previous)
    }

    private func moveNote(_ note: NoteItem, to folder: String) {
        let previous = notes
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].folder = folder
            NotesDataManager.shared.saveNotes(notes)
            NotesDataManager.shared.registerStructuralUndo(actionName: "Move to \(folder)", previousState: previous)
        }
    }

    private func moveToTrash(_ note: NoteItem) {
        let previous = notes
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].originalFolder = note.folder
            notes[idx].isPinned = false
            notes[idx].folder = "Trash"
            NotesDataManager.shared.saveNotes(notes)
            NotesDataManager.shared.registerStructuralUndo(actionName: "Move to Trash", previousState: previous)
        }
    }

    private func restoreFromTrash(_ note: NoteItem) {
        let previous = notes
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            let targetFolder = note.originalFolder ?? "General"
            notes[idx].folder = targetFolder == "Trash" ? "General" : targetFolder
            NotesDataManager.shared.saveNotes(notes)
            NotesDataManager.shared.registerStructuralUndo(actionName: "Restore Note", previousState: previous)
        }
    }

    private func deletePermanently(_ note: NoteItem) {
        let previous = notes
        notes.removeAll(where: { $0.id == note.id })
        if selectedNoteId == note.id {
            selectedNoteId = activeNotes.first?.id
        }
        NotesDataManager.shared.saveNotes(notes)
        NotesDataManager.shared.registerStructuralUndo(actionName: "Delete Note", previousState: previous)
    }

    private func importNewPDFNote() {
        let panel = NSOpenPanel()
        panel.title = "Import PDF Document as New Note"
        var contentTypes: [UTType] = [.pdf]
        if let pptxType = UTType(filenameExtension: "pptx") {
            contentTypes.append(pptxType)
        }
        if let pptxTypeOrg = UTType("org.openxmlformats.presentationml.presentation") {
            contentTypes.append(pptxTypeOrg)
        }
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let noteId = UUID()
                let title = (url.lastPathComponent as NSString).deletingPathExtension
                let ext = url.pathExtension.lowercased()
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: noteId) {
                    let newNote = NoteItem(
                        id: noteId,
                        title: title,
                        folder: "General",
                        content: "# \(title)\n\nAttached \(ext == "pptx" ? "Presentation" : "Document"): `\(url.lastPathComponent)`",
                        timestamp: Date(),
                        audioPath: nil,
                        transcript: [],
                        isStandalone: true,
                        bookmarks: [],
                        pdfPath: ext == "pdf" ? relPath : nil,
                        pptxPath: ext == "pptx" ? relPath : nil
                    )
                    notes.insert(newNote, at: 0)
                    selectedNoteId = newNote.id
                    NotesDataManager.shared.saveNotes(notes)
                }
            }
        }
    }

    private func attachDocumentToNote(_ note: NoteItem) {
        let panel = NSOpenPanel()
        panel.title = "Attach PDF or Presentation to Note"
        var contentTypes: [UTType] = [.pdf]
        if let pptxType = UTType(filenameExtension: "pptx") {
            contentTypes.append(pptxType)
        }
        if let pptxTypeOrg = UTType("org.openxmlformats.presentationml.presentation") {
            contentTypes.append(pptxTypeOrg)
        }
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let ext = url.pathExtension.lowercased()
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: note.id) {
                    if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                        if ext == "pptx" {
                            notes[idx].pptxPath = relPath
                        } else {
                            notes[idx].pdfPath = relPath
                        }
                        NotesDataManager.shared.saveNotes(notes)
                    }
                }
            }
        }
    }
}

// MARK: - Dedicated Theme-Adaptive Sidebar Note Row Component
struct SidebarNoteRowView: View {
    let note: NoteItem
    let isSelected: Bool
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var isPinned: Bool = false
    let onSelect: () -> Void
    
    @AppStorage("colorTheme") private var colorTheme = "Classic Minimal"
    @State private var isHovered: Bool = false
    
    private var isLightAccent: Bool {
        Color.onAccent(isDark, themeName: colorTheme) != .white
    }
    
    private var selectedTitleColor: Color {
        isLightAccent ? Color(red: 15/255, green: 23/255, blue: 42/255) : .white
    }
    
    private var selectedSecondaryColor: Color {
        isLightAccent ? Color(red: 71/255, green: 85/255, blue: 105/255) : Color.white.opacity(0.85)
    }
    
    private var selectedExcerptColor: Color {
        isLightAccent ? Color(red: 51/255, green: 65/255, blue: 85/255) : Color.white.opacity(0.9)
    }
    
    private var selectedIconColor: Color {
        isLightAccent ? Color(red: 15/255, green: 23/255, blue: 42/255) : .white
    }
    
    private var titleText: String {
        note.title.isEmpty ? "Untitled Note" : note.title
    }

    /// Today shows the time, this year "Jul 20", older notes "Jul 20, 2025".
    private var compactDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(note.timestamp) {
            return note.timestamp.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDate(note.timestamp, equalTo: Date(), toGranularity: .year) {
            return note.timestamp.formatted(.dateTime.month(.abbreviated).day())
        }
        return note.timestamp.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var excerptText: String {
        // Skip a leading "# Title" line so the excerpt doesn't just repeat the title.
        var body = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = body.split(separator: "\n", maxSplits: 1).first,
           firstLine.hasPrefix("#"),
           firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).caseInsensitiveCompare(titleText) == .orderedSame {
            body = String(body.dropFirst(firstLine.count))
        }
        let clean = body
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "No additional text" : clean
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                // Leading Icon
                Group {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? selectedIconColor : primaryAccent)
                    } else if note.pptxPath != nil {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? selectedIconColor : primaryAccent)
                    } else if note.pdfPath != nil {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? selectedIconColor : SemanticColor.pdfBadge)
                    } else if note.audioPath != nil {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? selectedIconColor : SemanticColor.audioBadge)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? selectedIconColor : Color.appTextSecondary(isDark))
                    }
                }
                .frame(width: 14)
                .padding(.top, 2)
                
                // Note Metadata & Excerpt
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? selectedTitleColor : Color.appText(isDark))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    // Date + 1-line clean markdown excerpt, like Notes and Mail
                    HStack(spacing: AppSpacing.sm) {
                        Text(compactDate)
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(isSelected ? selectedSecondaryColor : Color.appTextSecondary(isDark))
                            .fixedSize()
                        Text(excerptText)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(isSelected ? selectedExcerptColor : Color.appTextMuted(isDark))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    // Badges (PDF, Slides, Folder)
                    if note.pdfPath != nil || note.pptxPath != nil || isPinned {
                        HStack(spacing: 4) {
                            if note.pptxPath != nil {
                                Text("SLIDES")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(isSelected ? (isLightAccent ? Color.black.opacity(0.12) : Color.white.opacity(0.25)) : primaryAccent.opacity(0.15))
                                    .foregroundColor(isSelected ? (isLightAccent ? Color(red: 15/255, green: 23/255, blue: 42/255) : .white) : primaryAccent)
                                    .cornerRadius(AppRadius.xs)
                            } else if note.pdfPath != nil {
                                Text("PDF")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(isSelected ? (isLightAccent ? Color.black.opacity(0.12) : Color.white.opacity(0.25)) : SemanticColor.pdfSurface)
                                    .foregroundColor(isSelected ? (isLightAccent ? Color(red: 15/255, green: 23/255, blue: 42/255) : .white) : SemanticColor.pdfBadge)
                                    .cornerRadius(AppRadius.xs)
                            }
                            
                            if isPinned {
                                Text(note.folder)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(isSelected ? selectedSecondaryColor : secondaryAccent)
                            }
                        }
                        .padding(.top, 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(
                        isSelected
                            ? primaryAccent
                            : (isHovered ? (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Sidebar Trash Note Row Component
struct SidebarTrashNoteRowView: View {
    let note: NoteItem
    let isSelected: Bool
    let isDark: Bool
    let primaryAccent: Color
    let onSelect: () -> Void
    
    @AppStorage("colorTheme") private var colorTheme = "Classic Minimal"
    @State private var isHovered: Bool = false
    
    private var isLightAccent: Bool {
        Color.onAccent(isDark, themeName: colorTheme) != .white
    }
    
    private var selectedTitleColor: Color {
        isLightAccent ? Color(red: 15/255, green: 23/255, blue: 42/255) : .white
    }
    
    private var selectedSecondaryColor: Color {
        isLightAccent ? Color(red: 71/255, green: 85/255, blue: 105/255) : Color.white.opacity(0.85)
    }
    
    private var selectedIconColor: Color {
        isLightAccent ? Color(red: 15/255, green: 23/255, blue: 42/255) : .white
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(isSelected ? selectedIconColor : Color.appTextSecondary(isDark))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? selectedTitleColor : Color.appTextMuted(isDark))
                        .lineLimit(1)
                    
                    Text("From: \(note.originalFolder ?? "General")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? selectedSecondaryColor : Color.appTextSecondary(isDark))
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(
                        isSelected
                            ? primaryAccent
                            : (isHovered ? (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
