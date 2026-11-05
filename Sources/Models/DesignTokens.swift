import SwiftUI

// MARK: - Core Design Scale Tokens

/// Standardized corner radius tokens across the entire application.
/// Every rounded shape picks one of these; nesting goes one step down per level.
public enum AppRadius {
    /// 4pt - Badges, keycaps, inline chips, tags
    public static let xs: CGFloat = 4
    /// 6pt - Rows, small buttons, text fields
    public static let sm: CGFloat = 6
    /// 8pt - Buttons, popovers, code blocks, callouts
    public static let md: CGFloat = 8
    /// 12pt - Cards, panels, editor sections
    public static let lg: CGFloat = 12
    /// 16pt - Modals, sheets, floating palettes
    public static let xl: CGFloat = 16
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

/// Standardized typography scale tokens for optimal legibility and visual hierarchy.
public enum AppTypography {
    /// Large display title (26pt bold)
    public static let display = Font.system(size: 26, weight: .bold)
    /// Document / Modal title (20pt bold)
    public static let title = Font.system(size: 20, weight: .bold)
    /// Markdown Heading 1 (22pt bold)
    public static let h1 = Font.system(size: 22, weight: .bold)
    /// Markdown Heading 2 (17pt semibold)
    public static let h2 = Font.system(size: 17, weight: .semibold)
    /// Markdown Heading 3 (15pt medium)
    public static let h3 = Font.system(size: 15, weight: .medium)
    /// Markdown Heading 4 (13pt semibold)
    public static let h4 = Font.system(size: 13, weight: .semibold)
    /// Body text (14pt regular, comfortable reading scale)
    public static let body = Font.system(size: 14, weight: .regular)
    /// Small body / Callout (13pt regular)
    public static let callout = Font.system(size: 13, weight: .regular)
    /// Caption / Secondary metadata (11pt medium)
    public static let caption = Font.system(size: 11, weight: .medium)
    /// Micro badge / Keyboard shortcut (9.5pt bold, monospaced)
    public static let microBadge = Font.system(size: 10, weight: .bold, design: .monospaced)
    /// Inline and block code font (13pt monospaced)
    public static let code = Font.system(size: 13, weight: .regular, design: .monospaced)
}

/// Note-reading fonts for the Markdown preview. They follow the editor's Font Size setting
/// (Settings › Editor) so Split view shows typed and rendered text at the same size.
public enum ReadingTypography {
    /// The size AppTypography.body is designed at; the user's setting scales relative to it.
    public static let baseSize: CGFloat = 14

    public static func body(_ scale: CGFloat) -> Font { .system(size: 14 * scale) }
    public static func callout(_ scale: CGFloat) -> Font { .system(size: 13 * scale) }
    public static func h1(_ scale: CGFloat) -> Font { .system(size: 22 * scale, weight: .bold) }
    public static func h2(_ scale: CGFloat) -> Font { .system(size: 17 * scale, weight: .semibold) }
    public static func h3(_ scale: CGFloat) -> Font { .system(size: 15 * scale, weight: .semibold) }
    public static func h4(_ scale: CGFloat) -> Font { .system(size: 13 * scale, weight: .semibold) }
}

private struct ReadingScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    /// editorFontSize / ReadingTypography.baseSize, set by MarkdownRendererView.
    public var readingScale: CGFloat {
        get { self[ReadingScaleKey.self] }
        set { self[ReadingScaleKey.self] = newValue }
    }
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


// MARK: - Window-aware sheet sizing

private struct WindowContentSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

extension EnvironmentValues {
    /// The window's real content size (before GUI zoom), set by ZoomContainerView. Sheets read it to stay inside the window.
    public var windowContentSize: CGSize {
        get { self[WindowContentSizeKey.self] }
        set { self[WindowContentSizeKey.self] = newValue }
    }
}

/// Gives a sheet its designed size, shrinking it to fit a smaller window instead of overflowing it.
private struct AdaptiveSheetFrame: ViewModifier {
    let width: CGFloat
    let height: CGFloat
    @Environment(\.windowContentSize) private var window

    func body(content: Content) -> some View {
        let fitWidth = window.width > 0 ? min(width, max(480, window.width - 48)) : width
        let fitHeight = window.height > 0 ? min(height, max(360, window.height - 56)) : height
        content.frame(width: fitWidth, height: fitHeight)
    }
}

extension View {
    public func adaptiveSheetFrame(width: CGFloat, height: CGFloat) -> some View {
        modifier(AdaptiveSheetFrame(width: width, height: height))
    }
}


// MARK: - Editor preferences

/// How wide note text may grow (Settings › Editor › Reading Width).
public enum ReadingWidth: String, CaseIterable, Identifiable {
    case narrow, standard, wide, full

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .narrow: return "Narrow"
        case .standard: return "Standard"
        case .wide: return "Wide"
        case .full: return "Full Width"
        }
    }

    /// Maximum text column width in points (about 65, 80 and 100 characters at 14pt).
    public var maxWidth: CGFloat {
        switch self {
        case .narrow: return 620
        case .standard: return 760
        case .wide: return 960
        case .full: return .infinity
        }
    }
}

public enum EditorPreferenceKey {
    public static let readingWidth = "editorReadingWidth"
    public static let defaultViewMode = "defaultViewMode"
}
