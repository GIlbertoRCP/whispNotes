import SwiftUI
import Combine

// MARK: - Obsidian-Style Global GUI Zoom Manager
public final class ZoomManager: ObservableObject {
    public static let shared = ZoomManager()
    
    private let zoomKey = "appZoomScale"
    
    @Published public var scale: Double {
        didSet {
            UserDefaults.standard.set(scale, forKey: zoomKey)
            triggerHUD()
        }
    }
    
    @Published public var showHUD: Bool = false
    private var hudDismissWorkItem: DispatchWorkItem?
    
    public let minScale: Double = 0.70
    public let maxScale: Double = 1.80
    public let step: Double = 0.10
    
    public var percentageString: String {
        "\(Int(round(scale * 100)))%"
    }
    
    private init() {
        let saved = UserDefaults.standard.double(forKey: zoomKey)
        if saved >= 0.70 && saved <= 1.80 {
            self.scale = saved
        } else {
            self.scale = 1.0
        }
    }
    
    public func zoomIn() {
        let newScale = min(maxScale, (scale + step).rounded(toPlaces: 2))
        withAnimation(.easeOut(duration: 0.16)) {
            scale = newScale
        }
    }
    
    public func zoomOut() {
        let newScale = max(minScale, (scale - step).rounded(toPlaces: 2))
        withAnimation(.easeOut(duration: 0.16)) {
            scale = newScale
        }
    }
    
    public func resetZoom() {
        withAnimation(.easeOut(duration: 0.16)) {
            scale = 1.0
        }
    }
    
    private func triggerHUD() {
        hudDismissWorkItem?.cancel()
        withAnimation(.easeOut(duration: 0.14)) {
            showHUD = true
        }
        let workItem = DispatchWorkItem { [weak self] in
            withAnimation(.easeIn(duration: 0.22)) {
                self?.showHUD = false
            }
        }
        hudDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
