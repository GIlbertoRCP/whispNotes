import SwiftUI

// MARK: - Obsidian-Style Force-Directed Graph View Canvas
struct GraphViewModal: View {
    let notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @Binding var isOpen: Bool
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var nodeVelocities: [UUID: CGVector] = [:]
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var searchQuery: String = ""
    @State private var hoveredNodeId: UUID? = nil
    @State private var simulationTimer: Timer? = nil
    @State private var isPhysicsPaused: Bool = false
    @State private var draggedNodeId: UUID? = nil
    @State private var dragInitialPos: CGPoint = .zero
    @State private var basePanOffset: CGSize = .zero

    var edges: [GraphEdge] {
        var result: [GraphEdge] = []
        for note in notes {
            let outgoing = parseOutgoingWikiLinks(note.content)
            for targetTitle in outgoing {
                if let targetNote = notes.first(where: { $0.title.caseInsensitiveCompare(targetTitle) == .orderedSame }) {
                    result.append(GraphEdge(sourceId: note.id, targetId: targetNote.id))
                }
            }
        }
        return result
    }
    
    private func getPosition(for noteId: UUID, totalCount: Int, index: Int, canvasSize: CGSize) -> CGPoint {
        if let pos = nodePositions[noteId] {
            return pos
        }
        let radius: CGFloat = min(canvasSize.width, canvasSize.height) * 0.3
        let centerX = canvasSize.width / 2.0
        let centerY = canvasSize.height / 2.0
        let angle = (2.0 * .pi / Double(max(1, totalCount))) * Double(index)
        return CGPoint(x: centerX + radius * CGFloat(cos(angle)), y: centerY + radius * CGFloat(sin(angle)))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Controls
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.hexagonpath")
                        .font(.title2)
                        .foregroundColor(primaryAccent)
                    Text("KNOWLEDGE GRAPH CANVAS")
                        .font(.headline)
                        .fontWeight(.heavy)
                }
                
                Spacer()
                
                // Search Filter
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Filter nodes...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .frame(width: 110)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.panelBackground(isDark))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.subtleBorder(isDark), lineWidth: 1))
                
                // Freeze Physics Toggle Button
                Button(action: {
                    isPhysicsPaused.toggle()
                    if isPhysicsPaused {
                        simulationTimer?.invalidate()
                        simulationTimer = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isPhysicsPaused ? "play.fill" : "pause.fill")
                            .font(.caption2)
                            .foregroundColor(isPhysicsPaused ? .emerald : secondaryAccent)
                        Text(isPhysicsPaused ? "Resume" : "Freeze")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isPhysicsPaused ? .emerald : secondaryAccent)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(isPhysicsPaused ? Color.emerald.opacity(0.15) : secondaryAccent.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Toggle physics animation / reduced motion")

                // Zoom & Physics Controls
                HStack(spacing: 4) {
                    Button(action: { zoomScale = min(zoomScale + 0.2, 2.5) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { zoomScale = max(zoomScale - 0.2, 0.5) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { stepPhysicsSimulation(canvasSize: CGSize(width: 600, height: 450)) }) {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                            Text("Arrange")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)

                    Button(action: { zoomScale = 1.0; panOffset = .zero }) {
                        Text("Reset")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.panelBackground(isDark))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.subtleBorder(isDark), lineWidth: 1))
                
                // Close Button
                Button(action: { isOpen = false }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.sidebarBackground(isDark))

            Divider()
                .background(Color.subtleBorder(isDark))

            // Main Interactive Canvas
            GeometryReader { geo in
                let canvasSize = geo.size
                
                ZStack {
                    Color.panelBackground(isDark)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    panOffset = CGSize(
                                        width: basePanOffset.width + value.translation.width,
                                        height: basePanOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    basePanOffset = panOffset
                                }
                        )
                    
                    // Background Blueprint Grid
                    Canvas { context, size in
                        let gridSize: CGFloat = 30.0
                        var path = Path()
                        for x in stride(from: 0, to: size.width, by: gridSize) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for y in stride(from: 0, to: size.height, by: gridSize) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(path, with: .color(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.04)), lineWidth: 1)
                    }
                    .allowsHitTesting(false)
                    
                    // Connected Edge Lines
                    Canvas { context, size in
                        for edge in edges {
                            if let srcNote = notes.first(where: { $0.id == edge.sourceId }),
                               let dstNote = notes.first(where: { $0.id == edge.targetId }),
                               let srcIdx = notes.firstIndex(where: { $0.id == edge.sourceId }),
                               let dstIdx = notes.firstIndex(where: { $0.id == edge.targetId }) {
                                
                                let srcPos = getPosition(for: srcNote.id, totalCount: notes.count, index: srcIdx, canvasSize: size)
                                let dstPos = getPosition(for: dstNote.id, totalCount: notes.count, index: dstIdx, canvasSize: size)
                                
                                let isHighlighted = hoveredNodeId == edge.sourceId || hoveredNodeId == edge.targetId || selectedNoteId == edge.sourceId || selectedNoteId == edge.targetId
                                
                                var path = Path()
                                path.move(to: srcPos)
                                path.addLine(to: dstPos)
                                
                                let strokeColor = isHighlighted ? primaryAccent : secondaryAccent.opacity(0.4)
                                let lineWidth: CGFloat = isHighlighted ? 3.0 : 1.5
                                context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    
                    // Interactive Node Pills
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        let pos = getPosition(for: note.id, totalCount: notes.count, index: index, canvasSize: canvasSize)
                        let isSelected = note.id == selectedNoteId
                        let isHovered = note.id == hoveredNodeId
                        let isMatched = searchQuery.isEmpty || note.title.localizedCaseInsensitiveContains(searchQuery)
                        let linkCount = edges.filter { $0.sourceId == note.id || $0.targetId == note.id }.count
                        
                        HStack(spacing: 6) {
                            if note.audioPath != nil {
                                Image(systemName: "waveform")
                                    .font(.system(size: 10))
                                    .foregroundColor(primaryAccent)
                            } else {
                                Circle()
                                    .fill(isSelected ? primaryAccent : secondaryAccent)
                                    .frame(width: 8, height: 8)
                            }
                            
                            Text(note.title)
                                .font(.caption)
                                .fontWeight(isSelected || isHovered ? .bold : .medium)
                            
                            if linkCount > 0 {
                                Text("\(linkCount)")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(primaryAccent.opacity(0.2))
                                    .foregroundColor(primaryAccent)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? primaryAccent.opacity(0.2) : Color.cardBackground(isDark))
                        .foregroundColor(isSelected ? primaryAccent : (isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255)))
                        .cornerRadius(14)
                        .opacity(isMatched ? 1.0 : 0.3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? primaryAccent : (isHovered ? primaryAccent.opacity(0.7) : secondaryAccent.opacity(0.4)), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? primaryAccent.opacity(0.4) : Color.clear, radius: 8)
                        .position(x: pos.x, y: pos.y)
                        .onHover { over in
                            hoveredNodeId = over ? note.id : nil
                        }
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    if draggedNodeId != note.id {
                                        draggedNodeId = note.id
                                        dragInitialPos = getPosition(for: note.id, totalCount: notes.count, index: index, canvasSize: canvasSize)
                                    }
                                    let newX = dragInitialPos.x + value.translation.width / zoomScale
                                    let newY = dragInitialPos.y + value.translation.height / zoomScale
                                    nodePositions[note.id] = CGPoint(x: newX, y: newY)
                                    nodeVelocities[note.id] = .zero
                                }
                                .onEnded { value in
                                    if hypot(value.translation.width, value.translation.height) < 5 {
                                        selectedNoteId = note.id
                                        isOpen = false
                                    }
                                    draggedNodeId = nil
                                }
                        )
                    }
                }
                .scaleEffect(zoomScale)
                .offset(panOffset)
                .onAppear {
                    runInitialPhysicsSimulation(canvasSize: canvasSize)
                }
            }
            .frame(height: 480)
            
            // Footer Stats Bar
            HStack {
                Text("\(notes.count) Notes")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text("\(edges.count) Connections")
                    .font(.caption2)
                    .foregroundColor(primaryAccent)
                Spacer()
                Text("💡 Force-directed layout active • Drag nodes to reposition")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.sidebarBackground(isDark))
        }
        .frame(width: 640, height: 570)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
    }

    /// Force-Directed Physics Engine Iteration
    private func stepPhysicsSimulation(canvasSize: CGSize) {
        guard !notes.isEmpty && !isPhysicsPaused else { return }
        
        let centerX = canvasSize.width / 2.0
        let centerY = canvasSize.height / 2.0
        let repulsionK: CGFloat = 8000.0
        let springK: CGFloat = 0.04
        let springLength: CGFloat = 110.0
        let gravityK: CGFloat = 0.015
        let damping: CGFloat = 0.85

        var forces: [UUID: CGVector] = [:]
        for note in notes {
            forces[note.id] = .zero
        }

        // 1. Repulsion forces between all node pairs
        for i in 0..<notes.count {
            let idA = notes[i].id
            guard let posA = nodePositions[idA] else { continue }

            for j in (i + 1)..<notes.count {
                let idB = notes[j].id
                guard let posB = nodePositions[idB] else { continue }

                let dx = posB.x - posA.x
                let dy = posB.y - posA.y
                let distSq = dx * dx + dy * dy
                if distSq > 122500.0 { continue } // Skip nodes further than 350pt
                let dist = max(15.0, sqrt(distSq))
                let forceMagnitude = repulsionK / (dist * dist)

                let fx = (dx / dist) * forceMagnitude
                let fy = (dy / dist) * forceMagnitude

                forces[idA] = CGVector(dx: (forces[idA]?.dx ?? 0) - fx, dy: (forces[idA]?.dy ?? 0) - fy)
                forces[idB] = CGVector(dx: (forces[idB]?.dx ?? 0) + fx, dy: (forces[idB]?.dy ?? 0) + fy)
            }
        }

        // 2. Hooke's Spring attraction forces along connected edges
        for edge in edges {
            guard let posSrc = nodePositions[edge.sourceId],
                  let posDst = nodePositions[edge.targetId] else { continue }

            let dx = posDst.x - posSrc.x
            let dy = posDst.y - posSrc.y
            let dist = max(1.0, sqrt(dx * dx + dy * dy))
            let delta = dist - springLength
            let forceMagnitude = delta * springK

            let fx = (dx / dist) * forceMagnitude
            let fy = (dy / dist) * forceMagnitude

            forces[edge.sourceId] = CGVector(dx: (forces[edge.sourceId]?.dx ?? 0) + fx, dy: (forces[edge.sourceId]?.dy ?? 0) + fy)
            forces[edge.targetId] = CGVector(dx: (forces[edge.targetId]?.dx ?? 0) - fx, dy: (forces[edge.targetId]?.dy ?? 0) - fy)
        }

        // 3. Center gravity & Velocity update
        for note in notes {
            let id = note.id
            if id == draggedNodeId { continue }
            guard let pos = nodePositions[id] else { continue }

            let gx = (centerX - pos.x) * gravityK
            let gy = (centerY - pos.y) * gravityK

            let totalFx = (forces[id]?.dx ?? 0) + gx
            let totalFy = (forces[id]?.dy ?? 0) + gy

            var vel = nodeVelocities[id] ?? .zero
            vel.dx = (vel.dx + totalFx) * damping
            vel.dy = (vel.dy + totalFy) * damping

            nodeVelocities[id] = vel

            let newX = max(40.0, min(canvasSize.width - 40.0, pos.x + vel.dx))
            let newY = max(40.0, min(canvasSize.height - 40.0, pos.y + vel.dy))

            nodePositions[id] = CGPoint(x: newX, y: newY)
        }
    }

    private func runInitialPhysicsSimulation(canvasSize: CGSize) {
        let radius: CGFloat = min(canvasSize.width, canvasSize.height) * 0.3
        let centerX = canvasSize.width / 2.0
        let centerY = canvasSize.height / 2.0
        for (index, note) in notes.enumerated() {
            if nodePositions[note.id] == nil {
                let angle = (2.0 * .pi / Double(max(1, notes.count))) * Double(index)
                nodePositions[note.id] = CGPoint(x: centerX + radius * CGFloat(cos(angle)), y: centerY + radius * CGFloat(sin(angle)))
                nodeVelocities[note.id] = .zero
            }
        }
        for _ in 0..<20 {
            stepPhysicsSimulation(canvasSize: canvasSize)
        }
    }
    
    private func parseOutgoingWikiLinks(_ text: String) -> [String] {
        let pattern = "\\[\\[(.*?)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        var links: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                links.append(String(text[range]))
            }
        }
        return links
    }
}
