import SwiftUI

// MARK: - Wiki-Link Autocomplete Suggestion View
struct WikiLinkAutocompleteView: View {
    let query: String
    let notes: [NoteItem]
    let isDark: Bool
    let primaryAccent: Color
    var onSelect: (String) -> Void

    var matchingNotes: [NoteItem] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.isEmpty {
            return Array(notes.prefix(6))
        }
        return Array(notes.filter { $0.title.lowercased().contains(clean) }.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(primaryAccent)
                Text("Link to Note")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Divider()

            if matchingNotes.isEmpty {
                Button(action: { onSelect(query.isEmpty ? "New Note" : query) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                            .foregroundColor(primaryAccent)
                        Text("Create \"\(query.isEmpty ? "New Note" : query)\"")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(primaryAccent)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(matchingNotes) { note in
                    Button(action: { onSelect(note.title) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(note.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                                .lineLimit(1)
                            Spacer()
                            Text(note.folder)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.cardBackground(isDark).opacity(0.5))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(6)
        .frame(width: 240)
        .background(Color.panelBackground(isDark))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
    }
}
