import SwiftUI

// MARK: - Vim Help Cheat Sheet Modal View
public struct VimHelpModalView: View {
    @Binding var isPresented: Bool
    let isDark: Bool
    let primaryAccent: Color
    
    public init(isPresented: Binding<Bool>, isDark: Bool = true, primaryAccent: Color = .indigo) {
        self._isPresented = isPresented
        self.isDark = isDark
        self.primaryAccent = primaryAccent
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.title2)
                        .foregroundColor(primaryAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vim Mode Cheat Sheet")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Modal keyboard shortcuts and : command line references")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.sidebarBackground(isDark))
            
            Divider()
                .background(Color.subtleBorder(isDark))
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Section 1: Modes
                    cheatSection(title: "Modal Transitions", items: [
                        ("i / a", "Insert mode before / after cursor"),
                        ("I / A", "Insert at beginning / end of current line"),
                        ("o / O", "Open new line below / above and enter insert mode"),
                        ("v / V", "Character visual mode / line visual mode"),
                        ("ESC / Ctrl+[", "Exit to Normal mode / cancel command line"),
                        (":", "Open Vim Command-Line prompt")
                    ])
                    
                    // Section 2: Motions
                    cheatSection(title: "Motions & Navigation", items: [
                        ("h / j / k / l", "Move cursor Left / Down / Up / Right"),
                        ("w / b / e", "Jump forward / backward by word, end of word"),
                        ("0 / $", "Jump to line start / line end"),
                        ("gg / G", "Jump to top of document / bottom of document")
                    ])
                    
                    // Section 3: Editing
                    cheatSection(title: "Editing & Clipboard", items: [
                        ("x", "Delete character under cursor"),
                        ("dd", "Delete (cut) entire line to clipboard"),
                        ("yy", "Yank (copy) entire line to clipboard"),
                        ("p / P", "Paste clipboard after / before cursor"),
                        ("u / Ctrl+r", "Undo / Redo last edit")
                    ])
                    
                    // Section 4: Command Line
                    cheatSection(title: "Command-Line ( : ) Shortcuts", items: [
                        (":w", "Save active note to vault"),
                        (":q / :q!", "Close active note tab"),
                        (":wq / :x", "Save note and close tab"),
                        (":tabn / :tabp", "Navigate to Next / Previous tab"),
                        (":tabnew / :new", "Create a new note in new tab"),
                        (":set nu / :set nonu", "Enable / Disable line numbers"),
                        (":graph", "Open Knowledge Graph canvas"),
                        (":zen", "Toggle Zen focus mode"),
                        (":toc", "Toggle Table of Contents outline"),
                        (":ai", "Open Gemma AI Study Assistant"),
                        (":%s/old/new/g", "Find and replace all occurrences in note")
                    ])
                }
                .padding(16)
            }
            
            Divider()
                .background(Color.subtleBorder(isDark))
            
            // Footer
            HStack {
                Text("Press ESC anytime to return to Normal mode.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(primaryAccent)
                .cornerRadius(AppRadius.sm)
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: 580, height: 500)
        .background(Color.panelBackground(isDark))
        .cornerRadius(AppRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
    }
    
    private func cheatSection(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(primaryAccent)
                .textCase(.uppercase)
            
            VStack(spacing: 4) {
                ForEach(items, id: \.0) { key, desc in
                    HStack {
                        Text(key)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(4)
                            .frame(minWidth: 100, alignment: .leading)
                        
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(10)
            .background(Color.cardBackground(isDark))
            .cornerRadius(AppRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 1)
            )
        }
    }
}
