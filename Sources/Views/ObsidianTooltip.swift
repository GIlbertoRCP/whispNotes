import SwiftUI

// MARK: - Obsidian-Style Tooltip Arrow Callout Shape
struct TooltipArrowShape: Shape {
    let pointUp: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointUp {
            // Triangle pointing up towards the icon above
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        } else {
            // Triangle pointing down towards the icon below
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Obsidian-Style Tooltip Bubble View
struct ObsidianTooltipBubble: View {
    let text: String
    var shortcut: String? = nil
    var pointUp: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            if pointUp {
                TooltipArrowShape(pointUp: true)
                    .fill(Color(red: 24/255, green: 24/255, blue: 27/255))
                    .frame(width: 8, height: 4)
            }
            
            HStack(spacing: 6) {
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 241/255, green: 245/255, blue: 249/255)) // Slate 100
                    .lineLimit(1)
                
                if let sc = shortcut, !sc.isEmpty {
                    Text(sc)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 148/255, green: 163/255, blue: 184/255)) // Slate 400
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(3)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(Color(red: 24/255, green: 24/255, blue: 27/255)) // Zinc 900
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
            
            if !pointUp {
                TooltipArrowShape(pointUp: false)
                    .fill(Color(red: 24/255, green: 24/255, blue: 27/255))
                    .frame(width: 8, height: 4)
            }
        }
        .fixedSize()
    }
}

// MARK: - Obsidian-Style Tooltip View Modifier
struct ObsidianTooltipModifier: ViewModifier {
    let text: String
    var shortcut: String? = nil
    var edge: VerticalEdge = .bottom
    var delay: Double = 0.25 // 250ms snappy delay
    
    @State private var isHovered = false
    @State private var showTooltip = false
    @State private var hoverWorkItem: DispatchWorkItem?
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
                hoverWorkItem?.cancel()
                
                if hovering {
                    let workItem = DispatchWorkItem {
                        guard self.isHovered else { return }
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                            self.showTooltip = true
                        }
                    }
                    hoverWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                } else {
                    withAnimation(.easeOut(duration: 0.12)) {
                        self.showTooltip = false
                    }
                }
            }
            .overlay(alignment: edge == .bottom ? .bottom : .top) {
                if showTooltip && !text.isEmpty {
                    ObsidianTooltipBubble(
                        text: text,
                        shortcut: shortcut,
                        pointUp: edge == .bottom
                    )
                    .offset(y: edge == .bottom ? 30 : -30)
                    .zIndex(999)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
    }
}

// MARK: - Fluent View Extension
extension View {
    /// Attaches an Obsidian-style floating tooltip with dark bubble, arrow pointer, and optional keyboard shortcut badge.
    func obsidianTooltip(_ text: String, shortcut: String? = nil, edge: VerticalEdge = .bottom) -> some View {
        self.modifier(ObsidianTooltipModifier(text: text, shortcut: shortcut, edge: edge))
    }
}
