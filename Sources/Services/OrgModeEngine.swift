import SwiftUI
import AppKit

// MARK: - Org-Mode Productivity Engine
public struct OrgModeEngine {
    
    // MARK: - 1. Table Detection & Auto-Alignment
    public static func isInsideTable(in textView: NSTextView) -> Bool {
        let text = textView.string as NSString
        let loc = textView.selectedRange().location
        guard loc <= text.length else { return false }
        let lineRange = text.lineRange(for: NSRange(location: loc, length: 0))
        let line = text.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
        return line.contains("|")
    }
    
    public static func alignTableAtCursor(in textView: NSTextView) -> Bool {
        let fullText = textView.string as NSString
        let cursorLoc = textView.selectedRange().location
        guard cursorLoc <= fullText.length else { return false }
        
        let currentLineRange = fullText.lineRange(for: NSRange(location: cursorLoc, length: 0))
        let currentLineText = fullText.substring(with: currentLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentLineText.contains("|") else { return false }
        
        // Find full table range (contiguous lines with '|')
        var tableStart = currentLineRange.location
        var tableEnd = currentLineRange.location + currentLineRange.length
        
        // Walk backwards
        while tableStart > 0 {
            let prevRange = fullText.lineRange(for: NSRange(location: tableStart - 1, length: 0))
            let prevLine = fullText.substring(with: prevRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if prevLine.contains("|") {
                tableStart = prevRange.location
            } else {
                break
            }
        }
        
        // Walk forwards
        while tableEnd < fullText.length {
            let nextRange = fullText.lineRange(for: NSRange(location: tableEnd, length: 0))
            let nextLine = fullText.substring(with: nextRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if nextLine.contains("|") {
                tableEnd = nextRange.location + nextRange.length
            } else {
                break
            }
        }
        
        let tableRange = NSRange(location: tableStart, length: tableEnd - tableStart)
        let tableBlock = fullText.substring(with: tableRange)
        let rawLines = tableBlock.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !rawLines.isEmpty else { return false }
        
        // Parse rows and columns
        var parsedRows: [[String]] = []
        var maxCols = 0
        
        for line in rawLines {
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|") { trimmed.removeFirst() }
            if trimmed.hasSuffix("|") { trimmed.removeLast() }
            let cells = trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            parsedRows.append(cells)
            maxCols = max(maxCols, cells.count)
        }
        
        guard maxCols > 0 else { return false }
        
        // Compute column widths
        var colWidths = Array(repeating: 3, count: maxCols)
        for row in parsedRows {
            let isDivider = row.allSatisfy { $0.contains("-") }
            if !isDivider {
                for (colIdx, cell) in row.enumerated() {
                    colWidths[colIdx] = max(colWidths[colIdx], cell.count)
                }
            }
        }
        
        // Format aligned table
        var formattedLines: [String] = []
        for row in parsedRows {
            let isDivider = row.allSatisfy { $0.contains("-") || $0.isEmpty }
            var rowCells: [String] = []
            
            for colIdx in 0..<maxCols {
                let cell = colIdx < row.count ? row[colIdx] : ""
                let width = colWidths[colIdx]
                if isDivider {
                    rowCells.append(String(repeating: "-", count: max(3, width + 2)))
                } else {
                    let padding = max(0, width - cell.count)
                    rowCells.append(" " + cell + String(repeating: " ", count: padding) + " ")
                }
            }
            formattedLines.append("|" + rowCells.joined(separator: "|") + "|")
        }
        
        let formattedTable = formattedLines.joined(separator: "\n") + (tableEnd < fullText.length ? "\n" : "")
        textView.insertText(formattedTable, replacementRange: tableRange)
        return true
    }
    
    // MARK: - 2. Task State Cycling (- [ ] -> - [-] -> - [x])
    public static func cycleTaskState(in textView: NSTextView) -> Bool {
        let fullText = textView.string as NSString
        let loc = textView.selectedRange().location
        guard loc <= fullText.length else { return false }
        
        let lineRange = fullText.lineRange(for: NSRange(location: loc, length: 0))
        let lineText = fullText.substring(with: lineRange)
        
        var newLineText = lineText
        if lineText.contains("- [ ] ") {
            newLineText = lineText.replacingOccurrences(of: "- [ ] ", with: "- [-] ")
        } else if lineText.contains("- [-] ") {
            newLineText = lineText.replacingOccurrences(of: "- [-] ", with: "- [x] ")
        } else if lineText.contains("- [x] ") {
            newLineText = lineText.replacingOccurrences(of: "- [x] ", with: "- [ ] ")
        } else if lineText.contains("* [ ] ") {
            newLineText = lineText.replacingOccurrences(of: "* [ ] ", with: "* [-] ")
        } else if lineText.contains("* [-] ") {
            newLineText = lineText.replacingOccurrences(of: "* [-] ", with: "* [x] ")
        } else if lineText.contains("* [x] ") {
            newLineText = lineText.replacingOccurrences(of: "* [x] ", with: "* [ ] ")
        } else if lineText.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
            newLineText = lineText.replacingOccurrences(of: "- ", with: "- [ ] ")
        } else if lineText.trimmingCharacters(in: .whitespaces).hasPrefix("• ") {
            newLineText = lineText.replacingOccurrences(of: "• ", with: "- [ ] ")
        } else {
            // Turn raw line into task
            let leadingSpaces = lineText.prefix(while: { $0 == " " || $0 == "\t" })
            let rest = lineText.dropFirst(leadingSpaces.count)
            newLineText = "\(leadingSpaces)- [ ] \(rest)"
        }
        
        if newLineText != lineText {
            textView.insertText(newLineText, replacementRange: lineRange)
            return true
        }
        return false
    }
}
