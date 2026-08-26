import SwiftUI
import AppKit

// MARK: - Vim Mode Definition
public enum VimMode: String, CaseIterable {
    case normal = "NORMAL"
    case insert = "INSERT"
    case visual = "VISUAL"
    case visualLine = "V-LINE"
    case command = "COMMAND"
    
    public var accentColor: Color {
        switch self {
        case .normal: return Color(red: 99/255, green: 102/255, blue: 241/255) // Indigo
        case .insert: return Color(red: 16/255, green: 185/255, blue: 129/255) // Emerald
        case .visual: return Color(red: 245/255, green: 158/255, blue: 11/255) // Amber
        case .visualLine: return Color(red: 234/255, green: 88/255, blue: 12/255) // Orange
        case .command: return Color(red: 168/255, green: 85/255, blue: 247/255) // Purple
        }
    }
}

// MARK: - Vim Command Execution Action
public enum VimAction {
    case none
    case message(String)
    case save
    case closeTab
    case saveAndClose
    case nextTab
    case prevTab
    case newTab
    case toggleLineNumbers
    case openGraph
    case toggleFocus
    case openTOC
    case openAI
    case showHelp
    case replaceText(find: String, replace: String, isGlobal: Bool)
}

// MARK: - Vim Controller Engine
public class VimController: ObservableObject {
    public static let shared = VimController()
    
    @Published public var mode: VimMode = .normal
    @Published public var commandText: String = ""
    @Published public var statusMessage: String = ""
    @Published public var cursorLine: Int = 1
    @Published public var cursorColumn: Int = 1
    @Published public var showHelpModal: Bool = false
    @Published public var showLineNumbers: Bool = false
    
    private var pendingKeys: String = ""
    private var visualStartLocation: Int = 0
    private var statusClearTimer: Timer? = nil
    private var yankBuffer: String = ""
    private var isLineYank: Bool = false

    public init() {}
    
    public func setStatus(_ msg: String, duration: Double = 3.0) {
        statusMessage = msg
        statusClearTimer?.invalidate()
        if duration > 0 {
            statusClearTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    if self?.statusMessage == msg {
                        self?.statusMessage = ""
                    }
                }
            }
        }
    }

    public func updateCursorPosition(in textView: NSTextView) {
        let selectedRange = textView.selectedRange()
        let text = textView.string
        let loc = min(selectedRange.location, text.count)
        
        let prefix = (text as NSString).substring(to: loc)
        let lines = prefix.components(separatedBy: "\n")
        cursorLine = max(1, lines.count)
        cursorColumn = max(1, (lines.last?.count ?? 0) + 1)
    }

    // MARK: - Key Event Handling
    public func handleKeyDown(event: NSEvent, in textView: NSTextView, onAction: (VimAction) -> Void) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""
        let keyCode = event.keyCode
        
        // 1. Universal Escape Key (ESC keycode 53 or Ctrl+[)
        if keyCode == 53 || (flags.contains(.control) && chars == "[") {
            pendingKeys = ""
            if mode == .command {
                mode = .normal
                commandText = ""
                return true
            }
            if mode != .normal {
                mode = .normal
                // Move cursor back 1 if not at line start
                let range = textView.selectedRange()
                if range.location > 0 {
                    let text = textView.string
                    let indexBefore = (text as NSString).rangeOfCharacter(from: .newlines, options: .backwards, range: NSRange(location: range.location - 1, length: 1))
                    if indexBefore.location == NSNotFound {
                        textView.setSelectedRange(NSRange(location: max(0, range.location - 1), length: 0))
                    }
                }
                updateCursorPosition(in: textView)
                return true
            }
            return true
        }

        // 2. Command Line Mode
        if mode == .command {
            if keyCode == 36 { // Enter / Return
                let cmd = commandText
                commandText = ""
                mode = .normal
                let action = executeCommand(cmd, in: textView)
                onAction(action)
                return true
            } else if keyCode == 51 { // Backspace
                if commandText.isEmpty {
                    mode = .normal
                    return true
                }
                commandText.removeLast()
                return true
            } else if let chars = event.characters, !chars.isEmpty {
                commandText += chars
                return true
            }
            return true
        }

        // 3. Insert Mode: standard typing flows through
        if mode == .insert {
            return false
        }

        // 4. Visual Mode Handling
        if mode == .visual || mode == .visualLine {
            return handleVisualModeKeys(chars: chars, flags: flags, in: textView, onAction: onAction)
        }

        // 5. Normal Mode Handling
        if mode == .normal {
            return handleNormalModeKeys(chars: chars, flags: flags, in: textView, onAction: onAction)
        }

        return false
    }

    // MARK: - Normal Mode Key Processing
    private func handleNormalModeKeys(chars: String, flags: NSEvent.ModifierFlags, in textView: NSTextView, onAction: (VimAction) -> Void) -> Bool {
        let text = textView.string
        let range = textView.selectedRange()
        let loc = range.location
        let nsText = text as NSString

        // Command Mode trigger ':'
        if chars == ":" {
            mode = .command
            commandText = ""
            return true
        }

        // Mode switch to Insert 'i', 'a', 'I', 'A', 'o', 'O'
        if chars == "i" {
            mode = .insert
            return true
        }
        if chars == "a" {
            mode = .insert
            if loc < text.count {
                textView.setSelectedRange(NSRange(location: loc + 1, length: 0))
                updateCursorPosition(in: textView)
            }
            return true
        }
        if chars == "I" {
            mode = .insert
            let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
            let lineContent = nsText.substring(with: lineRange)
            let trimmedLeading = lineContent.prefix { $0.isWhitespace && $0 != "\n" }.count
            textView.setSelectedRange(NSRange(location: lineRange.location + trimmedLeading, length: 0))
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "A" {
            mode = .insert
            let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
            let end = max(lineRange.location, lineRange.location + lineRange.length - (lineRange.length > 0 && nsText.substring(with: NSRange(location: lineRange.location + lineRange.length - 1, length: 1)) == "\n" ? 1 : 0))
            textView.setSelectedRange(NSRange(location: end, length: 0))
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "o" {
            mode = .insert
            let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
            let end = max(lineRange.location, lineRange.location + lineRange.length - (lineRange.length > 0 && nsText.substring(with: NSRange(location: lineRange.location + lineRange.length - 1, length: 1)) == "\n" ? 1 : 0))
            textView.insertText("\n", replacementRange: NSRange(location: end, length: 0))
            textView.setSelectedRange(NSRange(location: end + 1, length: 0))
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "O" {
            mode = .insert
            let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
            textView.insertText("\n", replacementRange: NSRange(location: lineRange.location, length: 0))
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
            updateCursorPosition(in: textView)
            return true
        }

        // Visual Mode switches
        if chars == "v" {
            mode = .visual
            visualStartLocation = loc
            return true
        }
        if chars == "V" {
            mode = .visualLine
            let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
            visualStartLocation = lineRange.location
            textView.setSelectedRange(lineRange)
            return true
        }

        // Undo & Redo
        if chars == "u" {
            textView.undoManager?.undo()
            setStatus("Undo")
            updateCursorPosition(in: textView)
            return true
        }
        if flags.contains(.control) && chars == "r" {
            textView.undoManager?.redo()
            setStatus("Redo")
            updateCursorPosition(in: textView)
            return true
        }

        // Delete char 'x'
        if chars == "x" {
            if loc < text.count {
                let charRange = NSRange(location: loc, length: 1)
                let charToDelete = nsText.substring(with: charRange)
                if charToDelete != "\n" {
                    textView.insertText("", replacementRange: charRange)
                    textView.setSelectedRange(NSRange(location: min(loc, (textView.string as NSString).length), length: 0))
                }
            }
            updateCursorPosition(in: textView)
            return true
        }

        // Multi-key sequences: 'dd', 'yy', 'gg'
        if pendingKeys == "d" {
            pendingKeys = ""
            if chars == "d" {
                // Delete whole line
                let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
                yankBuffer = nsText.substring(with: lineRange)
                isLineYank = true
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(yankBuffer, forType: .string)
                textView.insertText("", replacementRange: lineRange)
                setStatus("1 line deleted")
                updateCursorPosition(in: textView)
                return true
            }
            return true
        }
        if pendingKeys == "y" {
            pendingKeys = ""
            if chars == "y" {
                // Yank line
                let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
                yankBuffer = nsText.substring(with: lineRange)
                isLineYank = true
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(yankBuffer, forType: .string)
                setStatus("1 line yanked")
                return true
            }
            return true
        }
        if pendingKeys == "g" {
            pendingKeys = ""
            if chars == "g" {
                // Jump to top of document
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                updateCursorPosition(in: textView)
                return true
            }
            return true
        }

        if chars == "d" {
            pendingKeys = "d"
            return true
        }
        if chars == "y" {
            pendingKeys = "y"
            return true
        }
        if chars == "g" {
            pendingKeys = "g"
            return true
        }

        // Paste 'p' (after) and 'P' (before)
        if chars == "p" {
            let pboardString = NSPasteboard.general.string(forType: .string) ?? yankBuffer
            if !pboardString.isEmpty {
                if isLineYank || pboardString.hasSuffix("\n") {
                    let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
                    let insertLoc = lineRange.location + lineRange.length
                    textView.insertText(pboardString.hasSuffix("\n") ? pboardString : pboardString + "\n", replacementRange: NSRange(location: insertLoc, length: 0))
                    textView.setSelectedRange(NSRange(location: insertLoc, length: 0))
                } else {
                    let insertLoc = min(loc + 1, text.count)
                    textView.insertText(pboardString, replacementRange: NSRange(location: insertLoc, length: 0))
                }
                setStatus("Pasted")
                updateCursorPosition(in: textView)
            }
            return true
        }
        if chars == "P" {
            let pboardString = NSPasteboard.general.string(forType: .string) ?? yankBuffer
            if !pboardString.isEmpty {
                if isLineYank || pboardString.hasSuffix("\n") {
                    let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
                    textView.insertText(pboardString.hasSuffix("\n") ? pboardString : pboardString + "\n", replacementRange: NSRange(location: lineRange.location, length: 0))
                    textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                } else {
                    textView.insertText(pboardString, replacementRange: NSRange(location: loc, length: 0))
                }
                setStatus("Pasted before")
                updateCursorPosition(in: textView)
            }
            return true
        }

        // Single Character Motions: h, j, k, l, w, b, e, 0, $, G
        if chars == "h" {
            if loc > 0 {
                textView.setSelectedRange(NSRange(location: loc - 1, length: 0))
                updateCursorPosition(in: textView)
            }
            return true
        }
        if chars == "l" {
            if loc < text.count {
                textView.setSelectedRange(NSRange(location: loc + 1, length: 0))
                updateCursorPosition(in: textView)
            }
            return true
        }
        if chars == "j" {
            moveLine(in: textView, down: true)
            return true
        }
        if chars == "k" {
            moveLine(in: textView, down: false)
            return true
        }
        if chars == "0" {
            let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "$" {
            let lineRange = nsText.lineRange(for: NSRange(location: loc, length: 0))
            let end = max(lineRange.location, lineRange.location + lineRange.length - (lineRange.length > 0 && nsText.substring(with: NSRange(location: lineRange.location + lineRange.length - 1, length: 1)) == "\n" ? 1 : 0))
            textView.setSelectedRange(NSRange(location: end, length: 0))
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "G" {
            // Jump to end of document
            textView.setSelectedRange(NSRange(location: text.count, length: 0))
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "w" {
            // Next word motion
            let nextWordLoc = findNextWord(in: text, from: loc)
            textView.setSelectedRange(NSRange(location: nextWordLoc, length: 0))
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "b" {
            // Previous word motion
            let prevWordLoc = findPrevWord(in: text, from: loc)
            textView.setSelectedRange(NSRange(location: prevWordLoc, length: 0))
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "e" {
            // End of word motion
            let endWordLoc = findEndOfWord(in: text, from: loc)
            textView.setSelectedRange(NSRange(location: endWordLoc, length: 0))
            updateCursorPosition(in: textView)
            return true
        }

        return true // Prevent default character insertion in Normal mode
    }

    // MARK: - Visual Mode Key Processing
    private func handleVisualModeKeys(chars: String, flags: NSEvent.ModifierFlags, in textView: NSTextView, onAction: (VimAction) -> Void) -> Bool {
        let text = textView.string
        let nsText = text as NSString
        let selectedRange = textView.selectedRange()

        if chars == "y" {
            // Yank selection
            yankBuffer = nsText.substring(with: selectedRange)
            isLineYank = (mode == .visualLine)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(yankBuffer, forType: .string)
            mode = .normal
            textView.setSelectedRange(NSRange(location: selectedRange.location, length: 0))
            setStatus("Yanked selection")
            return true
        }
        if chars == "d" || chars == "x" {
            // Delete selection
            yankBuffer = nsText.substring(with: selectedRange)
            isLineYank = (mode == .visualLine)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(yankBuffer, forType: .string)
            textView.insertText("", replacementRange: selectedRange)
            mode = .normal
            setStatus("Deleted selection")
            updateCursorPosition(in: textView)
            return true
        }
        if chars == "c" {
            // Change selection
            textView.insertText("", replacementRange: selectedRange)
            mode = .insert
            return true
        }

        // Motions in visual mode
        if chars == "h" || chars == "l" || chars == "j" || chars == "k" || chars == "w" || chars == "b" || chars == "0" || chars == "$" {
            var newEnd = selectedRange.location + selectedRange.length
            if chars == "h" { newEnd = max(0, newEnd - 1) }
            if chars == "l" { newEnd = min(text.count, newEnd + 1) }
            if chars == "0" {
                let lineRange = nsText.lineRange(for: NSRange(location: newEnd, length: 0))
                newEnd = lineRange.location
            }
            if chars == "$" {
                let lineRange = nsText.lineRange(for: NSRange(location: newEnd, length: 0))
                newEnd = lineRange.location + lineRange.length
            }

            let start = min(visualStartLocation, newEnd)
            let len = max(1, abs(visualStartLocation - newEnd))
            textView.setSelectedRange(NSRange(location: start, length: len))
            updateCursorPosition(in: textView)
            return true
        }

        return true
    }

    // MARK: - Motion Helpers
    private func moveLine(in textView: NSTextView, down: Bool) {
        let text = textView.string
        let nsText = text as NSString
        let range = textView.selectedRange()
        let currentLoc = range.location
        
        let currentLineRange = nsText.lineRange(for: NSRange(location: currentLoc, length: 0))
        let colOffset = currentLoc - currentLineRange.location
        
        if down {
            let nextLineStart = currentLineRange.location + currentLineRange.length
            if nextLineStart < text.count {
                let nextLineRange = nsText.lineRange(for: NSRange(location: nextLineStart, length: 0))
                let newLoc = min(nextLineRange.location + colOffset, nextLineRange.location + max(0, nextLineRange.length - 1))
                textView.setSelectedRange(NSRange(location: newLoc, length: 0))
            }
        } else {
            if currentLineRange.location > 0 {
                let prevCharLoc = currentLineRange.location - 1
                let prevLineRange = nsText.lineRange(for: NSRange(location: prevCharLoc, length: 0))
                let newLoc = min(prevLineRange.location + colOffset, prevLineRange.location + max(0, prevLineRange.length - 1))
                textView.setSelectedRange(NSRange(location: newLoc, length: 0))
            }
        }
        updateCursorPosition(in: textView)
    }

    private func findNextWord(in text: String, from loc: Int) -> Int {
        var idx = loc
        let chars = Array(text)
        // Skip current non-whitespace
        while idx < chars.count && !chars[idx].isWhitespace && !chars[idx].isNewline {
            idx += 1
        }
        // Skip whitespaces
        while idx < chars.count && (chars[idx].isWhitespace || chars[idx].isNewline) {
            idx += 1
        }
        return min(idx, text.count)
    }

    private func findPrevWord(in text: String, from loc: Int) -> Int {
        var idx = max(0, loc - 1)
        let chars = Array(text)
        // Skip whitespaces backwards
        while idx > 0 && (chars[idx].isWhitespace || chars[idx].isNewline) {
            idx -= 1
        }
        // Skip word characters backwards
        while idx > 0 && !chars[idx - 1].isWhitespace && !chars[idx - 1].isNewline {
            idx -= 1
        }
        return max(0, idx)
    }

    private func findEndOfWord(in text: String, from loc: Int) -> Int {
        var idx = loc + 1
        let chars = Array(text)
        // Skip whitespaces
        while idx < chars.count && (chars[idx].isWhitespace || chars[idx].isNewline) {
            idx += 1
        }
        // Advance to end of word
        while idx < chars.count - 1 && !chars[idx + 1].isWhitespace && !chars[idx + 1].isNewline {
            idx += 1
        }
        return min(idx, text.count)
    }

    // MARK: - Command Evaluation Engine (:w, :q, :wq, :tabn, etc.)
    public func executeCommand(_ rawCommand: String, in textView: NSTextView) -> VimAction {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .none }

        // :w or :write
        if trimmed == "w" || trimmed == "write" {
            setStatus("[Written] Note saved to vault")
            return .save
        }

        // :q or :quit
        if trimmed == "q" || trimmed == "quit" || trimmed == "q!" {
            setStatus("Tab closed")
            return .closeTab
        }

        // :wq or :x
        if trimmed == "wq" || trimmed == "x" {
            setStatus("[Written & Closed]")
            return .saveAndClose
        }

        // :tabn or :bnext
        if trimmed == "tabn" || trimmed == "tabnext" || trimmed == "bnext" || trimmed == "bn" {
            return .nextTab
        }

        // :tabp or :bprev
        if trimmed == "tabp" || trimmed == "tabprev" || trimmed == "bprev" || trimmed == "bp" {
            return .prevTab
        }

        // :tabnew or :new or :e
        if trimmed == "tabnew" || trimmed == "tabe" || trimmed == "new" || trimmed.hasPrefix("e ") {
            return .newTab
        }

        // :set nu / :set nonu
        if trimmed == "set nu" || trimmed == "set number" {
            showLineNumbers = true
            setStatus("Line numbers enabled")
            return .toggleLineNumbers
        }
        if trimmed == "set nonu" || trimmed == "set nonumber" {
            showLineNumbers = false
            setStatus("Line numbers disabled")
            return .toggleLineNumbers
        }

        // :graph
        if trimmed == "graph" || trimmed == "kg" {
            return .openGraph
        }

        // :zen
        if trimmed == "zen" || trimmed == "focus" {
            return .toggleFocus
        }

        // :toc
        if trimmed == "toc" || trimmed == "outline" {
            return .openTOC
        }

        // :ai
        if trimmed == "ai" || trimmed == "study" || trimmed == "gemma" {
            return .openAI
        }

        // :help or :h
        if trimmed == "help" || trimmed == "h" {
            showHelpModal = true
            return .showHelp
        }

        // :%s/find/replace/g or :s/find/replace/g
        if trimmed.hasPrefix("%s/") || trimmed.hasPrefix("s/") {
            let isGlobal = trimmed.hasPrefix("%s/")
            let patternPart = String(trimmed.dropFirst(isGlobal ? 3 : 2))
            let parts = patternPart.components(separatedBy: "/")
            if parts.count >= 2 {
                let findTerm = parts[0]
                let replaceTerm = parts[1]
                return .replaceText(find: findTerm, replace: replaceTerm, isGlobal: isGlobal)
            }
        }

        setStatus("E492: Not an editor command: \(trimmed)")
        return .message("E492: Not an editor command: \(trimmed)")
    }
}
