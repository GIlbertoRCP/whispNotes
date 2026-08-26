import Foundation
import SwiftUI
import Combine

// MARK: - Tab & Navigation State Engine
public class TabNavigationManager: ObservableObject {
    public static let shared = TabNavigationManager()
    
    @Published public var openTabIds: [UUID] = []
    @Published public var activeTabId: UUID? = nil
    
    @Published public var historyStack: [UUID] = []
    @Published public var historyIndex: Int = -1
    
    private var isNavigatingHistory = false
    
    public var canGoBack: Bool {
        historyIndex > 0
    }
    
    public var canGoForward: Bool {
        historyIndex >= 0 && historyIndex < historyStack.count - 1
    }
    
    private init() {}
    
    // MARK: - Tab Management
    public func openNote(_ id: UUID, inNewTab: Bool = false) {
        if openTabIds.isEmpty {
            openTabIds.append(id)
            activeTabId = id
        } else if openTabIds.contains(id) {
            // Already open, activate it
            activeTabId = id
        } else {
            // Open in new tab or append
            openTabIds.append(id)
            activeTabId = id
        }
        
        if !isNavigatingHistory {
            pushHistory(id)
        }
    }
    
    public func closeTab(_ id: UUID) {
        guard let idx = openTabIds.firstIndex(of: id) else { return }
        openTabIds.remove(at: idx)
        
        if activeTabId == id {
            if !openTabIds.isEmpty {
                let nextIdx = min(idx, openTabIds.count - 1)
                let nextId = openTabIds[nextIdx]
                activeTabId = nextId
                if !isNavigatingHistory {
                    pushHistory(nextId)
                }
            } else {
                activeTabId = nil
            }
        }
    }
    
    public func closeOtherTabs(_ id: UUID) {
        openTabIds = [id]
        activeTabId = id
    }
    
    public func closeTabsToRight(_ id: UUID) {
        guard let idx = openTabIds.firstIndex(of: id) else { return }
        openTabIds = Array(openTabIds.prefix(idx + 1))
        if let active = activeTabId, !openTabIds.contains(active) {
            activeTabId = id
        }
    }
    
    public func selectTab(at index: Int) {
        guard index >= 0 && index < openTabIds.count else { return }
        let id = openTabIds[index]
        activeTabId = id
        if !isNavigatingHistory {
            pushHistory(id)
        }
    }
    
    public func nextTab() {
        guard !openTabIds.isEmpty, let active = activeTabId, let idx = openTabIds.firstIndex(of: active) else { return }
        let nextIdx = (idx + 1) % openTabIds.count
        selectTab(at: nextIdx)
    }
    
    public func previousTab() {
        guard !openTabIds.isEmpty, let active = activeTabId, let idx = openTabIds.firstIndex(of: active) else { return }
        let prevIdx = (idx - 1 + openTabIds.count) % openTabIds.count
        selectTab(at: prevIdx)
    }
    
    // MARK: - History Navigation
    public func goBack() {
        guard canGoBack else { return }
        isNavigatingHistory = true
        historyIndex -= 1
        let targetId = historyStack[historyIndex]
        
        if !openTabIds.contains(targetId) {
            openTabIds.append(targetId)
        }
        activeTabId = targetId
        isNavigatingHistory = false
    }
    
    public func goForward() {
        guard canGoForward else { return }
        isNavigatingHistory = true
        historyIndex += 1
        let targetId = historyStack[historyIndex]
        
        if !openTabIds.contains(targetId) {
            openTabIds.append(targetId)
        }
        activeTabId = targetId
        isNavigatingHistory = false
    }
    
    func recentHistoryNotes(from allNotes: [NoteItem]) -> [NoteItem] {
        var results: [NoteItem] = []
        for id in historyStack.reversed() {
            if let note = allNotes.first(where: { $0.id == id }), !results.contains(where: { $0.id == id }) {
                results.append(note)
            }
        }
        return results
    }
    
    private func pushHistory(_ id: UUID) {
        if historyIndex >= 0 && historyIndex < historyStack.count {
            if historyStack[historyIndex] != id {
                historyStack = Array(historyStack.prefix(historyIndex + 1))
                historyStack.append(id)
                historyIndex = historyStack.count - 1
            }
        } else {
            historyStack.append(id)
            historyIndex = 0
        }
    }
}
