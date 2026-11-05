import SwiftUI
import AppKit

// MARK: - Graph Layout Model
//
// Layout and physics live outside SwiftUI state: links are parsed once, positions sit in plain arrays,
// and each tick bumps a single counter that redraws one Canvas. The previous version re-parsed every
// note's text several times per frame and rebuilt every node view 60 times a second.
@MainActor
final class GraphLayoutModel: ObservableObject {
    struct Node {
        let id: UUID
        let title: String
        let hasAudio: Bool
        var degree: Int
        var position: CGPoint
        var velocity: CGVector = .zero
        /// Pill size in world points.
        var size: CGSize
        var isFixed = false
    }

    struct Link {
        let a: Int
        let b: Int
    }

    /// Bumped whenever something visible changes; the canvas reads it to redraw.
    @Published private(set) var frame = 0
    @Published private(set) var isRunning = false

    private(set) var nodes: [Node] = []
    private(set) var links: [Link] = []
    private(set) var neighbors: [Set<Int>] = []

    // Camera: screen = world * scale + translation
    private(set) var scale: CGFloat = 1
    private(set) var translation: CGPoint = .zero
    private var cameraTarget: (scale: CGFloat, translation: CGPoint)?
    private(set) var canvasSize: CGSize = .zero

    static let minScale: CGFloat = 0.2
    static let maxScale: CGFloat = 2.5
    /// Below this zoom, nodes draw as dots and only highlighted ones keep their labels.
    static let labelScale: CGFloat = 0.55

    private var alpha: CGFloat = 1
    private var alphaTarget: CGFloat = 0
    private var timer: Timer?
    private var hasAutoFitted = false
    private var grabOffset: CGVector = .zero
    private var draggingIndex: Int?

    var isPaused = false {
        didSet {
            if isPaused { stop() } else { reheat(0.5) }
        }
    }

    // MARK: Loading

    static let pillHeight: CGFloat = 26
    private static let titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private static let badgeFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
    // [[Title]], [[Title|alias]], [[Title#heading]]
    private static let wikiLink = try! NSRegularExpression(pattern: #"\[\[([^\]\|#\n]+)(?:[#|][^\]\n]*)?\]\]"#)

    static func displayTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled Note" }
        return trimmed.count > 42 ? String(trimmed.prefix(40)) + "…" : trimmed
    }

    static func pillSize(title: String, degree: Int) -> CGSize {
        let textWidth = ceil((title as NSString).size(withAttributes: [.font: titleFont]).width)
        var width = 10 + 8 + 6 + textWidth + 10
        if degree > 0 {
            width += 6 + badgeWidth(degree)
        }
        return CGSize(width: width, height: pillHeight)
    }

    static func badgeWidth(_ degree: Int) -> CGFloat {
        ceil(("\(degree)" as NSString).size(withAttributes: [.font: badgeFont]).width) + 8
    }

    /// Builds nodes and links from the vault. Keeps the positions of nodes that were already laid out.
    func load(notes: [NoteItem], hideUnlinked: Bool) {
        let live = notes.filter { $0.folder != "Trash" }

        var indexByTitle: [String: Int] = [:]
        for (i, note) in live.enumerated() {
            let key = note.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !key.isEmpty, indexByTitle[key] == nil { indexByTitle[key] = i }
        }

        // Parse each note's links exactly once.
        var pairs = Set<[Int]>()
        for (i, note) in live.enumerated() where note.content.contains("[[") {
            let text = note.content as NSString
            for match in Self.wikiLink.matches(in: note.content, range: NSRange(location: 0, length: text.length)) {
                let target = text.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces).lowercased()
                guard let j = indexByTitle[target], j != i else { continue }
                pairs.insert([min(i, j), max(i, j)])
            }
        }

        var degree = Array(repeating: 0, count: live.count)
        for p in pairs { degree[p[0]] += 1; degree[p[1]] += 1 }

        let keep = live.indices.filter { !hideUnlinked || degree[$0] > 0 }
        var newIndex: [Int: Int] = [:]
        for (n, old) in keep.enumerated() { newIndex[old] = n }

        let previous = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.position) })
        nodes = keep.enumerated().map { n, i in
            let note = live[i]
            let title = Self.displayTitle(note.title)
            // Phyllotaxis seed: even spread, deterministic, no two nodes on the same spot.
            let r = 34 * sqrt(CGFloat(n) + 0.5)
            let angle = CGFloat(n) * 2.399963
            return Node(
                id: note.id,
                title: title,
                hasAudio: note.audioPath != nil,
                degree: degree[i],
                position: previous[note.id] ?? CGPoint(x: r * cos(angle), y: r * sin(angle)),
                size: Self.pillSize(title: title, degree: degree[i])
            )
        }
        links = pairs.compactMap { p in
            guard let a = newIndex[p[0]], let b = newIndex[p[1]] else { return nil }
            return Link(a: a, b: b)
        }
        neighbors = Array(repeating: [], count: nodes.count)
        for l in links { neighbors[l.a].insert(l.b); neighbors[l.b].insert(l.a) }

        hasAutoFitted = false
        reheat(1)
    }

    // MARK: Camera

    func setCanvasSize(_ size: CGSize) {
        let first = canvasSize == .zero
        canvasSize = size
        if first { translation = CGPoint(x: size.width / 2, y: size.height / 2) }
        redraw()
    }

    func toScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * scale + translation.x, y: p.y * scale + translation.y)
    }

    func toWorld(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - translation.x) / scale, y: (p.y - translation.y) / scale)
    }

    func pan(to newTranslation: CGPoint) {
        cameraTarget = nil
        translation = newTranslation
        redraw()
    }

    /// Zooms keeping the world point under `focus` (screen coordinates) still.
    func zoom(to newScale: CGFloat, around focus: CGPoint? = nil) {
        cameraTarget = nil
        let clamped = min(Self.maxScale, max(Self.minScale, newScale))
        let f = focus ?? CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        translation = CGPoint(
            x: f.x - (f.x - translation.x) * (clamped / scale),
            y: f.y - (f.y - translation.y) * (clamped / scale)
        )
        scale = clamped
        redraw()
    }

    /// Frames every node; animated over a few frames when `animated`.
    func fitToView(animated: Bool = true) {
        guard !nodes.isEmpty, canvasSize.width > 0 else { return }
        var bounds = CGRect.null
        for n in nodes {
            bounds = bounds.union(CGRect(x: n.position.x - n.size.width / 2, y: n.position.y - n.size.height / 2,
                                         width: n.size.width, height: n.size.height))
        }
        let margin: CGFloat = 48
        let s = min(Self.maxScale, max(Self.minScale, min(
            (canvasSize.width - margin * 2) / max(bounds.width, 1),
            (canvasSize.height - margin * 2) / max(bounds.height, 1),
            1.4
        )))
        let t = CGPoint(x: canvasSize.width / 2 - bounds.midX * s, y: canvasSize.height / 2 - bounds.midY * s)
        if animated {
            cameraTarget = (s, t)
            startTimerIfNeeded()
        } else {
            scale = s
            translation = t
            redraw()
        }
    }

    // MARK: Interaction

    func hitTest(_ screenPoint: CGPoint) -> Int? {
        let p = toWorld(screenPoint)
        let showsPills = scale >= Self.labelScale
        for i in nodes.indices.reversed() {
            let n = nodes[i]
            if showsPills {
                let rect = CGRect(x: n.position.x - n.size.width / 2, y: n.position.y - n.size.height / 2,
                                  width: n.size.width, height: n.size.height)
                if rect.contains(p) { return i }
            } else {
                let r = 9 / scale
                if hypot(p.x - n.position.x, p.y - n.position.y) <= r { return i }
            }
        }
        return nil
    }

    func beginDrag(_ i: Int, at screenPoint: CGPoint) {
        let p = toWorld(screenPoint)
        grabOffset = CGVector(dx: p.x - nodes[i].position.x, dy: p.y - nodes[i].position.y)
        draggingIndex = i
        nodes[i].isFixed = true
    }

    func drag(_ i: Int, to screenPoint: CGPoint) {
        let p = toWorld(screenPoint)
        nodes[i].position = CGPoint(x: p.x - grabOffset.dx, y: p.y - grabOffset.dy)
        nodes[i].velocity = .zero
        if !isPaused {
            alphaTarget = 0.3
            reheat(max(alpha, 0.3))
        } else {
            redraw()
        }
    }

    func endDrag(_ i: Int) {
        if nodes.indices.contains(i) { nodes[i].isFixed = false }
        draggingIndex = nil
        alphaTarget = 0
    }

    /// Restarts the layout from a fresh spread.
    func relayout() {
        for n in nodes.indices {
            let r = 34 * sqrt(CGFloat(n) + 0.5)
            let angle = CGFloat(n) * 2.399963
            nodes[n].position = CGPoint(x: r * cos(angle), y: r * sin(angle))
            nodes[n].velocity = .zero
        }
        hasAutoFitted = false
        if isPaused { isPaused = false } else { reheat(1) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func reheat(_ value: CGFloat) {
        guard !isPaused else { redraw(); return }
        alpha = max(alpha, value)
        startTimerIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // .common keeps the layout moving while a drag or menu is tracking.
        RunLoop.main.add(t, forMode: .common)
        timer = t
        isRunning = true
    }

    private func redraw() { frame &+= 1 }

    // MARK: Physics (velocity Verlet with cooling, after d3-force)

    private func tick() {
        let physicsActive = !isPaused && alpha > 0.003
        if physicsActive { stepPhysics() }

        if let target = cameraTarget {
            scale += (target.scale - scale) * 0.18
            translation.x += (target.translation.x - translation.x) * 0.18
            translation.y += (target.translation.y - translation.y) * 0.18
            if abs(target.scale - scale) < 0.002 && hypot(target.translation.x - translation.x, target.translation.y - translation.y) < 0.5 {
                scale = target.scale
                translation = target.translation
                cameraTarget = nil
            }
        }

        // Frame the graph once it has mostly settled after opening or re-layout.
        if !hasAutoFitted && alpha < 0.12 && draggingIndex == nil {
            hasAutoFitted = true
            fitToView()
        }

        redraw()
        if !physicsActive && cameraTarget == nil && draggingIndex == nil { stop() }
    }

    private func stepPhysics() {
        let n = nodes.count
        guard n > 0 else { return }
        alpha += (alphaTarget - alpha) * 0.025

        var px = nodes.map { $0.position.x }, py = nodes.map { $0.position.y }
        var vx = nodes.map { $0.velocity.dx }, vy = nodes.map { $0.velocity.dy }
        let w = nodes.map { $0.size.width }, h = nodes.map { $0.size.height }
        let fixed = nodes.map { $0.isFixed }

        // Many-body repulsion + rectangle collision (labels never overlap once settled).
        let charge: CGFloat = -520
        let cutoffSq: CGFloat = 900 * 900
        for i in 0..<n {
            for j in (i + 1)..<n {
                var dx = px[j] - px[i], dy = py[j] - py[i]
                if dx == 0 && dy == 0 { dx = CGFloat.random(in: -1...1); dy = CGFloat.random(in: -1...1) }
                let distSq = dx * dx + dy * dy
                if distSq < cutoffSq {
                    let k = charge * alpha / max(distSq, 36)
                    vx[i] += dx * k; vy[i] += dy * k
                    vx[j] -= dx * k; vy[j] -= dy * k
                }
                let overlapX = (w[i] + w[j]) / 2 + 12 - abs(dx)
                let overlapY = (h[i] + h[j]) / 2 + 10 - abs(dy)
                if overlapX > 0 && overlapY > 0 {
                    // Push apart along the axis that needs the smaller move.
                    if overlapX / max(w[i] + w[j], 1) < overlapY / max(h[i] + h[j], 1) {
                        let push = overlapX * 0.25 * (dx < 0 ? -1 : 1)
                        if !fixed[i] { px[i] -= push }
                        if !fixed[j] { px[j] += push }
                    } else {
                        let push = overlapY * 0.25 * (dy < 0 ? -1 : 1)
                        if !fixed[i] { py[i] -= push }
                        if !fixed[j] { py[j] += push }
                    }
                }
            }
        }

        // Springs along links, sized to the two labels.
        for link in links {
            let a = link.a, b = link.b
            let dx = (px[b] + vx[b]) - (px[a] + vx[a])
            let dy = (py[b] + vy[b]) - (py[a] + vy[a])
            let dist = max(sqrt(dx * dx + dy * dy), 1)
            let rest = (w[a] + w[b]) / 4 + 70
            let da = CGFloat(max(nodes[a].degree, 1)), db = CGFloat(max(nodes[b].degree, 1))
            let strength = 1 / min(da, db)
            let k = (dist - rest) / dist * alpha * strength * 0.7
            let bias = da / (da + db)
            vx[b] -= dx * k * bias; vy[b] -= dy * k * bias
            vx[a] += dx * k * (1 - bias); vy[a] += dy * k * (1 - bias)
        }

        // Gentle pull to the origin keeps unlinked notes from drifting off.
        let gravity: CGFloat = 0.035 * alpha
        for i in 0..<n {
            if fixed[i] { vx[i] = 0; vy[i] = 0; continue }
            vx[i] -= px[i] * gravity
            vy[i] -= py[i] * gravity
            vx[i] *= 0.6
            vy[i] *= 0.6
            px[i] += vx[i]
            py[i] += vy[i]
        }

        for i in 0..<n where !fixed[i] {
            nodes[i].position = CGPoint(x: px[i], y: py[i])
            nodes[i].velocity = CGVector(dx: vx[i], dy: vy[i])
        }
    }
}

// MARK: - Knowledge Graph Sheet
struct GraphViewModal: View {
    let notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @Binding var isOpen: Bool
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color

    @StateObject private var model = GraphLayoutModel()
    @AppStorage("graphHideUnlinked") private var hideUnlinked = false
    @State private var searchQuery = ""
    @State private var hoveredIndex: Int?
    @State private var drag: DragKind?
    @State private var pinchStartScale: CGFloat?

    private enum DragKind {
        case node(Int)
        case pan(start: CGPoint)
    }

    private var searchMatches: Set<Int>? {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }
        return Set(model.nodes.indices.filter { model.nodes[$0].title.localizedCaseInsensitiveContains(q) })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            canvasArea
            Divider()
            footer
        }
        .adaptiveSheetFrame(width: 900, height: 640)
        .background(Color.panelBackground(isDark))
        .onAppear { model.load(notes: notes, hideUnlinked: hideUnlinked) }
        .onChange(of: hideUnlinked) { _, hide in model.load(notes: notes, hideUnlinked: hide) }
        .onDisappear { model.stop() }
        .onExitCommand { close() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "circle.hexagonpath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(primaryAccent)
            Text("Knowledge Graph")
                .font(.headline)

            Spacer(minLength: AppSpacing.sm)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Find a note", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 130)
                    .onSubmit {
                        if let first = searchMatches?.sorted().first { open(first) }
                    }
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color.cardBackground(isDark))
            .cornerRadius(AppRadius.sm)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(Color.subtleBorder(isDark), lineWidth: 1))

            Toggle("Hide unlinked", isOn: $hideUnlinked)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .help("Show only notes that link to or from another note")

            HStack(spacing: 2) {
                graphButton("minus.magnifyingglass", help: "Zoom out") { model.zoom(to: model.scale / 1.25) }
                Text("\(Int((model.scale * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 40)
                graphButton("plus.magnifyingglass", help: "Zoom in") { model.zoom(to: model.scale * 1.25) }
                Divider().frame(height: 14).padding(.horizontal, 2)
                graphButton("arrow.up.left.and.down.right.magnifyingglass", help: "Fit all notes") { model.fitToView() }
                graphButton("arrow.triangle.2.circlepath", help: "Re-run layout") { model.relayout() }
                graphButton(model.isPaused ? "play.fill" : "pause.fill",
                            help: model.isPaused ? "Resume layout motion" : "Freeze layout") { model.isPaused.toggle() }
            }
            .padding(.horizontal, 4)
            .frame(height: 26)
            .background(Color.cardBackground(isDark))
            .cornerRadius(AppRadius.sm)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(Color.subtleBorder(isDark), lineWidth: 1))

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close (Esc)")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(Color.sidebarBackground(isDark))
    }

    private func graphButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.appTextMuted(isDark))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: Canvas

    @ViewBuilder
    private var canvasArea: some View {
        if model.nodes.isEmpty {
            WhispEmptyStateView(
                icon: "circle.hexagonpath",
                title: hideUnlinked ? "No Linked Notes Yet" : "No Notes Yet",
                description: hideUnlinked
                    ? "Link notes by typing [[Note Title]] in one of them, or turn off Hide unlinked."
                    : "Create notes and link them with [[Note Title]] to see how your ideas connect."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geo in
                let _ = model.frame
                Canvas { context, size in
                    draw(in: &context, size: size)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .simultaneousGesture(magnifyGesture)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        let hit = model.hitTest(point)
                        if hit != hoveredIndex { hoveredIndex = hit }
                        (hit == nil ? NSCursor.arrow : NSCursor.pointingHand).set()
                    case .ended:
                        hoveredIndex = nil
                        NSCursor.arrow.set()
                    }
                }
                .onAppear { model.setCanvasSize(geo.size) }
                .onChange(of: geo.size) { _, size in model.setCanvasSize(size) }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Knowledge graph")
                .accessibilityChildren {
                    ForEach(Array(model.nodes.enumerated()), id: \.element.id) { i, node in
                        Button("\(node.title), \(node.degree) links") { open(i) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if drag == nil {
                    if let i = model.hitTest(value.startLocation) {
                        drag = .node(i)
                        model.beginDrag(i, at: value.startLocation)
                    } else {
                        drag = .pan(start: model.translation)
                    }
                }
                switch drag {
                case .node(let i):
                    if hypot(value.translation.width, value.translation.height) > 3 {
                        NSCursor.closedHand.set()
                        model.drag(i, to: value.location)
                    }
                case .pan(let start):
                    model.pan(to: CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height))
                case .none:
                    break
                }
            }
            .onEnded { value in
                if case .node(let i) = drag {
                    model.endDrag(i)
                    // A click (no real movement) opens the note.
                    if hypot(value.translation.width, value.translation.height) <= 3 { open(i) }
                }
                drag = nil
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStartScale ?? model.scale
                if pinchStartScale == nil { pinchStartScale = start }
                model.zoom(to: start * value.magnification, around: value.startLocation)
            }
            .onEnded { _ in pinchStartScale = nil }
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let nodes = model.nodes
        let scale = model.scale
        let t = model.translation
        let selectedIndex = nodes.firstIndex { $0.id == selectedNoteId }

        // Focus: hovering (or searching) highlights a set and dims the rest.
        var focus: Set<Int>? = nil
        if let h = hoveredIndex, nodes.indices.contains(h) {
            focus = model.neighbors[h].union([h])
        } else if let matches = searchMatches {
            focus = matches
        }

        drawGrid(in: &context, size: size, scale: scale, translation: t)

        // Links, batched into two paths.
        var normal = Path(), strong = Path()
        for link in model.links {
            let a = model.toScreen(nodes[link.a].position), b = model.toScreen(nodes[link.b].position)
            let emphasized = link.a == hoveredIndex || link.b == hoveredIndex || link.a == selectedIndex || link.b == selectedIndex
            if emphasized {
                strong.move(to: a); strong.addLine(to: b)
            } else {
                normal.move(to: a); normal.addLine(to: b)
            }
        }
        var linkContext = context
        if focus != nil { linkContext.opacity = 0.35 }
        linkContext.stroke(normal, with: .color(secondaryAccent.opacity(isDark ? 0.4 : 0.5)), lineWidth: 1)
        context.stroke(strong, with: .color(primaryAccent), lineWidth: 1.8)

        let showsPills = scale >= GraphLayoutModel.labelScale
        for (i, node) in nodes.enumerated() {
            let isSelected = i == selectedIndex
            let isHovered = i == hoveredIndex
            let inFocus = focus?.contains(i) ?? true
            var nodeContext = context
            nodeContext.opacity = inFocus ? 1 : 0.22
            let center = model.toScreen(node.position)

            if showsPills || isHovered || isSelected || (searchMatches?.contains(i) ?? false) {
                // Pills keep a readable size at low zoom when they're the thing you're looking at.
                let pillScale = showsPills ? scale : max(scale, 0.8)
                drawPill(node, at: center, scale: pillScale, selected: isSelected, hovered: isHovered, in: &nodeContext)
            } else {
                let r: CGFloat = isSelected ? 6 : 4.5
                let dot = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                nodeContext.fill(dot, with: .color(node.degree > 0 ? primaryAccent : secondaryAccent))
            }
        }
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize, scale: CGFloat, translation: CGPoint) {
        var spacing = 32 * scale
        while spacing < 16 { spacing *= 2 }
        let ox = translation.x.truncatingRemainder(dividingBy: spacing)
        let oy = translation.y.truncatingRemainder(dividingBy: spacing)
        var grid = Path()
        var x = ox
        while x < size.width { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
        var y = oy
        while y < size.height { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
        context.stroke(grid, with: .color(isDark ? Color.white.opacity(0.035) : Color.black.opacity(0.04)), lineWidth: 1)
    }

    private func drawPill(_ node: GraphLayoutModel.Node, at center: CGPoint, scale: CGFloat,
                          selected: Bool, hovered: Bool, in context: inout GraphicsContext) {
        var c = context
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: scale, y: scale)

        let w = node.size.width, h = node.size.height
        let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        let pill = Path(roundedRect: rect, cornerRadius: h / 2)
        let onAccent = Color.onAccent(isDark)

        if selected || hovered {
            var shadow = c
            shadow.addFilter(.shadow(color: Color.black.opacity(isDark ? 0.45 : 0.15), radius: 6, x: 0, y: 2))
            shadow.fill(pill, with: .color(selected ? primaryAccent : Color.cardBackgroundElevated(isDark)))
        } else {
            c.fill(pill, with: .color(Color.cardBackgroundElevated(isDark)))
        }
        c.stroke(pill, with: .color(selected ? primaryAccent : (hovered ? primaryAccent.opacity(0.85) : Color.strongBorder(isDark).opacity(0.6))),
                 lineWidth: (selected ? 1.6 : 1) / scale)

        let iconColor: Color = selected ? onAccent : (node.degree > 0 ? primaryAccent : secondaryAccent)
        let iconCenter = CGPoint(x: rect.minX + 10 + 4, y: 0)
        if node.hasAudio {
            var icon = c.resolve(Image(systemName: "waveform"))
            icon.shading = .color(iconColor)
            c.draw(icon, in: CGRect(x: iconCenter.x - 5, y: -5, width: 10, height: 10))
        } else {
            c.fill(Path(ellipseIn: CGRect(x: iconCenter.x - 3.5, y: -3.5, width: 7, height: 7)), with: .color(iconColor))
        }

        let title = Text(node.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(selected ? onAccent : Color.appText(isDark))
        c.draw(title, at: CGPoint(x: rect.minX + 10 + 8 + 6, y: 0), anchor: .leading)

        if node.degree > 0 {
            let bw = GraphLayoutModel.badgeWidth(node.degree)
            let badgeRect = CGRect(x: rect.maxX - 10 - bw, y: -8, width: bw, height: 16)
            c.fill(Path(roundedRect: badgeRect, cornerRadius: AppRadius.xs),
                   with: .color(selected ? onAccent.opacity(0.18) : primaryAccent.opacity(0.18)))
            let count = Text("\(node.degree)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(selected ? onAccent : primaryAccent)
            c.draw(count, at: CGPoint(x: badgeRect.midX, y: 0), anchor: .center)
        }
    }

    // MARK: Footer & actions

    private var footer: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("\(model.nodes.count) notes · \(model.links.count) links")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundColor(Color.appTextSecondary(isDark))
            if model.isRunning && !model.isPaused {
                ProgressView().controlSize(.mini)
                    .help("Arranging…")
            }
            Spacer()
            Text("Click to open · Drag a note to move it · Drag the background to pan · Pinch to zoom")
                .font(.system(size: 11))
                .foregroundColor(Color.appTextSecondary(isDark))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.sidebarBackground(isDark))
    }

    private func open(_ index: Int) {
        guard model.nodes.indices.contains(index) else { return }
        let id = model.nodes[index].id
        selectedNoteId = id
        TabNavigationManager.shared.openNote(id)
        close()
    }

    private func close() {
        model.stop()
        isOpen = false
    }
}
