import SwiftUI

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

    var allTags: [String] {
        var tagSet: Set<String> = []
        let pattern = "#([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        for note in activeNotes {
            let text = note.content
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: nsRange)
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    tagSet.insert(String(text[range]).lowercased())
                }
            }
        }
        return Array(tagSet).sorted()
    }

    var filteredNotes: [NoteItem] {
        guard let tag = selectedTag else { return activeNotes }
        return activeNotes.filter { $0.content.lowercased().contains("#\(tag.lowercased())") }
    }

    var groupedNotes: [String: [NoteItem]] {
        Dictionary(grouping: filteredNotes, by: { $0.folder })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            HStack {
                Text("whispNotes")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                
                Spacer()
                
                // + New Folder Button
                Button(action: { showNewFolderPopover.toggle() }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.amber)
                        .padding(6)
                        .background(Color.amber.opacity(0.12))
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

                // + New Note Button
                Button(action: createNewNote) {
                    Image(systemName: "plus")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(secondaryAccent)
                        .padding(6)
                        .background(secondaryAccent.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("New Note (⌘N)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
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
                                        Image(systemName: note.isStandalone ? "doc.text" : "waveform")
                                            .font(.caption)
                                            .foregroundColor(note.isStandalone ? .secondary : primaryAccent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            Text(note.timestamp, style: .date)
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .contextMenu {
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
                        },
                        label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.amber)
                                Text(folder)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
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
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text("In Trash")
                                                .font(.system(size: 9))
                                                .foregroundColor(primaryAccent)
                                        }
                                    }
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
                                    .font(.caption)
                                    .fontWeight(.bold)
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
}
