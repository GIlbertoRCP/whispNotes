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

    var activeNotes: [NoteItem] {
        notes.filter { $0.folder != "Trash" }
    }

    var trashNotes: [NoteItem] {
        notes.filter { $0.folder == "Trash" }
    }

    @State private var cachedTags: [String] = []

    var allTags: [String] {
        cachedTags
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

    var groupedNotes: [String: [NoteItem]] {
        Dictionary(grouping: filteredNotes, by: { $0.folder })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            HStack(spacing: 8) {
                if let nsImg = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImg)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16))
                        .foregroundColor(primaryAccent)
                }
                
                Text("whispNotes")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                
                Spacer()
                
                // + New Folder Button
                Button(action: { showNewFolderPopover.toggle() }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryAccent)
                        .frame(width: 26, height: 26)
                        .background(secondaryAccent.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("New Folder")
                .popover(isPresented: $showNewFolderPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create New Folder")
                            .font(.caption)
                            .fontWeight(.bold)
                        TextField("Folder name...", text: $newFolderName, onCommit: {
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

                // + Import PDF Document Button
                Button(action: importNewPDFNote) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryAccent)
                        .frame(width: 26, height: 26)
                        .background(secondaryAccent.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Import PDF Document Note")

                // + New Note Button
                Button(action: createNewNote) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(primaryAccent)
                        .frame(width: 26, height: 26)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("New Note (⌘N)")
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.sidebarBackground(isDark))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.subtleBorder(isDark)),
                alignment: .bottom
            )
            
            // Real-Time Note Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("Search notes...", text: $searchText)
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
            .padding(.vertical, 6)
            .background(Color.cardBackground(isDark))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .background(Color.subtleBorder(isDark))

            // Tags Cloud Selector
            if !allTags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TAGS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        if selectedTag != nil {
                            Button("Clear") { selectedTag = nil }
                                .font(.caption2)
                                .foregroundColor(primaryAccent)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(allTags, id: \.self) { tag in
                                Button(action: {
                                    if selectedTag == tag {
                                        selectedTag = nil
                                    } else {
                                        selectedTag = tag
                                    }
                                }) {
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedTag == tag ? primaryAccent : Color.cardBackground(isDark))
                                        .foregroundColor(selectedTag == tag ? .white : primaryAccent)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)

                Divider()
                    .background(Color.subtleBorder(isDark))
            }

            // Sidebar accordion files list
            List(selection: $selectedNoteId) {
                ForEach(groupedNotes.keys.sorted(), id: \.self) { folder in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedFolders[folder] ?? true },
                            set: { expandedFolders[folder] = $0 }
                        ),
                        content: {
                            ForEach(groupedNotes[folder] ?? []) { note in
                                NavigationLink(value: note.id) {
                                    HStack(spacing: 8) {
                                        if note.pdfPath != nil {
                                            Image(systemName: "doc.richtext.fill")
                                                .font(.caption)
                                                .foregroundColor(primaryAccent)
                                        } else {
                                            Image(systemName: note.isStandalone ? "doc.text" : "waveform")
                                                .font(.caption)
                                                .foregroundColor(note.isStandalone ? (isDark ? .secondary : Color(red: 71/255, green: 85/255, blue: 105/255)) : primaryAccent)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                                                .lineLimit(1)
                                            HStack(spacing: 4) {
                                                if note.pdfPath != nil {
                                                    Text("PDF")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(primaryAccent.opacity(0.18))
                                                        .foregroundColor(primaryAccent)
                                                        .cornerRadius(3)
                                                }
                                                Text(note.timestamp, style: .date)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundColor(isDark ? .secondary : Color(red: 100/255, green: 116/255, blue: 139/255))
                                            }
                                        }
                                    }
                                }
                                .onDrag {
                                    NSItemProvider(object: note.id.uuidString as NSString)
                                }
                                .contextMenu {
                                    Button(action: { duplicateNote(note) }) {
                                        Label("Duplicate Note", systemImage: "doc.on.doc")
                                    }
                                    
                                    if note.pdfPath != nil {
                                        Button(action: {
                                            if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                                                notes[idx].pdfPath = nil
                                                NotesDataManager.shared.saveNotes(notes)
                                            }
                                        }) {
                                            Label("Detach PDF Document", systemImage: "doc.badge.ellipsis")
                                        }
                                    } else {
                                        Button(action: { attachPDFToNote(note) }) {
                                            Label("Attach PDF Document...", systemImage: "paperclip")
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
                        },
                        label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(secondaryAccent)
                                Text(folder)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(isDark ? .secondary : Color(red: 51/255, green: 65/255, blue: 85/255))
                                
                                Spacer()
                                
                                let noteCount = (groupedNotes[folder] ?? []).count
                                Text("\(noteCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(secondaryAccent.opacity(0.15))
                                    .foregroundColor(secondaryAccent)
                                    .clipShape(Capsule())
                            }
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], isTargeted: nil) { providers in
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
                                NavigationLink(value: note.id) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(primaryAccent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(isDark ? .secondary : Color(red: 71/255, green: 85/255, blue: 105/255))
                                            Text("In Trash")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(primaryAccent)
                                        }
                                    }
                                }
                                .onDrag {
                                    NSItemProvider(object: note.id.uuidString as NSString)
                                }
                                .contextMenu {
                                    Button(action: { restoreFromTrash(note) }) {
                                        Label("Restore Note", systemImage: "arrow.uturn.backward")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: { deletePermanently(note) }) {
                                        Label("Delete Permanently", systemImage: "trash.slash")
                                    }
                                }
                            }
                        },
                        label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(primaryAccent)
                                Text("Trash Bin (\(trashNotes.count))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(primaryAccent)
                                Spacer()
                                Button("Empty") {
                                    showEmptyTrashAlert = true
                                }
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red)
                                .buttonStyle(.plain)
                                .alert("Empty Trash Permanently?", isPresented: $showEmptyTrashAlert) {
                                    Button("Empty Trash", role: .destructive) {
                                        emptyTrashPermanently()
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("This will permanently delete all \(trashNotes.count) items in the trash. This action cannot be undone.")
                                }
                            }
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], isTargeted: nil) { providers in
                                handleDrop(providers: providers, targetFolder: "Trash")
                            }
                        }
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color.sidebarBackground(isDark))
        .onAppear {
            refreshTagsAsync()
        }
        .onChange(of: notes.count) { _, _ in
            refreshTagsAsync()
        }
        .popover(isPresented: Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rename Folder")
                    .font(.caption)
                    .fontWeight(.bold)
                TextField("New folder name...", text: $renameFolderInput, onCommit: {
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
                    if let idx = self.notes.firstIndex(where: { $0.id == noteId }) {
                        self.notes[idx].folder = targetFolder
                        NotesDataManager.shared.saveNotes(self.notes)
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
        for i in 0..<notes.count {
            if notes[i].folder == oldName {
                notes[i].folder = clean
            }
        }
        NotesDataManager.shared.saveNotes(notes)
    }

    private func deleteFolder(_ folder: String) {
        for i in 0..<notes.count {
            if notes[i].folder == folder {
                notes[i].folder = "General"
            }
        }
        NotesDataManager.shared.saveNotes(notes)
    }

    private func duplicateNote(_ note: NoteItem) {
        var copy = note
        copy.id = UUID()
        copy.title = "\(note.title) (Copy)"
        copy.timestamp = Date()
        notes.insert(copy, at: 0)
        selectedNoteId = copy.id
        NotesDataManager.shared.saveNotes(notes)
    }

    private func emptyTrashPermanently() {
        notes.removeAll(where: { $0.folder == "Trash" })
        if let id = selectedNoteId, !notes.contains(where: { $0.id == id }) {
            selectedNoteId = notes.first?.id
        }
        NotesDataManager.shared.saveNotesImmediately(notes)
    }

    private func moveNote(_ note: NoteItem, to folder: String) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].folder = folder
            NotesDataManager.shared.saveNotes(notes)
        }
    }

    private func moveToTrash(_ note: NoteItem) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].folder = "Trash"
            NotesDataManager.shared.saveNotes(notes)
        }
    }

    private func restoreFromTrash(_ note: NoteItem) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].folder = "General"
            NotesDataManager.shared.saveNotes(notes)
        }
    }

    private func deletePermanently(_ note: NoteItem) {
        notes.removeAll(where: { $0.id == note.id })
        if selectedNoteId == note.id {
            selectedNoteId = activeNotes.first?.id
        }
        NotesDataManager.shared.saveNotes(notes)
    }

    private func importNewPDFNote() {
        let panel = NSOpenPanel()
        panel.title = "Import PDF Document as New Note"
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let noteId = UUID()
                let title = (url.lastPathComponent as NSString).deletingPathExtension
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: noteId) {
                    let newNote = NoteItem(
                        id: noteId,
                        title: title,
                        folder: "General",
                        content: "# \(title)\n\nAttached Document: `\(url.lastPathComponent)`",
                        timestamp: Date(),
                        audioPath: nil,
                        transcript: [],
                        isStandalone: true,
                        bookmarks: [],
                        pdfPath: relPath
                    )
                    notes.insert(newNote, at: 0)
                    selectedNoteId = newNote.id
                    NotesDataManager.shared.saveNotes(notes)
                }
            }
        }
    }

    private func attachPDFToNote(_ note: NoteItem) {
        let panel = NSOpenPanel()
        panel.title = "Attach PDF to Note"
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let (relPath, _) = NotesDataManager.shared.importAttachment(from: url, for: note.id) {
                    if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                        notes[idx].pdfPath = relPath
                        NotesDataManager.shared.saveNotes(notes)
                    }
                }
            }
        }
    }

    private func refreshTagsAsync() {
        DispatchQueue.global(qos: .userInitiated).async {
            var tagSet: Set<String> = []
            let pattern = "#([a-zA-Z0-9_]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            
            let active = self.notes.filter { $0.folder != "Trash" }
            for note in active {
                let text = note.content
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                let matches = regex.matches(in: text, range: nsRange)
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        tagSet.insert(String(text[range]).lowercased())
                    }
                }
            }
            let sorted = Array(tagSet).sorted()
            DispatchQueue.main.async {
                self.cachedTags = sorted
            }
        }
    }
}
