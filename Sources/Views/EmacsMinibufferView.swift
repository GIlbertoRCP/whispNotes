import SwiftUI

// MARK: - Interactive M-x Minibuffer Command Runner & Emacs Status Bar
public struct EmacsMinibufferView: View {
    @ObservedObject var emacs = EmacsController.shared
    let isDark: Bool
    let primaryAccent: Color
    let onExecute: (EmacsAction) -> Void
    
    @FocusState private var isFieldFocused: Bool
    
    public init(isDark: Bool, primaryAccent: Color, onExecute: @escaping (EmacsAction) -> Void) {
        self.isDark = isDark
        self.primaryAccent = primaryAccent
        self.onExecute = onExecute
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if emacs.isMinibufferOpen {
                VStack(spacing: 0) {
                    // Command suggestions list (if matching)
                    let matches = emacs.filteredCommands
                    if !matches.isEmpty {
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(Array(matches.prefix(6).enumerated()), id: \.element.id) { idx, cmd in
                                    Button(action: {
                                        executeCommand(cmd)
                                    }) {
                                        HStack(spacing: 8) {
                                            Text(cmd.name)
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundColor(emacs.selectedCommandIndex == idx ? .white : (isDark ? .white : .black))
                                            
                                            Text("— \(cmd.title)")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(emacs.selectedCommandIndex == idx ? Color.white.opacity(0.85) : .secondary)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            if let hint = cmd.shortcutHint {
                                                Text(hint)
                                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(emacs.selectedCommandIndex == idx ? Color.white.opacity(0.2) : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                                                    .foregroundColor(emacs.selectedCommandIndex == idx ? .white : .secondary)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(emacs.selectedCommandIndex == idx ? primaryAccent : Color.clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(6)
                        }
                        .frame(maxHeight: 180)
                        
                        Divider()
                            .background(Color.subtleBorder(isDark))
                    }
                    
                    // Minibuffer Input Line
                    HStack(spacing: 8) {
                        Text("M-x")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(primaryAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(primaryAccent.opacity(0.15))
                            .cornerRadius(4)
                        
                        TextField("Type Emacs command (e.g. save-buffer, calendar, org-table-align)...", text: $emacs.minibufferQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .focused($isFieldFocused)
                            .onSubmit {
                                if let target = matches.first {
                                    executeCommand(target)
                                }
                            }
                        
                        Button("Cancel") {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                emacs.isMinibufferOpen = false
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Color.cardBackgroundElevated(isDark))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(primaryAccent.opacity(0.5), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .onAppear {
                    isFieldFocused = true
                }
            } else if !emacs.statusMessage.isEmpty || emacs.activePrefix != nil {
                // Emacs Floating Echo Toast
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 10))
                        .foregroundColor(primaryAccent)
                    
                    Text(emacs.activePrefix != nil ? "\(emacs.activePrefix!)-" : emacs.statusMessage)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cardBackgroundElevated(isDark))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func executeCommand(_ cmd: EmacsCommand) {
        withAnimation(.easeInOut(duration: 0.12)) {
            emacs.isMinibufferOpen = false
            emacs.minibufferQuery = ""
        }
        onExecute(cmd.action)
    }
}
