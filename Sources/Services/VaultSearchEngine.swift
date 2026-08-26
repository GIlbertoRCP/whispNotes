import Foundation
import SwiftUI
import Combine

// MARK: - Search Match Models
public enum SearchMatchType: String {
    case title = "Title"
    case body = "Content"
    case transcript = "Audio Transcript"
    case tag = "Tag"
    
    public var iconName: String {
        switch self {
        case .title: return "character.cursor.ibeam"
        case .body: return "doc.text"
        case .transcript: return "waveform"
        case .tag: return "tag"
        }
    }
}

public struct SearchMatchItem: Identifiable {
    public let id = UUID()
    public let lineNumber: Int
    public let lineContent: String
    public let matchType: SearchMatchType
    public let highlightRange: NSRange
}

struct NoteSearchResult: Identifiable {
    var id: UUID { note.id }
    let note: NoteItem
    let matches: [SearchMatchItem]
    var totalMatches: Int { matches.count }
}

public enum SearchFilterType: String, CaseIterable, Identifiable {
    case all = "All"
    case notes = "Notes"
    case pdfs = "PDFs"
    case audio = "Audio"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .notes: return "doc.text"
        case .pdfs: return "doc.richtext"
        case .audio: return "waveform"
        }
    }
}

// MARK: - Vault Search Engine
public class VaultSearchEngine: ObservableObject {
    public static let shared = VaultSearchEngine()
    
    @Published public var query: String = ""
    @Published public var filterType: SearchFilterType = .all
    @Published public var selectedFolder: String? = nil
    @Published public var selectedTag: String? = nil
    @Published public var matchCase: Bool = false
    @Published public var wholeWord: Bool = false
    
    private init() {}
    
    // MARK: - Full-Text Deep Search
    func performSearch(in notes: [NoteItem]) -> [NoteSearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }
        
        var results: [NoteSearchResult] = []
        
        // Prepare regex pattern
        let escaped = NSRegularExpression.escapedPattern(for: cleanQuery)
        let pattern = wholeWord ? "\\b\(escaped)\\b" : escaped
        let options: NSRegularExpression.Options = matchCase ? [] : [.caseInsensitive]
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        
        for note in notes {
            if note.folder == "Trash" { continue }
            
            // Filter by type
            if filterType == .pdfs && note.pdfPath == nil { continue }
            if filterType == .audio && note.audioPath == nil { continue }
            if filterType == .notes && (note.pdfPath != nil || note.audioPath != nil) { continue }
            
            // Filter by selected folder
            if let folder = selectedFolder, note.folder != folder { continue }
            
            // Filter by selected tag
            if let tag = selectedTag, !note.content.lowercased().contains("#\(tag.lowercased())") { continue }
            
            var matches: [SearchMatchItem] = []
            
            // 1. Search Title
            let titleRange = NSRange(note.title.startIndex..., in: note.title)
            let titleMatches = regex.matches(in: note.title, range: titleRange)
            for m in titleMatches {
                matches.append(SearchMatchItem(lineNumber: 1, lineContent: note.title, matchType: .title, highlightRange: m.range))
            }
            
            // 2. Search Markdown Body line by line
            let lines = note.content.components(separatedBy: "\n")
            for (idx, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                
                let lineRange = NSRange(line.startIndex..., in: line)
                let lineMatches = regex.matches(in: line, range: lineRange)
                for m in lineMatches {
                    let isTagMatch = trimmed.hasPrefix("#") && !trimmed.hasPrefix("# ")
                    matches.append(SearchMatchItem(
                        lineNumber: idx + 1,
                        lineContent: line,
                        matchType: isTagMatch ? .tag : .body,
                        highlightRange: m.range
                    ))
                }
            }
            
            // 3. Search Audio Transcript Segments
            for seg in note.transcript {
                let segRange = NSRange(seg.text.startIndex..., in: seg.text)
                let segMatches = regex.matches(in: seg.text, range: segRange)
                for m in segMatches {
                    matches.append(SearchMatchItem(
                        lineNumber: Int(seg.startTime),
                        lineContent: "[\(seg.speaker)]: \(seg.text)",
                        matchType: .transcript,
                        highlightRange: m.range
                    ))
                }
            }
            
            if !matches.isEmpty {
                results.append(NoteSearchResult(note: note, matches: matches))
            }
        }
        
        return results
    }
    
    // MARK: - Tag Extraction
    static func extractAllTags(from notes: [NoteItem]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        let tagPattern = "(?<![\\w#])#([a-zA-Z0-9_\\-]+)"
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return [] }
        
        for note in notes where note.folder != "Trash" {
            let lines = note.content.components(separatedBy: "\n")
            var noteTags: Set<String> = []
            
            for line in lines {
                // Ignore Markdown headings (e.g. "# Heading", "## Heading")
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") ||
                   trimmed.hasPrefix("#### ") || trimmed.hasPrefix("##### ") || trimmed.hasPrefix("###### ") {
                    continue
                }
                
                let range = NSRange(line.startIndex..., in: line)
                let matches = regex.matches(in: line, range: range)
                for match in matches {
                    if let tagRange = Range(match.range(at: 1), in: line) {
                        let tag = String(line[tagRange]).lowercased()
                        noteTags.insert(tag)
                    }
                }
            }
            
            for tag in noteTags {
                counts[tag, default: 0] += 1
            }
        }
        
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }
}

// MARK: - Notifications
extension Notification.Name {
    public static let openVaultSearch = Notification.Name("openVaultSearch")
    public static let filterNotesByTag = Notification.Name("filterNotesByTag")
}
