import Foundation
import SwiftUI
import AppKit

// MARK: - Export Format
public enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case pdf = "PDF Document"
    case html = "HTML Web Page"
    case markdown = "Markdown (.md)"
    case plainText = "Plain Text (.txt)"
    case srt = "Subtitles (.srt)"
    case vtt = "WebVTT (.vtt)"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .pdf: return "PDF"
        case .html: return "HTML"
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        case .srt: return "Subtitles"
        case .vtt: return "WebVTT"
        }
    }

    public var icon: String {
        switch self {
        case .pdf: return "doc.richtext.fill"
        case .html: return "safari.fill"
        case .markdown: return "arrow.down.doc.fill"
        case .plainText: return "doc.plaintext.fill"
        case .srt: return "captions.bubble.fill"
        case .vtt: return "film.fill"
        }
    }

    public var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .html: return "html"
        case .markdown: return "md"
        case .plainText: return "txt"
        case .srt: return "srt"
        case .vtt: return "vtt"
        }
    }
}

// MARK: - Export Font Family
public enum ExportFontFamily: String, CaseIterable, Identifiable, Codable {
    case sansSerif = "Modern Sans-Serif"
    case serif = "Editorial Serif"
    case monospace = "Technical Monospace"
    case rounded = "Friendly Rounded"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sansSerif: return "Sans-Serif (SF Pro / Inter)"
        case .serif: return "Serif (New York / Georgia)"
        case .monospace: return "Monospace (SF Mono / Menlo)"
        case .rounded: return "Rounded (SF Pro Rounded)"
        }
    }

    public var samplePreview: String {
        switch self {
        case .sansSerif: return "The quick brown fox jumps"
        case .serif: return "The quick brown fox jumps"
        case .monospace: return "01: const note = true;"
        case .rounded: return "The quick brown fox jumps"
        }
    }

    /// Resolves AppKit NSFont with chosen weight and size
    public func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self {
        case .sansSerif:
            return NSFont.systemFont(ofSize: size, weight: weight)
        case .serif:
            let desc = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif)
            if let desc = desc, let font = NSFont(descriptor: desc, size: size) {
                return font
            }
            return NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        case .monospace:
            let desc = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.monospaced)
            if let desc = desc, let font = NSFont(descriptor: desc, size: size) {
                return font
            }
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .rounded:
            let desc = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded)
            if let desc = desc, let font = NSFont(descriptor: desc, size: size) {
                return font
            }
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }

    /// CSS font-family string for HTML export
    public var cssFontFamily: String {
        switch self {
        case .sansSerif:
            return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Inter', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        case .serif:
            return "'New York', 'Georgia', Cambria, 'Times New Roman', Times, serif"
        case .monospace:
            return "'SF Mono', Monaco, Menlo, 'Courier New', Courier, monospace"
        case .rounded:
            return "'SF Pro Rounded', -apple-system, BlinkMacSystemFont, 'Nunito', 'Quicksand', sans-serif"
        }
    }

    /// SwiftUI Font design
    public var fontDesign: Font.Design {
        switch self {
        case .sansSerif: return .default
        case .serif: return .serif
        case .monospace: return .monospaced
        case .rounded: return .rounded
        }
    }
}

// MARK: - Export Font Size
public enum ExportFontSize: String, CaseIterable, Identifiable, Codable {
    case small = "Small (10pt)"
    case medium = "Standard (12pt)"
    case large = "Large (14pt)"
    case extraLarge = "Extra Large (16pt)"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Standard"
        case .large: return "Large"
        case .extraLarge: return "XL"
        }
    }

    public var bodySize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        case .extraLarge: return 16
        }
    }

    public var titleSize: CGFloat {
        switch self {
        case .small: return 18
        case .medium: return 22
        case .large: return 26
        case .extraLarge: return 30
        }
    }

    public var h1Size: CGFloat {
        switch self {
        case .small: return 15
        case .medium: return 18
        case .large: return 21
        case .extraLarge: return 24
        }
    }

    public var h2Size: CGFloat {
        switch self {
        case .small: return 13
        case .medium: return 15
        case .large: return 17
        case .extraLarge: return 19
        }
    }

    public var subtitleSize: CGFloat {
        switch self {
        case .small: return 9
        case .medium: return 11
        case .large: return 12
        case .extraLarge: return 13
        }
    }
}

// MARK: - Export Border Style
public enum ExportBorderStyle: String, CaseIterable, Identifiable, Codable {
    case borderedCard = "Framed Card"
    case headerDivider = "Header Divider"
    case none = "Borderless"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .borderedCard: return "Framed"
        case .headerDivider: return "Divider"
        case .none: return "Borderless"
        }
    }

    public var description: String {
        switch self {
        case .borderedCard: return "Clean border box around content with subtle header divider"
        case .headerDivider: return "Minimalist classic layout with crisp horizontal divider lines"
        case .none: return "Modern open layout without frame borders"
        }
    }
}

// MARK: - Export Indent Style
public enum ExportIndentStyle: String, CaseIterable, Identifiable, Codable {
    case blockParagraphs = "Block Spacing"
    case indentedParagraphs = "First-Line Indent"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .blockParagraphs: return "Block"
        case .indentedParagraphs: return "Indent"
        }
    }

    public var description: String {
        switch self {
        case .blockParagraphs: return "Standard paragraph gaps (ideal for technical & web documents)"
        case .indentedParagraphs: return "20pt first-line indentation (classic book & editorial styling)"
        }
    }

    public var firstLineIndent: CGFloat {
        switch self {
        case .blockParagraphs: return 0
        case .indentedParagraphs: return 20
        }
    }
}

// MARK: - Export Margin Size
public enum ExportMarginSize: String, CaseIterable, Identifiable, Codable {
    case compact = "Compact (24pt)"
    case standard = "Standard (36pt)"
    case generous = "Generous (48pt)"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .compact: return "Compact"
        case .standard: return "Standard"
        case .generous: return "Wide"
        }
    }

    public var points: CGFloat {
        switch self {
        case .compact: return 24
        case .standard: return 36
        case .generous: return 48
        }
    }
}

// MARK: - Export Theme
public enum ExportTheme: String, CaseIterable, Identifiable, Codable {
    case system = "System Auto"
    case light = "Clean Light"
    case dark = "Obsidian Dark"

    public var id: String { rawValue }
}

// MARK: - Full Export Configuration
public struct ExportConfiguration: Codable, Equatable {
    public var format: ExportFormat
    public var fontFamily: ExportFontFamily
    public var fontSize: ExportFontSize
    public var borderStyle: ExportBorderStyle
    public var indentStyle: ExportIndentStyle
    public var marginSize: ExportMarginSize
    public var includeMetadata: Bool
    public var includeTranscript: Bool
    public var theme: ExportTheme

    public static let `default` = ExportConfiguration(
        format: .pdf,
        fontFamily: .sansSerif,
        fontSize: .medium,
        borderStyle: .borderedCard,
        indentStyle: .blockParagraphs,
        marginSize: .standard,
        includeMetadata: true,
        includeTranscript: true,
        theme: .system
    )
}
