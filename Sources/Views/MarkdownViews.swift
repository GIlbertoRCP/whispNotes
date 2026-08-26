import SwiftUI

// MARK: - Word & Character Count Helper & Document Stats
public struct DocumentStats: Equatable {
    public let words: Int
    public let characters: Int
    public let charactersNoSpaces: Int
    public let lines: Int
    public let paragraphs: Int
    public let readingTimeMinutes: Int
    
    public static let zero = DocumentStats(words: 0, characters: 0, charactersNoSpaces: 0, lines: 0, paragraphs: 0, readingTimeMinutes: 0)
}

public func calculateDocumentStats(_ rawText: String) -> DocumentStats {
    let text = rawText.replacingOccurrences(of: "\\n", with: "\n")
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .zero
    }
    
    let characters = text.count
    let charactersNoSpaces = text.filter { !$0.isWhitespace && !$0.isNewline }.count
    
    // Clean Markdown markup tokens to get accurate word count
    var cleaned = text
    cleaned = cleaned.replacingOccurrences(of: "```[\\s\\S]*?```", with: " ", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "`[^`]*`", with: " ", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]+\\)", with: "$1", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "\\[\\[([^\\]]+)\\]\\]", with: "$1", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^\\)]*\\)", with: " ", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "(?m)^#{1,6}\\s+", with: "", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "(?m)^>\\s+", with: "", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "(?m)^[\\s]*[-*+]\\s+", with: "", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: "(?m)^[\\s]*\\d+\\.\\s+", with: "", options: .regularExpression)

    var wordCount = 0
    cleaned.enumerateSubstrings(in: cleaned.startIndex..<cleaned.endIndex, options: [.byWords, .localized]) { (_, _, _, _) in
        wordCount += 1
    }
    
    if wordCount == 0 && !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        wordCount = cleaned.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    let lines = text.components(separatedBy: "\n").count
    let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    let readingTime = max(1, Int(ceil(Double(wordCount) / 200.0)))
    
    return DocumentStats(
        words: wordCount,
        characters: characters,
        charactersNoSpaces: charactersNoSpaces,
        lines: lines,
        paragraphs: max(1, paragraphs),
        readingTimeMinutes: readingTime
    )
}

public func calculateWordAndCharCount(_ text: String) -> (words: Int, chars: Int) {
    let stats = calculateDocumentStats(text)
    return (stats.words, stats.characters)
}

// MARK: - Code Block Card Component
struct CodeBlockView: View {
    let code: String
    let isDark: Bool
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text("CODE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.secondary.opacity(0.8))
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        Text(copied ? "Copied" : "Copy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(copied ? .emerald : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isDark ? Color(red: 226/255, green: 232/255, blue: 240/255) : Color(red: 15/255, green: 23/255, blue: 42/255))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.cardBackground(isDark))
        .cornerRadius(AppRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

// MARK: - Markdown Grid Table Renderer Component
struct MarkdownTableView: View {
    let lines: [String]
    let isDark: Bool
    
    var parsedRows: [[String]] {
        lines.compactMap { line in
            let parts = line.components(separatedBy: "|")
            if parts.count < 3 { return nil }
            return parts[1..<(parts.count - 1)].map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }
    
    var body: some View {
        let rows = parsedRows
        if let header = rows.first {
            let dataRows = rows.dropFirst().filter { row in
                !row.allSatisfy { $0.allSatisfy { $0 == "-" || $0 == ":" } }
            }
            
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    ForEach(Array(header.enumerated()), id: \.offset) { colIdx, cell in
                        Text(cell)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(Color.sidebarBackground(isDark))
                
                Divider()
                    .background(Color.subtleBorder(isDark))
                
                // Data Rows
                ForEach(Array(dataRows.enumerated()), id: \.offset) { rowIdx, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                            Text(cell)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .background(rowIdx % 2 == 0 ? Color.clear : Color.cardBackground(isDark))
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 1)
            )
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Tokenizer & Markdown Renderer View
struct TextToken: Identifiable {
    let id = UUID()
    enum TokenType {
        case text(String)
        case wikiLink(String)
        case hashtag(String)
        case playLink(timeLabel: String, seconds: Double)
        case inlineMath(String)
    }
    let type: TokenType
}

func parseLineTokens(_ line: String) -> [TextToken] {
    var tokens: [TextToken] = []
    var currentIndex = line.startIndex

    let pattern = "\\[\\[(.*?)\\]\\]|\\[(.*?)\\]\\(play://([0-9.]+)\\)|#([a-zA-Z0-9_]+)|\\$([^$\\n]+)\\$"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [.init(type: .text(line))]
    }

    let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
    let matches = regex.matches(in: line, range: nsRange)

    for match in matches {
        guard let matchRange = Range(match.range, in: line) else { continue }
        
        if currentIndex < matchRange.lowerBound {
            let prefixText = String(line[currentIndex..<matchRange.lowerBound])
            if !prefixText.isEmpty {
                tokens.append(.init(type: .text(prefixText)))
            }
        }

        if let wikiRange = Range(match.range(at: 1), in: line), !line[wikiRange].isEmpty {
            let wikiTitle = String(line[wikiRange])
            tokens.append(.init(type: .wikiLink(wikiTitle)))
        } else if let labelRange = Range(match.range(at: 2), in: line),
                  let secRange = Range(match.range(at: 3), in: line),
                  let seconds = Double(line[secRange]) {
            let label = String(line[labelRange])
            tokens.append(.init(type: .playLink(timeLabel: label, seconds: seconds)))
        } else if let tagRange = Range(match.range(at: 4), in: line), !line[tagRange].isEmpty {
            let tag = String(line[tagRange])
            tokens.append(.init(type: .hashtag(tag)))
        } else if let mathRange = Range(match.range(at: 5), in: line), !line[mathRange].isEmpty {
            let latexFormula = String(line[mathRange])
            tokens.append(.init(type: .inlineMath(latexFormula)))
        }

        currentIndex = matchRange.upperBound
    }

    if currentIndex < line.endIndex {
        let suffixText = String(line[currentIndex..<line.endIndex])
        if !suffixText.isEmpty {
            tokens.append(.init(type: .text(suffixText)))
        }
    }

    return tokens
}

struct FormattedTextLine: View {
    let text: String
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let currentFolder: String
    let primaryAccent: Color
    let secondaryAccent: Color
    var isDark: Bool = true

    var tokens: [TextToken] {
        parseLineTokens(text)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(tokens) { token in
                switch token.type {
                case .text(let plainStr):
                    Text(plainStr)
                case .inlineMath(let formula):
                    InlineMathView(latex: formula, isDark: isDark)
                case .hashtag(let tag):
                    Button(action: {
                        NotificationCenter.default.post(name: .filterNotesByTag, object: tag)
                    }) {
                        Text("#\(tag)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(primaryAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(primaryAccent.opacity(0.14))
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(primaryAccent.opacity(0.35), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Filter notes by #\(tag)")
                case .wikiLink(let targetTitle):
                    Button(action: {
                        openOrCreateWikiLinkNote(targetTitle)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 9))
                            Text(targetTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(secondaryAccent.opacity(0.2))
                        .foregroundColor(secondaryAccent)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(secondaryAccent.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                case .playLink(let label, let seconds):
                    Button(action: {
                        playerVM.seek(to: seconds)
                        if !playerVM.isPlaying {
                            playerVM.togglePlayPause()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            Text(label)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryAccent.opacity(0.2))
                        .foregroundColor(primaryAccent)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openOrCreateWikiLinkNote(_ targetTitle: String) {
        let cleanTarget = targetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = notes.first(where: { $0.title.caseInsensitiveCompare(cleanTarget) == .orderedSame }) {
            selectedNoteId = existing.id
        } else {
            let newNote = NoteItem(
                title: cleanTarget,
                folder: currentFolder,
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
}

enum MarkdownBlockType {
    case line(String)
    case table([String])
    case code(String)
    case callout(type: String, title: String, content: [String])
    case image(alt: String, path: String)
    case mermaid(String)
    case mathBlock(String)
}

// MARK: - Inline Markdown Image Viewer Component
struct MarkdownImageView: View {
    let alt: String
    let pathOrURL: String
    let isDark: Bool
    let primaryAccent: Color
    
    @State private var loadedImage: NSImage? = nil
    @State private var resolvedURL: URL? = nil
    @State private var isHovered = false
    @State private var copied = false
    @State private var loadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let image = loadedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 680, maxHeight: 480, alignment: .leading)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                } else if loadFailed {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Image not found")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text(pathOrURL)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.cardBackground(isDark))
                    .cornerRadius(8)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                        Text("Loading image...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.cardBackground(isDark))
                    .cornerRadius(8)
                }

                // Hover Actions: Open in Preview ↗, Copy Image 📋, Reveal in Finder 📁
                if isHovered && loadedImage != nil {
                    HStack(spacing: 4) {
                        if let url = resolvedURL {
                            Button(action: { NSWorkspace.shared.open(url) }) {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.black.opacity(0.65))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .help("Open in Preview.app")

                            Button(action: { NSWorkspace.shared.activateFileViewerSelecting([url]) }) {
                                Image(systemName: "folder")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.black.opacity(0.65))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                        }

                        Button(action: {
                            if let img = loadedImage {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.writeObjects([img])
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    copied = false
                                }
                            }
                        }) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(copied ? .emerald : .white)
                                .padding(5)
                                .background(Color.black.opacity(0.65))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Copy Image to Clipboard")
                    }
                    .padding(8)
                    .transition(.opacity)
                }
            }
            .onHover { inside in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = inside
                }
            }

            // Optional Alt Text Caption
            if !alt.isEmpty && alt != "Pasted image" && !alt.hasPrefix("Pasted image 20") {
                Text(alt)
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        let cleanPath = pathOrURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Web Image (http:// or https://)
        if cleanPath.hasPrefix("http://") || cleanPath.hasPrefix("https://") {
            if let webURL = URL(string: cleanPath) {
                resolvedURL = webURL
                DispatchQueue.global(qos: .userInitiated).async {
                    if let data = try? Data(contentsOf: webURL), let img = NSImage(data: data) {
                        DispatchQueue.main.async {
                            self.loadedImage = img
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.loadFailed = true
                        }
                    }
                }
                return
            }
        }

        // 2. Attachment / Vault relative path (attachment:filename.png or filename.png)
        let stripped = cleanPath.replacingOccurrences(of: "attachment:", with: "")
        if let targetURL = NotesDataManager.shared.resolveAttachmentURL(stripped) {
            resolvedURL = targetURL
            if let img = NSImage(contentsOf: targetURL) {
                self.loadedImage = img
                return
            }
        }

        // 3. Absolute local file path (file:///...)
        let fileURL = cleanPath.hasPrefix("file://") ? URL(string: cleanPath) : URL(fileURLWithPath: cleanPath)
        if let fURL = fileURL, FileManager.default.fileExists(atPath: fURL.path) {
            resolvedURL = fURL
            if let img = NSImage(contentsOf: fURL) {
                self.loadedImage = img
                return
            }
        }

        self.loadFailed = true
    }
}

// MARK: - Obsidian Callout Box Component
struct CalloutBlockView: View {
    let type: String
    let title: String
    let content: [String]
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let currentFolder: String
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color

    var calloutColor: Color {
        switch type {
        case "NOTE", "INFO": return primaryAccent
        case "TIP", "HINT": return Color(red: 16/255, green: 185/255, blue: 129/255)
        case "WARNING", "CAUTION": return Color(red: 245/255, green: 158/255, blue: 11/255)
        case "IMPORTANT", "DANGER", "BUG": return Color(red: 244/255, green: 63/255, blue: 94/255)
        case "QUESTION", "FAQ", "HELP": return Color(red: 139/255, green: 92/255, blue: 246/255)
        case "SUCCESS", "CHECK", "DONE": return Color(red: 34/255, green: 197/255, blue: 94/255)
        default: return primaryAccent
        }
    }

    var calloutIcon: String {
        switch type {
        case "NOTE", "INFO": return "info.circle.fill"
        case "TIP", "HINT": return "lightbulb.fill"
        case "WARNING", "CAUTION": return "exclamationmark.triangle.fill"
        case "IMPORTANT", "DANGER", "BUG": return "flame.fill"
        case "QUESTION", "FAQ", "HELP": return "questionmark.circle.fill"
        case "SUCCESS", "CHECK", "DONE": return "checkmark.seal.fill"
        default: return "quote.bubble.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: calloutIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(calloutColor)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(calloutColor)
                Spacer()
            }

            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(content.enumerated()), id: \.offset) { _, line in
                        FormattedTextLine(
                            text: line,
                            notes: $notes,
                            selectedNoteId: $selectedNoteId,
                            playerVM: playerVM,
                            currentFolder: currentFolder,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent
                        )
                        .font(.caption)
                    }
                }
                .padding(.leading, 2)
            }
        }
        .padding(10)
        .background(calloutColor.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(calloutColor.opacity(0.35), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

func parseMarkdownBlocks(_ text: String) -> [MarkdownBlockType] {
    let lines = text.components(separatedBy: "\n")
    var blocks: [MarkdownBlockType] = []
    
    var index = 0
    while index < lines.count {
        let line = lines[index]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Standard Markdown Image check (![alt](path))
        if trimmed.hasPrefix("![") && trimmed.contains("](") && trimmed.hasSuffix(")") {
            let imgPattern = "^!\\[(.*?)\\]\\((.*?)\\)$"
            if let regex = try? NSRegularExpression(pattern: imgPattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let altRange = Range(match.range(at: 1), in: trimmed),
               let pathRange = Range(match.range(at: 2), in: trimmed) {
                let alt = String(trimmed[altRange])
                let path = String(trimmed[pathRange])
                blocks.append(.image(alt: alt, path: path))
                index += 1
                continue
            }
        }

        // Obsidian Transclusion Image check (![[image.png]] or ![[image.png|300]])
        if trimmed.hasPrefix("![[") && trimmed.hasSuffix("]]") {
            let obsPattern = "^!\\[\\[(.*?)(?:\\|.*)?\\]\\]$"
            if let regex = try? NSRegularExpression(pattern: obsPattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let pathRange = Range(match.range(at: 1), in: trimmed) {
                let path = String(trimmed[pathRange])
                blocks.append(.image(alt: "", path: path))
                index += 1
                continue
            }
        }
        
        // Obsidian Callout check (> [!TYPE] Title)
        if line.hasPrefix("> [!") {
            let pattern = "^>\\s*\\[!(.*?)\\]\\s*(.*)$"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let typeRange = Range(match.range(at: 1), in: line) {
                let calloutType = String(line[typeRange]).uppercased()
                var calloutTitle = ""
                if let titleRange = Range(match.range(at: 2), in: line) {
                    calloutTitle = String(line[titleRange]).trimmingCharacters(in: .whitespaces)
                }
                if calloutTitle.isEmpty {
                    calloutTitle = calloutType.capitalized
                }
                
                var bodyLines: [String] = []
                index += 1
                while index < lines.count && lines[index].hasPrefix(">") && !lines[index].hasPrefix("> [!") {
                    let raw = lines[index]
                    let clean = raw.hasPrefix("> ") ? String(raw.dropFirst(2)) : String(raw.dropFirst())
                    bodyLines.append(clean)
                    index += 1
                }
                blocks.append(.callout(type: calloutType, title: calloutTitle, content: bodyLines))
                continue
            }
        }
        
        // Block Math check ($$ ... $$)
        if trimmed.hasPrefix("$$") {
            if trimmed.hasSuffix("$$") && trimmed.count > 4 {
                let mathContent = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.mathBlock(mathContent))
                index += 1
                continue
            }
            var mathLines: [String] = []
            let firstLineMath = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if !firstLineMath.isEmpty { mathLines.append(firstLineMath) }
            index += 1
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasSuffix("$$") {
                mathLines.append(lines[index])
                index += 1
            }
            if index < lines.count {
                let lastTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                let lastLineMath = String(lastTrimmed.dropLast(2)).trimmingCharacters(in: .whitespaces)
                if !lastLineMath.isEmpty { mathLines.append(lastLineMath) }
                index += 1
            }
            blocks.append(.mathBlock(mathLines.joined(separator: "\n")))
            continue
        }

        // Mermaid Block check (```mermaid ... ```)
        if trimmed.hasPrefix("```mermaid") {
            var mermaidLines: [String] = []
            index += 1
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                mermaidLines.append(lines[index])
                index += 1
            }
            blocks.append(.mermaid(mermaidLines.joined(separator: "\n")))
            index += 1
            continue
        }

        // Math/LaTeX Code block check (```math or ```latex)
        if trimmed.hasPrefix("```math") || trimmed.hasPrefix("```latex") {
            var mathLines: [String] = []
            index += 1
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                mathLines.append(lines[index])
                index += 1
            }
            blocks.append(.mathBlock(mathLines.joined(separator: "\n")))
            index += 1
            continue
        }

        // Code block check
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            var codeLines: [String] = []
            index += 1
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[index])
                index += 1
            }
            blocks.append(.code(codeLines.joined(separator: "\n")))
            index += 1
            continue
        }
        
        // Table check
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            var tableLines: [String] = []
            while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                tableLines.append(lines[index])
                index += 1
            }
            blocks.append(.table(tableLines))
            continue
        }
        
        blocks.append(.line(line))
        index += 1
    }
    
    return blocks
}

struct MarkdownRendererView: View {
    let markdown: String
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color

    var currentNoteFolder: String {
        if let id = selectedNoteId, let note = notes.first(where: { $0.id == id }) {
            return note.folder
        }
        return "General"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parseMarkdownBlocks(markdown).enumerated()), id: \.offset) { _, block in
                switch block {
                case .line(let line):
                    renderLine(line)
                case .table(let tableLines):
                    MarkdownTableView(lines: tableLines, isDark: isDark)
                case .code(let codeStr):
                    CodeBlockView(code: codeStr, isDark: isDark)
                case .image(let alt, let path):
                    MarkdownImageView(
                        alt: alt,
                        pathOrURL: path,
                        isDark: isDark,
                        primaryAccent: primaryAccent
                    )
                case .callout(let type, let title, let contentLines):
                    CalloutBlockView(
                        type: type,
                        title: title,
                        content: contentLines,
                        notes: $notes,
                        selectedNoteId: $selectedNoteId,
                        playerVM: playerVM,
                        currentFolder: currentNoteFolder,
                        isDark: isDark,
                        primaryAccent: primaryAccent,
                        secondaryAccent: secondaryAccent
                    )
                case .mermaid(let mermaidCode):
                    MermaidRendererView(
                        code: mermaidCode,
                        isDark: isDark,
                        primaryAccent: primaryAccent
                    )
                case .mathBlock(let latex):
                    MathEquationBlockView(
                        latex: latex,
                        isDark: isDark,
                        primaryAccent: primaryAccent
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        if line.hasPrefix("# ") {
            Text(line.replacingOccurrences(of: "# ", with: ""))
                .font(.title)
                .fontWeight(.bold)
        } else if line.hasPrefix("## ") {
            Text(line.replacingOccurrences(of: "## ", with: ""))
                .font(.title2)
                .fontWeight(.semibold)
        } else if line.hasPrefix("### ") {
            Text(line.replacingOccurrences(of: "### ", with: ""))
                .font(.headline)
                .fontWeight(.medium)
        } else if line.hasPrefix("> ") {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(primaryAccent)
                    .frame(width: 3)
                FormattedTextLine(
                    text: line.replacingOccurrences(of: "> ", with: ""),
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.cardBackground(true))
            .cornerRadius(6)
        } else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") {
            let isChecked = line.hasPrefix("- [x] ")
            let clean = line.replacingOccurrences(of: "- [ ] ", with: "").replacingOccurrences(of: "- [x] ", with: "")
            HStack(alignment: .top, spacing: 8) {
                Button(action: { toggleCheckbox(targetLine: line) }) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundColor(isChecked ? primaryAccent : .secondary)
                }
                .buttonStyle(.plain)
                
                FormattedTextLine(
                    text: clean,
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
                .strikethrough(isChecked, color: .secondary)
            }
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                FormattedTextLine(
                    text: line.replacingOccurrences(of: "- ", with: ""),
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
            }
        } else {
            FormattedTextLine(
                text: line,
                notes: $notes,
                selectedNoteId: $selectedNoteId,
                playerVM: playerVM,
                currentFolder: currentNoteFolder,
                primaryAccent: primaryAccent,
                secondaryAccent: secondaryAccent
            )
        }
    }

    private func toggleCheckbox(targetLine: String) {
        guard let id = selectedNoteId, let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let currentContent = notes[idx].content
        let replacement = targetLine.hasPrefix("- [x] ") ? targetLine.replacingOccurrences(of: "- [x] ", with: "- [ ] ") : targetLine.replacingOccurrences(of: "- [ ] ", with: "- [x] ")
        if let range = currentContent.range(of: targetLine) {
            notes[idx].content.replaceSubrange(range, with: replacement)
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}
