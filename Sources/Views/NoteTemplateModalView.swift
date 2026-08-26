import SwiftUI

// MARK: - Note Template Picker Modal
struct NoteTemplateModalView: View {
    @Binding var isOpen: Bool
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @State private var selectedTemplate: NoteTemplate = TemplateLibrary.meetingNotes
    @State private var customTitle: String = ""
    
    init(
        isOpen: Binding<Bool>,
        notes: Binding<[NoteItem]>,
        selectedNoteId: Binding<UUID?>,
        isDark: Bool,
        primaryAccent: Color,
        secondaryAccent: Color
    ) {
        self._isOpen = isOpen
        self._notes = notes
        self._selectedNoteId = selectedNoteId
        self.isDark = isDark
        self.primaryAccent = primaryAccent
        self.secondaryAccent = secondaryAccent
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(primaryAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("NOTE TEMPLATES")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(isDark ? .white : .black)
                    Text("Select a pre-structured template to accelerate your notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color.sidebarBackground(isDark))
            
            Divider()
                .background(Color.subtleBorder(isDark))
            
            // Body Split: Template List & Live Preview
            HStack(spacing: 0) {
                // Left: Template List
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(TemplateLibrary.allTemplates) { template in
                            Button(action: { selectedTemplate = template }) {
                                HStack(spacing: 10) {
                                    Image(systemName: template.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(selectedTemplate.id == template.id ? primaryAccent : .secondary)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.title)
                                            .font(.system(size: 12, weight: selectedTemplate.id == template.id ? .bold : .medium))
                                            .foregroundColor(selectedTemplate.id == template.id ? (isDark ? .white : .black) : .primary)
                                        
                                        Text(template.description)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .fill(selectedTemplate.id == template.id ? primaryAccent.opacity(0.14) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .stroke(selectedTemplate.id == template.id ? primaryAccent.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
                .frame(width: 260)
                .background(Color.sidebarBackground(isDark))
                
                Divider()
                    .background(Color.subtleBorder(isDark))
                
                // Right: Template Preview & Action
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(selectedTemplate.resolveContent(title: customTitle.isEmpty ? selectedTemplate.title : customTitle, folder: selectedTemplate.defaultFolder))
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(isDark ? Color(red: 226/255, green: 232/255, blue: 240/255) : Color(red: 15/255, green: 23/255, blue: 42/255))
                                .textSelection(.enabled)
                                .padding(16)
                        }
                    }
                    .background(Color.panelBackground(isDark))
                    
                    Divider()
                        .background(Color.subtleBorder(isDark))
                    
                    // Bottom Controls
                    HStack(spacing: 12) {
                        TextField("Note Title (optional)...", text: $customTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 240)
                        
                        Spacer()
                        
                        Button("Cancel") {
                            isOpen = false
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        Button(action: createNoteFromTemplate) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Create from Template")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(primaryAccent)
                            .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color.sidebarBackground(isDark))
                }
            }
        }
        .frame(width: 720, height: 480)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .preferredColorScheme(isDark ? .dark : .light)
    }
    
    private func createNoteFromTemplate() {
        let finalTitle = customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedTemplate.title : customTitle
        let resolvedMarkdown = selectedTemplate.resolveContent(title: finalTitle, folder: selectedTemplate.defaultFolder)
        
        let newNote = NoteItem(
            title: finalTitle,
            folder: selectedTemplate.defaultFolder,
            content: resolvedMarkdown,
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        
        notes.insert(newNote, at: 0)
        NotesDataManager.shared.saveNotes(notes)
        selectedNoteId = newNote.id
        TabNavigationManager.shared.openNote(newNote.id, inNewTab: true)
        isOpen = false
    }
}
