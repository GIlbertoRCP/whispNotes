import Foundation
import AppKit

// MARK: - Smart Paste & Markdown Formatting Engine
public final class SmartPasteEngine {
    public static let shared = SmartPasteEngine()
    
    private init() {}
    
    public struct PasteResult {
        public let text: String
        public let wasFormatted: Bool
        public let formatType: String // e.g. "HTML to Markdown", "Smart Text Cleanup", "Plain Text"
    }
    
    /// Inspects the pasteboard and returns appropriately formatted Markdown text.
    public func processPasteboard(_ pasteboard: NSPasteboard = .general) -> PasteResult? {
        // 1. Check for HTML rich text
        if let htmlData = pasteboard.data(forType: .html) ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.html")),
           let htmlString = String(data: htmlData, encoding: .utf8) ?? String(data: htmlData, encoding: .isoLatin1) {
            let converted = convertHTMLToMarkdown(htmlString)
            let trimmed = converted.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return PasteResult(text: trimmed, wasFormatted: true, formatType: "HTML to Markdown")
            }
        }
        
        // 2. Check for plain text
        if let plainText = pasteboard.string(forType: .string) {
            let cleaned = cleanClutteredPlainText(plainText)
            if cleaned != plainText {
                return PasteResult(text: cleaned, wasFormatted: true, formatType: "Smart Text Cleanup")
            } else {
                return PasteResult(text: plainText, wasFormatted: false, formatType: "Plain Text")
            }
        }
        
        return nil
    }
    
    // MARK: - HTML to Markdown Converter
    
    /// Converts an HTML string (from clipboard) into clean GitHub-Flavored Markdown.
    public func convertHTMLToMarkdown(_ rawHTML: String) -> String {
        var html = rawHTML
        
        // 1. Pre-process KaTeX / MathJax equations
        // Extract LaTeX math from <annotation encoding="application/x-tex">formula</annotation>
        let annotationPattern = "(?s)<annotation[^>]*encoding=[\"']application/x-tex[\"'][^>]*>(.*?)</annotation>"
        if let regex = try? NSRegularExpression(pattern: annotationPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: html),
                      let formulaRange = Range(match.range(at: 1), in: html) else { continue }
                let formula = decodeHTMLEntities(String(html[formulaRange])).trimmingCharacters(in: .whitespacesAndNewlines)
                html.replaceSubrange(fullRange, with: " $\(formula)$ ")
            }
        }
        
        // Strip out entire KaTeX mathml / html containers that now have extracted formulas or leftovers
        html = html.replacingOccurrences(of: "(?s)<span class=\"katex-mathml\">.*?</span>", with: "", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?s)<span class=\"katex-html\"[^>]*>.*?</span>", with: "", options: .regularExpression)
        
        // Strip document wrapper (<head>, <style>, <script>, <meta>)
        html = html.replacingOccurrences(of: "(?s)<head[^>]*>.*?</head>", with: "", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?s)<style[^>]*>.*?</style>", with: "", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?s)<script[^>]*>.*?</script>", with: "", options: .regularExpression)
        
        // 2. Parse HTML Tables into Markdown Tables
        html = convertTablesToMarkdown(html)
        
        // 3. Preformatted Code Blocks (<pre><code>...</code></pre> or <pre>...</pre>)
        let preCodePattern = "(?s)<pre[^>]*><code[^>]*class=[\"']?(?:language-)?([a-zA-Z0-9_-]+)?[\"']?[^>]*>(.*?)</code></pre>"
        if let regex = try? NSRegularExpression(pattern: preCodePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: html),
                      let codeRange = Range(match.range(at: 2), in: html) else { continue }
                var lang = ""
                if match.range(at: 1).location != NSNotFound, let langRange = Range(match.range(at: 1), in: html) {
                    lang = String(html[langRange])
                }
                let code = decodeHTMLEntities(String(html[codeRange]))
                let markdownCode = "\n\n```\(lang)\n\(code)\n```\n\n"
                html.replaceSubrange(fullRange, with: markdownCode)
            }
        }
        
        let genericPrePattern = "(?s)<pre[^>]*>(.*?)</pre>"
        if let regex = try? NSRegularExpression(pattern: genericPrePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: html),
                      let codeRange = Range(match.range(at: 1), in: html) else { continue }
                let code = decodeHTMLEntities(String(html[codeRange]))
                let markdownCode = "\n\n```\n\(code)\n```\n\n"
                html.replaceSubrange(fullRange, with: markdownCode)
            }
        }
        
        // 4. Inline Code (<code>...</code>)
        html = html.replacingOccurrences(of: "<code[^>]*>(.*?)</code>", with: "`$1`", options: .regularExpression)
        
        // 5. Headings (<h1> through <h6>)
        html = html.replacingOccurrences(of: "(?s)<h1[^>]*>(.*?)</h1>", with: "\n\n# $1\n\n", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?s)<h2[^>]*>(.*?)</h2>", with: "\n\n## $1\n\n", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?s)<h3[^>]*>(.*?)</h3>", with: "\n\n### $1\n\n", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?s)<h4[^>]*>(.*?)</h4>", with: "\n\n#### $1\n\n", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?s)<h5[^>]*>(.*?)</h5>", with: "\n\n##### $1\n\n", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?s)<h6[^>]*>(.*?)</h6>", with: "\n\n###### $1\n\n", options: .regularExpression)
        
        // 6. Blockquotes (<blockquote>...</blockquote>)
        let bqPattern = "(?s)<blockquote[^>]*>(.*?)</blockquote>"
        if let regex = try? NSRegularExpression(pattern: bqPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: html),
                      let contentRange = Range(match.range(at: 1), in: html) else { continue }
                let content = String(html[contentRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: "\n")
                    .map { "> \($0)" }
                    .joined(separator: "\n")
                html.replaceSubrange(fullRange, with: "\n\n\(content)\n\n")
            }
        }
        
        // 7. Unordered & Ordered Lists
        html = convertListsToMarkdown(html)
        
        // 8. Horizontal Rules
        html = html.replacingOccurrences(of: "<hr[^>]*>", with: "\n\n---\n\n", options: .regularExpression)
        
        // 9. Links (<a href="...">...</a>)
        html = html.replacingOccurrences(of: "<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>", with: "[$2]($1)", options: .regularExpression)
        
        // 10. Images (<img src="..." alt="...">)
        html = html.replacingOccurrences(of: "<img[^>]*src=[\"']([^\"']+)[\"'][^>]*alt=[\"']([^\"']*)[\"'][^>]*>", with: "![$2]($1)", options: .regularExpression)
        html = html.replacingOccurrences(of: "<img[^>]*alt=[\"']([^\"']*)[\"'][^>]*src=[\"']([^\"']+)[\"'][^>]*>", with: "![$1]($2)", options: .regularExpression)
        html = html.replacingOccurrences(of: "<img[^>]*src=[\"']([^\"']+)[\"'][^>]*>", with: "![]($1)", options: .regularExpression)
        
        // 11. Text formatting: bold, italic, strike
        html = html.replacingOccurrences(of: "<(strong|b)[^>]*>(.*?)</\\1>", with: "**$2**", options: .regularExpression)
        html = html.replacingOccurrences(of: "<(em|i)[^>]*>(.*?)</\\1>", with: "*$2*", options: .regularExpression)
        html = html.replacingOccurrences(of: "<(del|s|strike)[^>]*>(.*?)</\\1>", with: "~~$2~~", options: .regularExpression)
        
        // 12. Paragraphs & Line Breaks
        html = html.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        html = html.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        html = html.replacingOccurrences(of: "<p[^>]*>", with: "", options: .regularExpression)
        html = html.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
        html = html.replacingOccurrences(of: "<div[^>]*>", with: "", options: .regularExpression)
        
        // 13. Strip any remaining HTML tags
        html = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 14. Decode HTML Entities
        html = decodeHTMLEntities(html)
        
        // 15. Clean up excessive newlines
        html = html.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - HTML Tables to Markdown
    private func convertTablesToMarkdown(_ html: String) -> String {
        var result = html
        let tablePattern = "(?s)<table[^>]*>(.*?)</table>"
        guard let tableRegex = try? NSRegularExpression(pattern: tablePattern, options: .caseInsensitive) else {
            return result
        }
        
        let matches = tableRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let tableRange = Range(match.range, in: result),
                  let contentRange = Range(match.range(at: 1), in: result) else { continue }
            let tableContent = String(result[contentRange])
            
            // Extract rows
            var parsedRows: [[String]] = []
            let rowPattern = "(?s)<tr[^>]*>(.*?)</tr>"
            if let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: .caseInsensitive) {
                let rowMatches = rowRegex.matches(in: tableContent, range: NSRange(tableContent.startIndex..., in: tableContent))
                for rowMatch in rowMatches {
                    guard let cellsContentRange = Range(rowMatch.range(at: 1), in: tableContent) else { continue }
                    let cellsContent = String(tableContent[cellsContentRange])
                    
                    var cells: [String] = []
                    let cellPattern = "(?s)<(td|th)[^>]*>(.*?)</\\1>"
                    if let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: .caseInsensitive) {
                        let cellMatches = cellRegex.matches(in: cellsContent, range: NSRange(cellsContent.startIndex..., in: cellsContent))
                        for cellMatch in cellMatches {
                            guard let cellTextRange = Range(cellMatch.range(at: 2), in: cellsContent) else { continue }
                            var cellText = String(cellsContent[cellTextRange])
                            // Clean tags inside cell
                            cellText = cellText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            cellText = decodeHTMLEntities(cellText).trimmingCharacters(in: .whitespacesAndNewlines)
                            // Escape pipe characters inside cells
                            cellText = cellText.replacingOccurrences(of: "|", with: "\\|")
                            // Replace newlines inside cells with space
                            cellText = cellText.replacingOccurrences(of: "\n", with: " ")
                            cells.append(cellText.isEmpty ? " " : cellText)
                        }
                    }
                    if !cells.isEmpty {
                        parsedRows.append(cells)
                    }
                }
            }
            
            guard !parsedRows.isEmpty else { continue }
            
            // Build Markdown Table
            let maxCols = parsedRows.map { $0.count }.max() ?? 0
            guard maxCols > 0 else { continue }
            
            var mdTableLines: [String] = []
            
            // Header Row
            let header = parsedRows[0]
            var paddedHeader = header
            while paddedHeader.count < maxCols { paddedHeader.append(" ") }
            mdTableLines.append("| " + paddedHeader.joined(separator: " | ") + " |")
            
            // Divider Row
            let divider = Array(repeating: "---", count: maxCols)
            mdTableLines.append("| " + divider.joined(separator: " | ") + " |")
            
            // Body Rows
            for row in parsedRows.dropFirst() {
                var paddedRow = row
                while paddedRow.count < maxCols { paddedRow.append(" ") }
                mdTableLines.append("| " + paddedRow.joined(separator: " | ") + " |")
            }
            
            let markdownTable = "\n\n" + mdTableLines.joined(separator: "\n") + "\n\n"
            result.replaceSubrange(tableRange, with: markdownTable)
        }
        
        return result
    }
    
    // MARK: - HTML Lists to Markdown
    private func convertListsToMarkdown(_ html: String) -> String {
        var result = html
        
        // Unordered lists
        let ulPattern = "(?s)<ul[^>]*>(.*?)</ul>"
        if let ulRegex = try? NSRegularExpression(pattern: ulPattern, options: .caseInsensitive) {
            let matches = ulRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let contentRange = Range(match.range(at: 1), in: result) else { continue }
                let listContent = String(result[contentRange])
                let items = extractListItems(listContent, isOrdered: false)
                result.replaceSubrange(fullRange, with: "\n\n\(items)\n\n")
            }
        }
        
        // Ordered lists
        let olPattern = "(?s)<ol[^>]*>(.*?)</ol>"
        if let olRegex = try? NSRegularExpression(pattern: olPattern, options: .caseInsensitive) {
            let matches = olRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let contentRange = Range(match.range(at: 1), in: result) else { continue }
                let listContent = String(result[contentRange])
                let items = extractListItems(listContent, isOrdered: true)
                result.replaceSubrange(fullRange, with: "\n\n\(items)\n\n")
            }
        }
        
        return result
    }
    
    private func extractListItems(_ content: String, isOrdered: Bool) -> String {
        let liPattern = "(?s)<li[^>]*>(.*?)</li>"
        guard let regex = try? NSRegularExpression(pattern: liPattern, options: .caseInsensitive) else {
            return content
        }
        
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        var items: [String] = []
        var index = 1
        
        for match in matches {
            guard let itemRange = Range(match.range(at: 1), in: content) else { continue }
            var itemText = String(content[itemRange])
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            itemText = decodeHTMLEntities(itemText).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isOrdered {
                items.append("\(index). \(itemText)")
                index += 1
            } else {
                items.append("- \(itemText)")
            }
        }
        
        return items.joined(separator: "\n")
    }
    
    // MARK: - Smart Plain Text Cleanup
    
    /// Cleans up cluttered plain-text pastes (e.g. run-on definitions, double-space separated points, glued headers, or unformatted tables).
    public func cleanClutteredPlainText(_ rawText: String) -> String {
        var text = rawText
        
        // Check if the text matches cluttered patterns
        let hasDoubleSpaceSeparators = text.contains("  ")
        let hasDefinitionPattern = text.range(of: "\\b[A-Za-z0-9_.-]+(?:\\s*\\([^)]+\\))?\\s*:\\s+", options: .regularExpression) != nil
        let hasGluedHeaders = text.range(of: "[a-z][A-Z]", options: .regularExpression) != nil
        
        guard hasDoubleSpaceSeparators || hasDefinitionPattern || hasGluedHeaders else {
            return rawText
        }
        
        // 1. Separate common glued headings (e.g. "Suggested Learning Plan & ResourcesWhen theoretical..." -> Heading + Newline)
        text = separateGluedHeadings(text)
        
        // 2. Detect definition items separated by double spaces:
        // "difficulty:  Recursive (Decidable): There is an algorithm...  Recursively Enumerable (...): ..."
        text = structureDefinitionLists(text)
        
        // 3. Detect and structure flat tables if present in text
        text = structureFlatTables(text)
        
        // 4. Normalize multiple blank lines
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func separateGluedHeadings(_ input: String) -> String {
        var text = input
        
        // Pattern: Title/Heading glued directly to sentence starter: e.g. "ResourcesWhen", "TheoremsIf", "DifficultyThe", "PlanConsider"
        let sentenceStarters = ["When", "If", "Considered", "Consider", "While", "Because", "Although", "In", "For", "Given", "Assume", "Note", "Recall"]
        for starter in sentenceStarters {
            let pattern = "([a-z0-9&])(\(starter)\\b)"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1\n\n$2")
            }
        }
        
        // If a known section header is found at start of a line or after double space, promote to Markdown header
        let commonHeaders = [
            "Suggested Learning Plan & Resources",
            "Suggested Learning Plan",
            "Key Takeaways",
            "Summary",
            "Recommended Resources",
            "Prerequisites",
            "Definition",
            "Overview"
        ]
        
        for header in commonHeaders {
            if text.contains(header) {
                // Ensure it has newlines before and after
                text = text.replacingOccurrences(of: "  \(header)", with: "\n\n### \(header)\n\n")
                if text.hasPrefix(header) {
                    text = "### \(header)\n\n" + text.dropFirst(header.count).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return text
    }
    
    private func structureDefinitionLists(_ input: String) -> String {
        var text = input
        
        // When we have text like:
        // "grouping problems into three tiers of difficulty:  Recursive (Decidable): There is an algorithm..."
        // Split on double spaces preceding a definition: "  (Term: ...)"
        
        // Pattern: Double space followed by a capitalized term with optional parenthesis and a colon:
        // e.g. "  Recursive (Decidable): " or "  Non-r.e. (Completely Uncomputable): " or "  Fundamental Theorem: "
        let itemPattern = "(?:\\s{2,})([A-Z][a-zA-Z0-9_. -]+(?:\\s*\\([^)]+\\))?)\\s*:\\s*"
        if let regex = try? NSRegularExpression(pattern: itemPattern) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n\n- **$1:** ")
        }
        
        // Also if intro sentence ended with colon, ensure it has a newline before the first bullet
        text = text.replacingOccurrences(of: ":\n\n- ", with: ":\n\n- ")
        
        // Separate standalone Theorems: e.g. "- **Fundamental Theorem:**" into a standalone highlighted paragraph
        text = text.replacingOccurrences(of: "- **Fundamental Theorem:** ", with: "\n\n**Fundamental Theorem:** ")
        text = text.replacingOccurrences(of: "- **Theorem:** ", with: "\n\n**Theorem:** ")
        
        return text
    }
    
    private func structureFlatTables(_ input: String) -> String {
        var text = input
        
        // Check for common flattened table patterns where headers and rows are concatenated:
        // "ResourceWhy It HelpsMichael Sipser — Introduction...Considered the clearest...Easy Theory...Walkthrough...JFLAP...An interactive..."
        let tableHeaderPair = "ResourceWhy It Helps"
        if let headerRange = text.range(of: tableHeaderPair) {
            let before = String(text[..<headerRange.lowerBound])
            var after = String(text[headerRange.upperBound...])
            
            // Separate sentence period glued directly to next resource name: "diagonalization.Easy Theory" -> "diagonalization.\nEasy Theory"
            let gluedPeriodPattern = "([a-z0-9\\)])\\.([A-Z])"
            if let periodRegex = try? NSRegularExpression(pattern: gluedPeriodPattern) {
                after = periodRegex.stringByReplacingMatches(in: after, range: NSRange(after.startIndex..., in: after), withTemplate: "$1.\n$2")
            }
            
            // Identify rows using common delimiters like "Michael Sipser", "Easy Theory", "JFLAP", etc.
            let rowSplitPattern = "([A-Za-z0-9 /_.—-]+?\\s*(?:\\([^)]+\\))?)\\s*(Considered|Walkthrough|An interactive|A comprehensive|Provides|Includes|Official|Used for)"
            if let regex = try? NSRegularExpression(pattern: rowSplitPattern) {
                let matches = regex.matches(in: after, range: NSRange(after.startIndex..., in: after))
                if !matches.isEmpty {
                    var rows: [(col1: String, col2: String)] = []
                    var lastIndex = after.startIndex
                    
                    for match in matches {
                        guard Range(match.range, in: after) != nil,
                              let col1Range = Range(match.range(at: 1), in: after),
                              let leadWordRange = Range(match.range(at: 2), in: after) else { continue }
                        
                        let col1 = String(after[col1Range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let leadWord = String(after[leadWordRange])
                        
                        if let lastRow = rows.last {
                            // Update previous row's col2 with content up to this row's start
                            let prevEnd = col1Range.lowerBound
                            if lastIndex < prevEnd {
                                let prevCol2 = String(after[lastIndex..<prevEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                                rows[rows.count - 1] = (lastRow.col1, prevCol2)
                            }
                        }
                        
                        rows.append((col1, leadWord))
                        lastIndex = leadWordRange.lowerBound
                    }
                    
                    // Final row col2
                    if let lastRow = rows.last, lastIndex < after.endIndex {
                        let finalCol2 = String(after[lastIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        rows[rows.count - 1] = (lastRow.col1, finalCol2)
                    }
                    
                    if !rows.isEmpty {
                        var mdTable = "\n\n| Resource | Why It Helps |\n| --- | --- |\n"
                        for row in rows {
                            let cleanCol1 = row.col1.replacingOccurrences(of: "\n", with: " ")
                            let cleanCol2 = row.col2.replacingOccurrences(of: "\n", with: " ")
                            mdTable += "| \(cleanCol1) | \(cleanCol2) |\n"
                        }
                        text = before.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + mdTable
                    }
                }
            }
        }
        
        // Also check if text has tab-separated values (TSV pasted from Excel / Sheets)
        if text.contains("\t") && text.contains("\n") {
            let lines = text.components(separatedBy: "\n")
            let tabLines = lines.filter { $0.contains("\t") }
            if tabLines.count >= 2 {
                var mdLines: [String] = []
                for (i, line) in lines.enumerated() {
                    let cols = line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
                    mdLines.append("| " + cols.joined(separator: " | ") + " |")
                    if i == 0 {
                        mdLines.append("| " + Array(repeating: "---", count: cols.count).joined(separator: " | ") + " |")
                    }
                }
                text = mdLines.joined(separator: "\n")
            }
        }
        
        return text
    }
    
    // MARK: - HTML Entity Decoder
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&le;": "\\le",
            "&ge;": "\\ge",
            "&ne;": "\\ne",
            "&times;": "×",
            "&divide;": "÷",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&rsquo;": "’",
            "&lsquo;": "‘",
            "&rdquo;": "”",
            "&ldquo;": "“"
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        
        // Numeric hex / decimal entities: &#123; or &#x7b;
        let numPattern = "&#(x[0-9a-fA-F]+|[0-9]+);"
        if let regex = try? NSRegularExpression(pattern: numPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let numRange = Range(match.range(at: 1), in: result) else { continue }
                let codeStr = String(result[numRange])
                let code: UInt32?
                if codeStr.hasPrefix("x") || codeStr.hasPrefix("X") {
                    code = UInt32(codeStr.dropFirst(), radix: 16)
                } else {
                    code = UInt32(codeStr, radix: 10)
                }
                if let c = code, let scalar = UnicodeScalar(c) {
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }
        
        return result
    }
}
