import Foundation

// MARK: - Graph Canvas Models
struct GraphNode: Identifiable {
    let id: UUID
    let title: String
    let x: CGFloat
    let y: CGFloat
}

struct GraphEdge: Identifiable {
    let id = UUID()
    let sourceId: UUID
    let targetId: UUID
}
