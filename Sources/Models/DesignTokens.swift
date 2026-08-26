import SwiftUI

// MARK: - Core Design Scale Tokens

/// Standardized corner radius tokens across the entire application.
public enum AppRadius {
    /// 6pt - Small elements, badges, pills, buttons, tags
    public static let sm: CGFloat = 6
    /// 10pt - Medium containers, cards, popovers, editor sections
    public static let md: CGFloat = 10
    /// 16pt - Large modals, sheets, floating palettes, canvas cards
    public static let lg: CGFloat = 16
}

/// Standardized 4pt base grid spacing tokens.
public enum AppSpacing {
    /// 4pt - Compact micro-spacing (icons + labels, inline badges)
    public static let xs: CGFloat = 4
    /// 8pt - Standard component internal padding & element gaps
    public static let sm: CGFloat = 8
    /// 12pt - Card padding, section gaps, list item padding
    public static let md: CGFloat = 12
    /// 16pt - Panel margins, modal content padding, container margins
    public static let lg: CGFloat = 16
    /// 24pt - Modal margins, empty state spacing, major section divides
    public static let xl: CGFloat = 24
}

/// Standardized animation curve tokens for consistent fluidity.
public enum AppAnimation {
    /// Micro interactions: button presses, tab switches, badge hovers (0.16s easeOut)
    public static let micro = Animation.easeOut(duration: 0.16)
    
    /// Panel transitions: sidebar toggle, transcript collapse, accordion expand (spring)
    public static let panel = Animation.spring(response: 0.28, dampingFraction: 0.82)
    
    /// Theme and color transitions (0.22s easeInOut)
    public static let theme = Animation.easeInOut(duration: 0.22)
    
    /// Modal sheets and dialogs presentation
    public static let modal = Animation.spring(response: 0.32, dampingFraction: 0.85)
}

/// Standardized shadow elevations.
public enum AppShadow {
    /// Floating Low: For popovers, dropdowns, autocomplete chips, active badges
    public static func floatingLow<V: View>(content: V, color: Color = Color.black.opacity(0.18)) -> some View {
        content.shadow(color: color, radius: 6, x: 0, y: 3)
    }
    
    /// Floating High: For modals, sheets, command palettes, search dialogs
    public static func floatingHigh<V: View>(content: V, color: Color = Color.black.opacity(0.35)) -> some View {
        content.shadow(color: color, radius: 20, x: 0, y: 10)
    }
}

// MARK: - View Extension Helpers
extension View {
    public func appRadius(_ radius: CGFloat) -> some View {
        self.cornerRadius(radius)
    }
    
    public func appBorder(_ color: Color, radius: CGFloat = AppRadius.sm, width: CGFloat = 1) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(color, lineWidth: width)
        )
    }
    
    public func appShadowLow(color: Color = Color.black.opacity(0.18)) -> some View {
        self.shadow(color: color, radius: 6, x: 0, y: 3)
    }
    
    public func appShadowHigh(color: Color = Color.black.opacity(0.35)) -> some View {
        self.shadow(color: color, radius: 20, x: 0, y: 10)
    }
    
    /// Reusable macOS interactive row hover modifier
    public func macHoverRow(isDark: Bool = true) -> some View {
        self.modifier(MacHoverRowModifier(isDark: isDark))
    }
    
    /// Reusable macOS card hover modifier
    public func macHoverCard(radius: CGFloat = AppRadius.sm, isDark: Bool = true) -> some View {
        self.modifier(MacHoverCardModifier(radius: radius, isDark: isDark))
    }
}

// MARK: - Custom Hover Modifiers
private struct MacHoverRowModifier: ViewModifier {
    let isDark: Bool
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(isHovered ? (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)) : Color.clear)
            )
            .onHover { hovering in
                withAnimation(AppAnimation.micro) {
                    isHovered = hovering
                }
            }
    }
}

private struct MacHoverCardModifier: ViewModifier {
    let radius: CGFloat
    let isDark: Bool
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(isHovered ? (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(isHovered ? (isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)) : Color.clear, lineWidth: 1)
            )
            .onHover { hovering in
                withAnimation(AppAnimation.micro) {
                    isHovered = hovering
                }
            }
    }
}
