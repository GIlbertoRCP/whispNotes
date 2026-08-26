import SwiftUI

// MARK: - Interactive Emacs & Org-Mode Keybinding Reference Modal
public struct EmacsHelpModalView: View {
    @Binding var isPresented: Bool
    let isDark: Bool
    let primaryAccent: Color
    
    public init(isPresented: Binding<Bool>, isDark: Bool, primaryAccent: Color) {
        self._isPresented = isPresented
        self.isDark = isDark
        self.primaryAccent = primaryAccent
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "keyboard.fill")
                    .font(.title2)
                    .foregroundColor(primaryAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("GNU Emacs & Org-Mode Keybindings")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Keyboard commands and modal editing reference in WhispNotes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color.sidebarBackground(isDark))
            
            Divider()
                .background(Color.subtleBorder(isDark))
            
            ScrollView {
                VStack(spacing: 16) {
                    // Category 1: Navigation Motions
                    cheatSection(title: "CURSOR MOTIONS & NAVIGATION", items: [
                        ("C-a", "Jump to Beginning of Line"),
                        ("C-e", "Jump to End of Line"),
                        ("C-f", "Move Forward One Character"),
                        ("C-b", "Move Backward One Character"),
                        ("M-f (⌥f)", "Move Forward One Word"),
                        ("M-b (⌥b)", "Move Backward One Word"),
                        ("C-p", "Previous Line (Up)"),
                        ("C-n", "Next Line (Down)"),
                        ("M-v (⌥v)", "Scroll Page Up"),
                        ("C-v", "Scroll Page Down"),
                        ("M-< (⌥<)", "Jump to Start of Buffer"),
                        ("M-> (⌥>)", "Jump to End of Buffer")
                    ])
                    
                    // Category 2: Kill Ring & Clipboard
                    cheatSection(title: "KILL RING & EDITING", items: [
                        ("C-k", "Kill line from cursor to end into Kill Ring"),
                        ("C-y", "Yank (paste) most recent item from Kill Ring"),
                        ("M-y (⌥y)", "Yank-Pop: cycle through previous kill-ring items"),
                        ("M-w (⌥w)", "Copy active selection into Kill Ring"),
                        ("C-w", "Kill active selection / word backward"),
                        ("C-d", "Delete forward character"),
                        ("C-t", "Transpose (swap) two adjacent characters"),
                        ("C-x u", "Undo last editing operation"),
                        ("C-g", "Abort / Quit active command or prefix")
                    ])
                    
                    // Category 3: Buffer & File Chords
                    cheatSection(title: "BUFFER & FILE CHORDS (C-x)", items: [
                        ("C-x C-s", "Save active buffer / note to vault"),
                        ("C-x C-f", "Find note / open full-text vault search"),
                        ("C-x b", "Switch active tab / buffer"),
                        ("C-x k", "Kill (close) active tab / buffer"),
                        ("C-x C-c", "Open Calendar & Daily Journal Hub"),
                        ("M-x (⌥x)", "Interactive Minibuffer Command Runner")
                    ])
                    
                    // Category 4: Org-Mode Tools
                    cheatSection(title: "ORG-MODE PRODUCTIVITY SUITE", items: [
                        ("TAB", "Auto-align Markdown/Org table and jump cell"),
                        ("C-c C-c", "Cycle task state: [ ] → [-] → [x]"),
                        ("C-c a", "Force align entire active table block")
                    ])
                }
                .padding(18)
            }
            .background(Color.panelBackground(isDark))
            
            Divider()
                .background(Color.subtleBorder(isDark))
            
            HStack {
                Text("Tip: Press **⌥X** anytime to run commands from the M-x minibuffer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(primaryAccent)
            }
            .padding(14)
            .background(Color.sidebarBackground(isDark))
        }
        .frame(width: 620, height: 500)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
    }
    
    private func cheatSection(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isDark ? Color(red: 148/255, green: 163/255, blue: 184/255) : Color(red: 100/255, green: 116/255, blue: 139/255))
            
            VStack(spacing: 4) {
                ForEach(items, id: \.0) { key, desc in
                    HStack {
                        Text(key)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(primaryAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(primaryAccent.opacity(0.12))
                            .cornerRadius(4)
                            .frame(minWidth: 90, alignment: .leading)
                        
                        Text(desc)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isDark ? Color(red: 226/255, green: 232/255, blue: 240/255) : Color(red: 30/255, green: 41/255, blue: 59/255))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                }
            }
            .padding(10)
            .background(Color.cardBackground(isDark))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 0.5)
            )
        }
    }
}
