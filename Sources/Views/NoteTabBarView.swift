import SwiftUI

// MARK: - Modern Glassmorphic Multi-Tab Bar View
struct NoteTabBarView: View {
    @ObservedObject var tabManager: TabNavigationManager = .shared
    @Binding var notes: [NoteItem]
    var isSidebarOpen: Bool = true
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    let onNewTab: () -> Void
    
    init(
        tabManager: TabNavigationManager = .shared,
        notes: Binding<[NoteItem]>,
        isSidebarOpen: Bool = true,
        isDark: Bool,
        primaryAccent: Color,
        secondaryAccent: Color,
        onNewTab: @escaping () -> Void
    ) {
        self.tabManager = tabManager
        self._notes = notes
        self.isSidebarOpen = isSidebarOpen
        self.isDark = isDark
        self.primaryAccent = primaryAccent
        self.secondaryAccent = secondaryAccent
        self.onNewTab = onNewTab
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 3) {
                        ForEach(Array(tabManager.openTabIds.enumerated()), id: \.element) { index, tabId in
                            if let note = notes.first(where: { $0.id == tabId }) {
                                TabItemView(
                                    note: note,
                                    isActive: tabManager.activeTabId == tabId,
                                    index: index,
                                    isDark: isDark,
                                    primaryAccent: primaryAccent,
                                    onSelect: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            tabManager.selectTab(at: index)
                                        }
                                    },
                                    onClose: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            tabManager.closeTab(tabId)
                                        }
                                    },
                                    onCloseOthers: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            tabManager.closeOtherTabs(tabId)
                                        }
                                    },
                                    onCloseToRight: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            tabManager.closeTabsToRight(tabId)
                                        }
                                    }
                                )
                                .id(tabId)
                            }
                        }
                        
                        // New Tab '+' Action Button directly adjacent to the tabs
                        Button(action: onNewTab) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 18, height: 18)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(AppRadius.xs)
                        }
                        .buttonStyle(.plain)
                        .help("New Tab (⌘T)")
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .onChange(of: tabManager.activeTabId) { _, newActiveId in
                        if let id = newActiveId {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: 28)
        .background(Color.sidebarBackground(isDark))
        .overlay(
            Rectangle()
                .fill(Color.subtleBorder(isDark))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Individual Tab Item View
struct TabItemView: View {
    let note: NoteItem
    let isActive: Bool
    let index: Int
    let isDark: Bool
    let primaryAccent: Color
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseToRight: () -> Void
    
    @State private var isHovered = false
    
    var iconName: String {
        if note.pptxPath != nil {
            return "sparkles.tv"
        } else if note.pdfPath != nil {
            return "doc.richtext"
        } else if note.audioPath != nil {
            return "waveform"
        } else {
            return "doc.text"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Note Type Icon
            Image(systemName: iconName)
                .font(.system(size: 9, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? primaryAccent : .secondary)
            
            // Note Title
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? (isDark ? .white : .black) : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 110, alignment: .leading)
            
            // Close Tab Button (Shows on hover or active)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isHovered || isActive ? .secondary : .clear)
                    .frame(width: 12, height: 12)
                    .background(isHovered ? Color.primary.opacity(0.12) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close Tab (⌘W)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(Color.cardBackgroundElevated(isDark))
                        .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.06), radius: 2, x: 0, y: 1)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(Color.primary.opacity(0.04))
                }
            }
        )
        .overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 0.8)
                }
            }
        )
        .overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(primaryAccent)
                        .frame(height: 1.5)
                        .padding(.horizontal, 6)
                }
            },
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = inside
            }
        }
        .contextMenu {
            Button("Close Tab") {
                onClose()
            }
            
            Button("Close Other Tabs") {
                onCloseOthers()
            }
            
            Button("Close Tabs to the Right") {
                onCloseToRight()
            }
            
            Divider()
            
            if index < 9 {
                Text("Shortcut: ⌘\(index + 1)")
            }
        }
    }
}
