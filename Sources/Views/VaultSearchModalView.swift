import SwiftUI

// MARK: - Vault Full-Text Deep Search Modal (⌘⇧F)
struct VaultSearchModalView: View {
    @Binding var isOpen: Bool
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    
    @StateObject private var searchEngine = VaultSearchEngine.shared
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("colorTheme") private var colorTheme = "Classic Minimal"
    
    @State private var searchResults: [NoteSearchResult] = []
    @State private var selectedMatchIndex: Int = 0
    @State private var expandedNotes: Set<UUID> = []
    
    private var primaryAccent: Color {
        ThemeColors.primary(colorTheme)
    }
    
    private var totalMatchCount: Int {
        searchResults.reduce(0) { $0 + $1.totalMatches }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(primaryAccent)
                    
                    TextField("Search all notes, markdown text, transcripts, and #tags...", text: $searchEngine.query)
                        .font(.headline)
                        .textFieldStyle(.plain)
                        .onChange(of: searchEngine.query) { _, _ in
                            runSearch()
                        }
                    
                    if !searchEngine.query.isEmpty {
                        Button(action: {
                            searchEngine.query = ""
                            runSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: { isOpen = false }) {
                        Text("Esc")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.panelBackground(isDarkMode))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color.sidebarBackground(isDarkMode))
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Filter & Options Bar
                HStack(spacing: 12) {
                    // Type Filter Pills
                    HStack(spacing: 4) {
                        ForEach(SearchFilterType.allCases) { type in
                            Button(action: {
                                searchEngine.filterType = type
                                runSearch()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: type.iconName)
                                        .font(.caption2)
                                    Text(type.rawValue)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(searchEngine.filterType == type ? primaryAccent.opacity(0.18) : Color.clear)
                                .foregroundColor(searchEngine.filterType == type ? primaryAccent : .secondary)
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Color.panelBackground(isDarkMode))
                    .cornerRadius(7)
                    
                    Spacer()
                    
                    // Match Case Toggle
                    Button(action: {
                        searchEngine.matchCase.toggle()
                        runSearch()
                    }) {
                        Text("Aa")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(searchEngine.matchCase ? primaryAccent.opacity(0.18) : Color.panelBackground(isDarkMode))
                            .foregroundColor(searchEngine.matchCase ? primaryAccent : .secondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Match Case")
                    
                    // Whole Word Toggle
                    Button(action: {
                        searchEngine.wholeWord.toggle()
                        runSearch()
                    }) {
                        Text("\\b")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(searchEngine.wholeWord ? primaryAccent.opacity(0.18) : Color.panelBackground(isDarkMode))
                            .foregroundColor(searchEngine.wholeWord ? primaryAccent : .secondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Whole Word Only")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.sidebarBackground(isDarkMode).opacity(0.5))
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Search Results Status Header
                if !searchEngine.query.isEmpty {
                    HStack {
                        Text("\(totalMatchCount) matches in \(searchResults.count) notes")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Expand All") {
                            expandedNotes = Set(searchResults.map { $0.id })
                        }
                        .font(.caption2)
                        .foregroundColor(primaryAccent)
                        .buttonStyle(.plain)
                        
                        Button("Collapse All") {
                            expandedNotes.removeAll()
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.panelBackground(isDarkMode))
                }
                
                // Results List
                ScrollView {
                    if searchEngine.query.isEmpty {
                        WhispEmptyStateView(
                            icon: "text.magnifyingglass",
                            title: "Search Entire Vault",
                            description: "Find any keyword across all notes, markdown content, #tags, and audio transcripts."
                        )
                        .frame(height: 280)
                    } else if searchResults.isEmpty {
                        WhispEmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Matching Results",
                            description: "No notes matched \"\(searchEngine.query)\". Try adjusting filters or keyword terms."
                        )
                        .frame(height: 280)
                    } else {
                        ForEach(searchResults) { result in
                            NoteSearchResultCard(
                                result: result,
                                isExpanded: expandedNotes.contains(result.id),
                                query: searchEngine.query,
                                matchCase: searchEngine.matchCase,
                                isDark: isDarkMode,
                                primaryAccent: primaryAccent,
                                onToggleExpand: {
                                    if expandedNotes.contains(result.id) {
                                        expandedNotes.remove(result.id)
                                    } else {
                                        expandedNotes.insert(result.id)
                                    }
                                },
                                onSelectMatch: { match in
                                    openNote(result.note)
                                }
                            )
                        }
                    }
                }
                .padding(12)
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Footer
                HStack {
                    HStack(spacing: 12) {
                        Text("Search: **⌘⇧F**")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Quick Switcher: **⌘K**")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Close") { isOpen = false }
                        .font(.caption)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.sidebarBackground(isDarkMode))
            }
            .frame(width: 700, height: 540)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .fill(Color.panelBackground(isDarkMode).opacity(0.85))
                    )
            )
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
            .onAppear {
                runSearch()
            }
        }
    
    private func runSearch() {
        searchResults = searchEngine.performSearch(in: notes)
        expandedNotes = Set(searchResults.map { $0.id })
    }
    
    private func openNote(_ note: NoteItem) {
        TabNavigationManager.shared.openNote(note.id)
        selectedNoteId = note.id
        isOpen = false
    }
}

// MARK: - Note Search Result Card
struct NoteSearchResultCard: View {
    let result: NoteSearchResult
    let isExpanded: Bool
    let query: String
    let matchCase: Bool
    let isDark: Bool
    let primaryAccent: Color
    let onToggleExpand: () -> Void
    let onSelectMatch: (SearchMatchItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Note Header Row
            Button(action: onToggleExpand) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: result.note.pdfPath != nil ? "doc.richtext" : (result.note.audioPath != nil ? "waveform" : "doc.text"))
                        .font(.caption)
                        .foregroundColor(primaryAccent)
                    
                    Text(result.note.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isDark ? .white : .black)
                    
                    Text("•  \(result.note.folder)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(result.totalMatches) matches")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(primaryAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.sidebarBackground(isDark))
            }
            .buttonStyle(.plain)
            
            // Expanded Matching Lines
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(result.matches) { match in
                        Button(action: { onSelectMatch(match) }) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("L\(match.lineNumber)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, alignment: .trailing)
                                
                                Image(systemName: match.matchType.iconName)
                                    .font(.system(size: 9))
                                    .foregroundColor(primaryAccent)
                                    .padding(.top, 2)
                                
                                HighlightedSnippetText(
                                    content: match.lineContent,
                                    query: query,
                                    matchCase: matchCase,
                                    primaryAccent: primaryAccent,
                                    isDark: isDark
                                )
                                .font(.system(size: 11))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.cardBackground(isDark).opacity(0.6))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
            }
        }
        .background(Color.cardBackground(isDark))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
    }
}

// MARK: - Highlighted Snippet Text View
struct HighlightedSnippetText: View {
    let content: String
    let query: String
    let matchCase: Bool
    let primaryAccent: Color
    let isDark: Bool
    
    var body: some View {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery.isEmpty {
            Text(content)
                .foregroundColor(.secondary)
        } else {
            let options: NSString.CompareOptions = matchCase ? [] : [.caseInsensitive]
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            
            Text(attributedString(for: trimmed, query: cleanQuery, options: options))
        }
    }
    
    private func attributedString(for text: String, query: String, options: NSString.CompareOptions) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = isDark ? Color(red: 203/255, green: 213/255, blue: 225/255) : Color(red: 51/255, green: 65/255, blue: 85/255)
        
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: query, options: options, range: searchRange) {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].foregroundColor = primaryAccent
                attributed[attrRange].font = .system(size: 11, weight: .bold)
                attributed[attrRange].backgroundColor = primaryAccent.opacity(0.2)
            }
            searchRange = range.upperBound..<text.endIndex
        }
        
        return attributed
    }
}
