import SwiftUI
import AppKit

// MARK: - Emacs Action Dispatch Model
public enum EmacsAction: Equatable, Hashable {
    case none
    case message(String)
    case save
    case openVaultSearch
    case switchTab
    case closeTab
    case openCalendar
    case openGraph
    case toggleFocus
    case openTOC
    case openAI
    case orgTableAlign
    case orgCycleTask
    case showHelp
    case newDailyNote
    case newNoteFromTemplate
    case exportPDF
    case exportSRT
}

// MARK: - M-x Interactive Minibuffer Command Model
public struct EmacsCommand: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let title: String
    public let shortcutHint: String?
    public let action: EmacsAction
    
    public init(name: String, title: String, shortcutHint: String? = nil, action: EmacsAction) {
        self.name = name
        self.title = title
        self.shortcutHint = shortcutHint
        self.action = action
    }
}

// MARK: - Emacs Controller Singleton
public class EmacsController: ObservableObject {
    public static let shared = EmacsController()
    
    @Published public var isMinibufferOpen: Bool = false
    @Published public var minibufferQuery: String = ""
    @Published public var selectedCommandIndex: Int = 0
    @Published public var statusMessage: String = ""
    @Published public var activePrefix: String? = nil // e.g. "C-x", "C-c", "C-h"
    @Published public var showHelpModal: Bool = false
    
    // Emacs Kill Ring Stack
    private var killRing: [String] = []
    private var lastYankRange: NSRange? = nil
    private var yankIndex: Int = 0
    private var statusTimer: Timer? = nil
    
    // M-x Built-in Command Library
    public let availableCommands: [EmacsCommand] = [
        EmacsCommand(name: "save-buffer", title: "Save Active Note / Buffer", shortcutHint: "C-x C-s", action: .save),
        EmacsCommand(name: "find-file", title: "Find / Search Notes in Vault", shortcutHint: "C-x C-f", action: .openVaultSearch),
        EmacsCommand(name: "switch-to-buffer", title: "Switch Tab / Buffer", shortcutHint: "C-x b", action: .switchTab),
        EmacsCommand(name: "kill-buffer", title: "Close Active Tab / Buffer", shortcutHint: "C-x k", action: .closeTab),
        EmacsCommand(name: "calendar", title: "Open Calendar & Daily Journal Hub", shortcutHint: "⌘⌥C", action: .openCalendar),
        EmacsCommand(name: "daily-note", title: "Create / Open Today's Daily Note", shortcutHint: "⌘D", action: .newDailyNote),
        EmacsCommand(name: "note-template", title: "Insert New Note from Template", shortcutHint: "⌘T", action: .newNoteFromTemplate),
        EmacsCommand(name: "org-table-align", title: "Org-Mode: Auto-Align Markdown Table", shortcutHint: "TAB", action: .orgTableAlign),
        EmacsCommand(name: "org-todo-cycle", title: "Org-Mode: Cycle Task State [ ] / [-] / [x]", shortcutHint: "C-c C-c", action: .orgCycleTask),
        EmacsCommand(name: "graph-view", title: "Open Knowledge Graph Canvas", shortcutHint: "⌘G", action: .openGraph),
        EmacsCommand(name: "zen-focus-mode", title: "Toggle Zen Focus Mode", shortcutHint: "⌘⇧F", action: .toggleFocus),
        EmacsCommand(name: "table-of-contents", title: "Open Document Outline (TOC)", shortcutHint: "⌘⇧O", action: .openTOC),
        EmacsCommand(name: "ai-assistant", title: "Ask Gemma Local AI Study Assistant", shortcutHint: "✨", action: .openAI),
        EmacsCommand(name: "export-pdf-document", title: "Export Document as PDF", shortcutHint: "PDF", action: .exportPDF),
        EmacsCommand(name: "export-subtitles-srt", title: "Export Audio Subtitles (SRT)", shortcutHint: "SRT", action: .exportSRT),
        EmacsCommand(name: "describe-bindings", title: "Emacs & Org-Mode Keybinding Reference", shortcutHint: "C-h m", action: .showHelp)
    ]
    
    public var filteredCommands: [EmacsCommand] {
        let clean = minibufferQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.isEmpty { return availableCommands }
        return availableCommands.filter {
            $0.name.lowercased().contains(clean) || $0.title.lowercased().contains(clean)
        }
    }
    
    public init() {}
    
    public func setStatus(_ msg: String, duration: Double = 3.0) {
        statusMessage = msg
        statusTimer?.invalidate()
        if duration > 0 {
            statusTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    if self?.statusMessage == msg {
                        self?.statusMessage = ""
                    }
                }
            }
        }
    }
    
    // MARK: - Kill-Ring Clipboard Management
    public func pushToKillRing(_ text: String) {
        guard !text.isEmpty else { return }
        killRing.insert(text, at: 0)
        if killRing.count > 40 {
            killRing.removeLast()
        }
        yankIndex = 0
    }
    
    public func peekKillRing() -> String? {
        guard !killRing.isEmpty else { return nil }
        return killRing[safe: yankIndex] ?? killRing.first
    }
    
    // MARK: - Main Key Event Interceptor
    public func handleKeyDown(event: NSEvent, in textView: NSTextView, onAction: @escaping (EmacsAction) -> Void) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCtrl = flags.contains(.control)
        let isAlt = flags.contains(.option)
        let chars = event.charactersIgnoringModifiers ?? ""
        
        // 1. M-x (Alt+X / Option+X) -> Trigger Minibuffer
        if isAlt && chars.lowercased() == "x" {
            DispatchQueue.main.async {
                self.isMinibufferOpen = true
                self.minibufferQuery = ""
                self.selectedCommandIndex = 0
            }
            return true
        }
        
        // 2. Ctrl-G -> Abort / Cancel prefix or active prompt
        if isCtrl && chars.lowercased() == "g" {
            activePrefix = nil
            setStatus("Quit")
            return true
        }
        
        // 3. Handle 2-Chord Prefix States (C-x, C-c, C-h)
        if let prefix = activePrefix {
            activePrefix = nil
            return handleChordKey(prefix: prefix, key: chars.lowercased(), isCtrl: isCtrl, isAlt: isAlt, in: textView, onAction: onAction)
        }
        
        // 4. Check for New Prefix Invocations
        if isCtrl {
            switch chars.lowercased() {
            case "x":
                activePrefix = "C-x"
                setStatus("C-x-")
                return true
            case "c":
                activePrefix = "C-c"
                setStatus("C-c-")
                return true
            case "h":
                activePrefix = "C-h"
                setStatus("C-h-")
                return true
            default:
                break
            }
        }
        
        // 5. Single-Chord GNU Emacs Motions & Edits
        if isCtrl {
            switch chars.lowercased() {
            case "a": // C-a: Beginning of line
                jumpToLineBoundary(in: textView, start: true)
                return true
            case "e": // C-e: End of line
                jumpToLineBoundary(in: textView, start: false)
                return true
            case "f": // C-f: Forward char
                moveCursor(in: textView, by: 1)
                return true
            case "b": // C-b: Backward char
                moveCursor(in: textView, by: -1)
                return true
            case "p": // C-p: Previous line
                moveLine(in: textView, forward: false)
                return true
            case "n": // C-n: Next line
                moveLine(in: textView, forward: true)
                return true
            case "v": // C-v: Scroll page down
                textView.scrollPageDown(nil)
                return true
            case "d": // C-d: Delete forward char
                deleteForward(in: textView)
                return true
            case "k": // C-k: Kill line to end
                killToEndOfLine(in: textView)
                return true
            case "y": // C-y: Yank from kill ring
                yankFromKillRing(in: textView)
                return true
            case "w": // C-w: Kill region / word
                killRegionOrWord(in: textView)
                return true
            case "t": // C-t: Transpose characters
                transposeChars(in: textView)
                return true
            default:
                break
            }
        }
        
        // 6. Meta / Alt-based Single Chords (M-f, M-b, M-v, M-w, M-y, M-<, M->)
        if isAlt {
            switch chars.lowercased() {
            case "f": // M-f: Forward word
                moveWord(in: textView, forward: true)
                return true
            case "b": // M-b: Backward word
                moveWord(in: textView, forward: false)
                return true
            case "v": // M-v: Page up
                textView.scrollPageUp(nil)
                return true
            case "w": // M-w: Copy region to kill ring
                copyRegionToKillRing(in: textView)
                return true
            case "y": // M-y: Yank pop (cycle previous kill)
                yankPop(in: textView)
                return true
            case "<": // M-<: Beginning of buffer
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                return true
            case ">": // M->: End of buffer
                let len = textView.string.count
                textView.setSelectedRange(NSRange(location: len, length: 0))
                textView.scrollRangeToVisible(NSRange(location: len, length: 0))
                return true
            default:
                break
            }
        }
        
        return false
    }
    
    // MARK: - 2-Chord Prefix Dispatcher
    private func handleChordKey(prefix: String, key: String, isCtrl: Bool, isAlt: Bool, in textView: NSTextView, onAction: (EmacsAction) -> Void) -> Bool {
        switch prefix {
        case "C-x":
            if isCtrl || !isCtrl {
                switch key {
                case "s": // C-x C-s / C-x s: Save buffer
                    onAction(.save)
                    setStatus("Wrote note to vault")
                    return true
                case "f": // C-x C-f / C-x f: Find file
                    onAction(.openVaultSearch)
                    return true
                case "b": // C-x b: Switch buffer
                    onAction(.switchTab)
                    return true
                case "k": // C-x k: Kill buffer
                    onAction(.closeTab)
                    return true
                case "u": // C-x u: Undo
                    textView.undoManager?.undo()
                    setStatus("Undo")
                    return true
                case "c": // C-x C-c: Calendar / Daily
                    onAction(.openCalendar)
                    return true
                default:
                    setStatus("C-x \(key) is undefined")
                    return true
                }
            }
        case "C-c":
            switch key {
            case "c": // C-c C-c: Org Task Cycle
                onAction(.orgCycleTask)
                return true
            case "a": // C-c a: Org Table Align
                onAction(.orgTableAlign)
                return true
            default:
                setStatus("C-c \(key) is undefined")
                return true
            }
        case "C-h":
            switch key {
            case "m", "b", "k", "h": // C-h m: Describe bindings
                showHelpModal = true
                return true
            default:
                setStatus("C-h \(key) is undefined")
                return true
            }
        default:
            break
        }
        return false
    }
    
    // MARK: - Emacs Editing Primitives
    private func jumpToLineBoundary(in textView: NSTextView, start: Bool) {
        let text = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let lineRange = text.lineRange(for: selectedRange)
        if start {
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
        } else {
            var endLoc = lineRange.location + lineRange.length
            if endLoc > 0 && endLoc <= text.length && text.substring(with: NSRange(location: endLoc - 1, length: 1)) == "\n" {
                endLoc -= 1
            }
            textView.setSelectedRange(NSRange(location: endLoc, length: 0))
        }
        textView.scrollRangeToVisible(textView.selectedRange())
    }
    
    private func moveCursor(in textView: NSTextView, by offset: Int) {
        let text = textView.string
        let loc = textView.selectedRange().location
        let newLoc = max(0, min(text.count, loc + offset))
        textView.setSelectedRange(NSRange(location: newLoc, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
    }
    
    private func moveLine(in textView: NSTextView, forward: Bool) {
        if forward {
            textView.moveDown(nil)
        } else {
            textView.moveUp(nil)
        }
    }
    
    private func moveWord(in textView: NSTextView, forward: Bool) {
        if forward {
            textView.moveWordForward(nil)
        } else {
            textView.moveWordBackward(nil)
        }
    }
    
    private func deleteForward(in textView: NSTextView) {
        let selected = textView.selectedRange()
        let text = textView.string as NSString
        if selected.length > 0 {
            textView.insertText("", replacementRange: selected)
        } else if selected.location < text.length {
            textView.insertText("", replacementRange: NSRange(location: selected.location, length: 1))
        }
    }
    
    private func killToEndOfLine(in textView: NSTextView) {
        let text = textView.string as NSString
        let selected = textView.selectedRange()
        let lineRange = text.lineRange(for: selected)
        let lineEnd = lineRange.location + lineRange.length
        
        let killRange: NSRange
        if selected.location == lineEnd - 1 && text.substring(with: NSRange(location: selected.location, length: 1)) == "\n" {
            // At newline: kill the newline
            killRange = NSRange(location: selected.location, length: 1)
        } else {
            // Kill from cursor to end of line (excluding newline if present)
            var targetEnd = lineEnd
            if targetEnd > 0 && targetEnd <= text.length && text.substring(with: NSRange(location: targetEnd - 1, length: 1)) == "\n" {
                targetEnd -= 1
            }
            let len = max(0, targetEnd - selected.location)
            killRange = NSRange(location: selected.location, length: len)
        }
        
        if killRange.length > 0 {
            let killedText = text.substring(with: killRange)
            pushToKillRing(killedText)
            textView.insertText("", replacementRange: killRange)
            setStatus("Kill: \(killedText.prefix(20))...")
        }
    }
    
    private func copyRegionToKillRing(in textView: NSTextView) {
        let selected = textView.selectedRange()
        if selected.length > 0 {
            let text = (textView.string as NSString).substring(with: selected)
            pushToKillRing(text)
            setStatus("Copied to kill ring")
        }
    }
    
    private func killRegionOrWord(in textView: NSTextView) {
        let selected = textView.selectedRange()
        if selected.length > 0 {
            let text = (textView.string as NSString).substring(with: selected)
            pushToKillRing(text)
            textView.insertText("", replacementRange: selected)
            setStatus("Killed region")
        } else {
            // Backward kill word
            textView.deleteWordBackward(nil)
        }
    }
    
    private func yankFromKillRing(in textView: NSTextView) {
        guard let text = peekKillRing() else {
            setStatus("Kill ring is empty")
            return
        }
        let loc = textView.selectedRange().location
        textView.insertText(text, replacementRange: textView.selectedRange())
        lastYankRange = NSRange(location: loc, length: (text as NSString).length)
        setStatus("Yanked")
    }
    
    private func yankPop(in textView: NSTextView) {
        guard killRing.count > 1, let lastRange = lastYankRange else { return }
        yankIndex = (yankIndex + 1) % killRing.count
        let nextText = killRing[yankIndex]
        textView.insertText(nextText, replacementRange: lastRange)
        lastYankRange = NSRange(location: lastRange.location, length: (nextText as NSString).length)
        setStatus("Yank pop (\(yankIndex + 1)/\(killRing.count))")
    }
    
    private func transposeChars(in textView: NSTextView) {
        let text = textView.string as NSString
        let loc = textView.selectedRange().location
        guard loc > 0 && loc < text.length else { return }
        let c1 = text.substring(with: NSRange(location: loc - 1, length: 1))
        let c2 = text.substring(with: NSRange(location: loc, length: 1))
        let swap = "\(c2)\(c1)"
        textView.insertText(swap, replacementRange: NSRange(location: loc - 1, length: 2))
    }
}

// MARK: - Collection Safety Extension
private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
