import SwiftUI

// MARK: - Zoom Container View
/// Wraps application content and scales the entire interface cleanly based on ZoomManager scale factor.
public struct ZoomContainerView<Content: View>: View {
    @ObservedObject private var zoomManager = ZoomManager.shared
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let scale = CGFloat(zoomManager.scale)
            let scaledWidth = max(100, proxy.size.width / scale)
            let scaledHeight = max(100, proxy.size.height / scale)
            
            ZStack(alignment: .topLeading) {
                if abs(scale - 1.0) < 0.001 {
                    content
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    content
                        .frame(width: scaledWidth, height: scaledHeight)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                        .clipped()
                }
                
                // Floating Obsidian-Style Zoom HUD Pill
                if zoomManager.showHUD {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 7) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Zoom: \(zoomManager.percentageString)")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(AppRadius.xl)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 5)
                            .padding(24)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .environment(\.windowContentSize, proxy.size)
        }
    }
}
