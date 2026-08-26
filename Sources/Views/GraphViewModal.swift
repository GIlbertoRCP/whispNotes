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
    @State private var basePanOffset: CGSize = .zero
    @State private var searchQuery: String = ""
    @State private var hoveredNodeId: UUID? = nil
    @State private var simulationTimer: Timer? = nil
    @State private var isPhysicsPaused: Bool = false
    @State private var draggedNodeId: UUID? = nil
    @State private var dragInitialNodePos: CGPoint = .zero
    @State private var lastCanvasSize: CGSize = CGSize(width: 720, height: 500)

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
    
    private func getPosition(for noteId: UUID) -> CGPoint {
        if let pos = nodePositions[noteId] {
            return pos
        }
        return CGPoint(x: lastCanvasSize.width / 2.0, y: lastCanvasSize.height / 2.0)
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
                
                // Freeze / Resume Physics Toggle
                Button(action: {
                    isPhysicsPaused.toggle()
                    if isPhysicsPaused {
                        stopSimulation()
                    } else {
                        startSimulation()
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isPhysicsPaused ? Color.emerald.opacity(0.15) : secondaryAccent.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Toggle physics animation / reduced motion")

                // Zoom & Layout Controls
                HStack(spacing: 4) {
                    Button(action: { zoomScale = min(zoomScale + 0.15, 2.5) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { zoomScale = max(zoomScale - 0.15, 0.4) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(Int(zoomScale * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32)
                    
                    Divider().frame(height: 12)
                    
                    Button(action: {
                        rearrangeCircleLayout(canvasSize: lastCanvasSize)
                        startSimulation()
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                            Text("Arrange")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            zoomScale = 1.0
                            panOffset = .zero
                            basePanOffset = .zero
                        }
                    }) {
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
                Button(action: {
                    stopSimulation()
                    isOpen = false
                }) {
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
            if notes.isEmpty {
                WhispEmptyStateView(
                    icon: "circle.hexagonpath",
                    title: "No Notes in Vault",
                    description: "Create notes and connect them using [[WikiLinks]] to explore your interactive knowledge graph.",
                    actionTitle: "Close",
                    action: { isOpen = false }
                )
                .frame(height: 500)
            } else {
                GeometryReader { geo in
                    let canvasSize = geo.size
                    
                    ZStack {
                        // Background Grid & Pan Surface
                        Color.panelBackground(isDark)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if draggedNodeId == nil {
                                            panOffset = CGSize(
                                                width: basePanOffset.width + value.translation.width,
                                                height: basePanOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        basePanOffset = panOffset
                                    }
                            )
                        
                        // Scaled & Panned Content Container
                        ZStack {
                            // Background Blueprint Grid
                            Canvas { context, size in
                                let gridSize: CGFloat = 32.0
                                var path = Path()
                                for x in stride(from: -size.width, to: size.width * 2, by: gridSize) {
                                    path.move(to: CGPoint(x: x, y: -size.height))
                                    path.addLine(to: CGPoint(x: x, y: size.height * 2))
                                }
                                for y in stride(from: -size.height, to: size.height * 2, by: gridSize) {
                                    path.move(to: CGPoint(x: -size.width, y: y))
                                    path.addLine(to: CGPoint(x: size.width * 2, y: y))
                                }
                                context.stroke(path, with: .color(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.04)), lineWidth: 1)
                            }
                            .allowsHitTesting(false)
                            
                            // Connected Edge Lines
                            Canvas { context, size in
                                for edge in edges {
                                    guard let posSrc = nodePositions[edge.sourceId],
                                          let posDst = nodePositions[edge.targetId] else { continue }
                                    
                                    let isHighlighted = hoveredNodeId == edge.sourceId || hoveredNodeId == edge.targetId || selectedNoteId == edge.sourceId || selectedNoteId == edge.targetId
                                    
                                    var path = Path()
                                    path.move(to: posSrc)
                                    path.addLine(to: posDst)
                                    
                                    let strokeColor = isHighlighted ? primaryAccent : secondaryAccent.opacity(0.45)
                                    let lineWidth: CGFloat = isHighlighted ? 2.5 : 1.2
                                    context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)
                                }
                            }
                            .allowsHitTesting(false)
                            
                            // Interactive Draggable Node Pills
                            ForEach(notes) { note in
                                let pos = getPosition(for: note.id)
                                let isSelected = note.id == selectedNoteId
                                let isHovered = note.id == hoveredNodeId
                                let isMatched = searchQuery.isEmpty || note.title.localizedCaseInsensitiveContains(searchQuery)
                                let linkCount = edges.filter { $0.sourceId == note.id || $0.targetId == note.id }.count
                                
                                HStack(spacing: 6) {
                                    if note.audioPath != nil {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 10))
                                            .foregroundColor(isSelected ? .white : primaryAccent)
                                    } else {
                                        Circle()
                                            .fill(isSelected ? .white : (linkCount > 0 ? primaryAccent : secondaryAccent))
                                            .frame(width: 7, height: 7)
                                    }
                                    
                                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                        .font(.system(size: 11.5, weight: isSelected || isHovered ? .bold : .medium))
                                        .foregroundColor(isSelected ? .white : (isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255)))
                                        .lineLimit(1)
                                    
                                    if linkCount > 0 {
                                        Text("\(linkCount)")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(isSelected ? Color.white.opacity(0.25) : primaryAccent.opacity(0.2))
                                            .foregroundColor(isSelected ? .white : primaryAccent)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            isSelected
                                                ? primaryAccent
                                                : (isHovered ? (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)) : Color.cardBackground(isDark))
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? primaryAccent : (isHovered ? primaryAccent.opacity(0.8) : secondaryAccent.opacity(0.4)), lineWidth: isSelected ? 2 : 1)
                                )
                                .shadow(color: isSelected ? primaryAccent.opacity(0.4) : (isHovered ? Color.black.opacity(0.2) : Color.clear), radius: 6, x: 0, y: 2)
                                .opacity(isMatched ? 1.0 : 0.25)
                                .position(x: pos.x, y: pos.y)
                                .onHover { over in
                                    hoveredNodeId = over ? note.id : nil
                                }
                                .onTapGesture {
                                    selectedNoteId = note.id
                                    TabNavigationManager.shared.openNote(note.id)
                                    stopSimulation()
                                    isOpen = false
                                }
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 1)
                                        .onChanged { value in
                                            if draggedNodeId != note.id {
                                                draggedNodeId = note.id
                                                dragInitialNodePos = nodePositions[note.id] ?? pos
                                            }
                                            let newX = dragInitialNodePos.x + value.translation.width / zoomScale
                                            let newY = dragInitialNodePos.y + value.translation.height / zoomScale
                                            nodePositions[note.id] = CGPoint(x: newX, y: newY)
                                            nodeVelocities[note.id] = .zero
                                            
                                            // Wake up simulation while dragging so connected nodes smoothly react
                                            if simulationTimer == nil && !isPhysicsPaused {
                                                startSimulation()
                                            }
                                        }
                                        .onEnded { _ in
                                            draggedNodeId = nil
                                        }
                                )
                            }
                        }
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                    }
                    .clipped()
                    .onAppear {
                        lastCanvasSize = canvasSize
                        initializePositionsIfNeeded(canvasSize: canvasSize)
                        startSimulation()
                    }
                    .onChange(of: geo.size) { _, newSize in
                        lastCanvasSize = newSize
                    }
                }
                .frame(height: 500)
            }
            
            Divider()
                .background(Color.subtleBorder(isDark))

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
                Text("💡 Drag nodes smoothly • Click any note to open • Pan canvas background")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.sidebarBackground(isDark))
        }
        .frame(width: 760, height: 590)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .onDisappear {
            stopSimulation()
        }
    }

    // MARK: - Physics Simulation Engine
    private func startSimulation() {
        guard !isPhysicsPaused else { return }
        stopSimulation()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            stepPhysicsSimulation(canvasSize: lastCanvasSize)
        }
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    private func stepPhysicsSimulation(canvasSize: CGSize) {
        guard !notes.isEmpty && !isPhysicsPaused else { return }
        
        let centerX = canvasSize.width / 2.0
        let centerY = canvasSize.height / 2.0
        let repulsionK: CGFloat = 6500.0
        let springK: CGFloat = 0.04
        let springLength: CGFloat = 100.0
        let gravityK: CGFloat = 0.012
        let damping: CGFloat = 0.86

        var forces: [UUID: CGVector] = [:]
        for note in notes {
            forces[note.id] = .zero
        }

        // 1. Repulsion between all node pairs
        for i in 0..<notes.count {
            let idA = notes[i].id
            guard let posA = nodePositions[idA] else { continue }

            for j in (i + 1)..<notes.count {
                let idB = notes[j].id
                guard let posB = nodePositions[idB] else { continue }

                let dx = posB.x - posA.x
                let dy = posB.y - posA.y
                let distSq = dx * dx + dy * dy
                if distSq > 160000.0 { continue } // Skip nodes further than 400pt
                let dist = max(20.0, sqrt(distSq))
                let forceMagnitude = repulsionK / (dist * dist)

                let fx = (dx / dist) * forceMagnitude
                let fy = (dy / dist) * forceMagnitude

                forces[idA] = CGVector(dx: (forces[idA]?.dx ?? 0) - fx, dy: (forces[idA]?.dy ?? 0) - fy)
                forces[idB] = CGVector(dx: (forces[idB]?.dx ?? 0) + fx, dy: (forces[idB]?.dy ?? 0) + fy)
            }
        }

        // 2. Hooke's Spring attraction along connected edges
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
        var totalKineticEnergy: CGFloat = 0.0
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
            totalKineticEnergy += abs(vel.dx) + abs(vel.dy)

            let newX = max(40.0, min(canvasSize.width - 40.0, pos.x + vel.dx))
            let newY = max(40.0, min(canvasSize.height - 40.0, pos.y + vel.dy))

            nodePositions[id] = CGPoint(x: newX, y: newY)
        }

        // Auto-pause physics when settled to conserve battery/CPU
        if totalKineticEnergy < 0.08 && draggedNodeId == nil {
            stopSimulation()
        }
    }

    private func initializePositionsIfNeeded(canvasSize: CGSize) {
        let radius: CGFloat = min(canvasSize.width, canvasSize.height) * 0.32
        let centerX = canvasSize.width / 2.0
        let centerY = canvasSize.height / 2.0
        for (index, note) in notes.enumerated() {
            if nodePositions[note.id] == nil {
                let angle = (2.0 * .pi / Double(max(1, notes.count))) * Double(index)
                nodePositions[note.id] = CGPoint(x: centerX + radius * CGFloat(cos(angle)), y: centerY + radius * CGFloat(sin(angle)))
                nodeVelocities[note.id] = .zero
            }
        }
    }

    private func rearrangeCircleLayout(canvasSize: CGSize) {
        let radius: CGFloat = min(canvasSize.width, canvasSize.height) * 0.32
        let centerX = canvasSize.width / 2.0
        let centerY = canvasSize.height / 2.0
        for (index, note) in notes.enumerated() {
            let angle = (2.0 * .pi / Double(max(1, notes.count))) * Double(index)
            nodePositions[note.id] = CGPoint(x: centerX + radius * CGFloat(cos(angle)), y: centerY + radius * CGFloat(sin(angle)))
            nodeVelocities[note.id] = .zero
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
