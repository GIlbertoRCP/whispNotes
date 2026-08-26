import SwiftUI

// MARK: - Theme Definition Architecture
public struct ThemeDefinition: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let isDark: Bool
    
    // Core Accent Tokens
    public let primary: Color
    public let secondary: Color
    
    // Surface Tokens
    public let appBackground: Color
    public let sidebarBackground: Color
    public let panelBackground: Color
    public let cardBackground: Color
    public let cardBackgroundElevated: Color
    
    // Border & Separation Tokens
    public let border: Color
    public let borderStrong: Color
    
    // Depth & Shadow Tokens
    public let shadowColor: Color
    public let shadowOpacity: Double
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(isDark)
    }
    
    public static func == (lhs: ThemeDefinition, rhs: ThemeDefinition) -> Bool {
        lhs.name == rhs.name && lhs.isDark == rhs.isDark
    }
}

// MARK: - App Color Theme Enum
public enum AppColorTheme: String, CaseIterable, Identifiable {
    case midnightRose = "Midnight Rose"
    case obsidianBlack = "Obsidian Black"
    case nordArctic = "Nord Arctic"
    case slateMinimal = "Slate Minimal"
    case rosePine = "Rose Pine"
    
    public var id: String { rawValue }
}

// MARK: - Curated Theme Library
public struct ThemeLibrary {
    
    // 1. Midnight Rose (Dark & Light) - Warm, moody indigo-charcoal with soft crimson rose
    public static let midnightRoseDark = ThemeDefinition(
        name: "Midnight Rose",
        displayName: "Midnight Rose",
        isDark: true,
        primary: Color(red: 244/255, green: 63/255, blue: 94/255),      // Soft Crimson Rose (#f43f5e)
        secondary: Color(red: 129/255, green: 140/255, blue: 248/255),  // Soft Indigo (#818cf8)
        appBackground: Color(red: 13/255, green: 15/255, blue: 23/255),   // Deep Slate Navy (#0d0f17)
        sidebarBackground: Color(red: 20/255, green: 23/255, blue: 33/255), // Indigo Tinted Charcoal (#141721)
        panelBackground: Color(red: 27/255, green: 31/255, blue: 44/255),   // Layer 2 (#1b1f2c)
        cardBackground: Color(red: 35/255, green: 40/255, blue: 56/255).opacity(0.65), // Soft translucent indigo card
        cardBackgroundElevated: Color(red: 42/255, green: 48/255, blue: 67/255), // Elevated Card
        border: Color(red: 60/255, green: 68/255, blue: 92/255).opacity(0.35),
        borderStrong: Color(red: 244/255, green: 63/255, blue: 94/255).opacity(0.45),
        shadowColor: Color.black,
        shadowOpacity: 0.35
    )
    
    public static let midnightRoseLight = ThemeDefinition(
        name: "Midnight Rose",
        displayName: "Midnight Rose",
        isDark: false,
        primary: Color(red: 190/255, green: 18/255, blue: 60/255),      // Rose 700 (#be123c)
        secondary: Color(red: 67/255, green: 56/255, blue: 202/255),    // Indigo 700 (#4338ca)
        appBackground: Color(red: 250/255, green: 250/255, blue: 252/255),
        sidebarBackground: Color(red: 244/255, green: 244/255, blue: 248/255),
        panelBackground: Color.white,
        cardBackground: Color(red: 241/255, green: 241/255, blue: 246/255),
        cardBackgroundElevated: Color.white,
        border: Color(red: 226/255, green: 226/255, blue: 234/255),
        borderStrong: Color(red: 190/255, green: 18/255, blue: 60/255).opacity(0.35),
        shadowColor: Color.black,
        shadowOpacity: 0.08
    )
    
    // 2. Obsidian Black (Dark & Light) - True OLED Pitch Charcoal with Ice Slate Cyan & Soft Rose
    public static let obsidianBlackDark = ThemeDefinition(
        name: "Obsidian Black",
        displayName: "Obsidian Black",
        isDark: true,
        primary: Color(red: 244/255, green: 114/255, blue: 140/255),    // Soft Rose (#f4728c)
        secondary: Color(red: 56/255, green: 189/255, blue: 248/255),   // Ice Slate Cyan (#38bdf8)
        appBackground: Color(red: 10/255, green: 10/255, blue: 12/255),  // Pitch OLED Charcoal (#0a0a0c)
        sidebarBackground: Color(red: 16/255, green: 16/255, blue: 20/255), // Pitch Layer 1 (#101014)
        panelBackground: Color(red: 22/255, green: 22/255, blue: 26/255),   // Pitch Layer 2 (#16161a)
        cardBackground: Color(red: 30/255, green: 30/255, blue: 36/255),   // Crisp neutral dark card
        cardBackgroundElevated: Color(red: 38/255, green: 38/255, blue: 46/255),
        border: Color(red: 45/255, green: 45/255, blue: 54/255),          // Subtle neutral border
        borderStrong: Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.45),
        shadowColor: Color.black,
        shadowOpacity: 0.45
    )
    
    public static let obsidianBlackLight = ThemeDefinition(
        name: "Obsidian Black",
        displayName: "Obsidian Black",
        isDark: false,
        primary: Color(red: 225/255, green: 29/255, blue: 72/255),      // Rose 600
        secondary: Color(red: 8/255, green: 145/255, blue: 178/255),    // Cyan 600 (#0891b2)
        appBackground: Color(red: 248/255, green: 250/255, blue: 252/255),
        sidebarBackground: Color(red: 241/255, green: 245/255, blue: 249/255),
        panelBackground: Color.white,
        cardBackground: Color(red: 236/255, green: 242/255, blue: 248/255),
        cardBackgroundElevated: Color.white,
        border: Color(red: 203/255, green: 213/255, blue: 225/255),
        borderStrong: Color(red: 8/255, green: 145/255, blue: 178/255).opacity(0.5),
        shadowColor: Color.black,
        shadowOpacity: 0.1
    )
    
    // 3. Nord Arctic (Dark & Light) - Frosted Scandinavian Polar Night with Frost Ice & Cyan
    public static let nordArcticDark = ThemeDefinition(
        name: "Nord Arctic",
        displayName: "Nord Arctic",
        isDark: true,
        primary: Color(red: 136/255, green: 192/255, blue: 208/255),    // Nord Frost Cyan (#88c0d0)
        secondary: Color(red: 129/255, green: 161/255, blue: 193/255),  // Nord Frost Ice (#81a1c1)
        appBackground: Color(red: 46/255, green: 52/255, blue: 64/255),    // Nord0 Polar Night (#2e3440)
        sidebarBackground: Color(red: 59/255, green: 66/255, blue: 82/255), // Nord1 (#3b4252)
        panelBackground: Color(red: 67/255, green: 76/255, blue: 94/255),   // Nord2 (#434c5e)
        cardBackground: Color(red: 76/255, green: 86/255, blue: 106/255).opacity(0.6), // Nord3 (#4c566a)
        cardBackgroundElevated: Color(red: 76/255, green: 86/255, blue: 106/255),
        border: Color(red: 94/255, green: 129/255, blue: 172/255).opacity(0.35), // Cool frosted border
        borderStrong: Color(red: 136/255, green: 192/255, blue: 208/255).opacity(0.7),
        shadowColor: Color(red: 20/255, green: 24/255, blue: 33/255),
        shadowOpacity: 0.4
    )
    
    public static let nordArcticLight = ThemeDefinition(
        name: "Nord Arctic",
        displayName: "Nord Arctic",
        isDark: false,
        primary: Color(red: 14/255, green: 116/255, blue: 144/255),     // Cyan 700 (#0e7490)
        secondary: Color(red: 29/255, green: 78/255, blue: 137/255),    // Ice 700
        appBackground: Color(red: 241/255, green: 245/255, blue: 249/255),
        sidebarBackground: Color(red: 232/255, green: 238/255, blue: 245/255),
        panelBackground: Color.white,
        cardBackground: Color(red: 226/255, green: 234/255, blue: 243/255),
        cardBackgroundElevated: Color.white,
        border: Color(red: 198/255, green: 211/255, blue: 226/255),
        borderStrong: Color(red: 14/255, green: 116/255, blue: 144/255).opacity(0.4),
        shadowColor: Color.black,
        shadowOpacity: 0.08
    )
    
    // 4. Rosé Pine (Dark & Light) - Warm, soft muted lavender & warm rose
    public static let rosePineDark = ThemeDefinition(
        name: "Rose Pine",
        displayName: "Rosé Pine",
        isDark: true,
        primary: Color(red: 235/255, green: 188/255, blue: 186/255),    // Warm Rose (#ebbcba)
        secondary: Color(red: 196/255, green: 167/255, blue: 231/255),  // Warm Lavender (#c4a7e7)
        appBackground: Color(red: 25/255, green: 23/255, blue: 36/255),    // Base (#191724)
        sidebarBackground: Color(red: 31/255, green: 29/255, blue: 46/255), // Surface (#1f1d2e)
        panelBackground: Color(red: 38/255, green: 35/255, blue: 58/255),   // Overlay (#26233a)
        cardBackground: Color(red: 44/255, green: 41/255, blue: 66/255).opacity(0.7), // Muted plum card
        cardBackgroundElevated: Color(red: 52/255, green: 48/255, blue: 77/255),
        border: Color(red: 82/255, green: 79/255, blue: 103/255).opacity(0.5), // Warm muted border
        borderStrong: Color(red: 235/255, green: 188/255, blue: 186/255).opacity(0.65),
        shadowColor: Color(red: 16/255, green: 14/255, blue: 24/255),
        shadowOpacity: 0.45
    )
    
    public static let rosePineLight = ThemeDefinition(
        name: "Rose Pine",
        displayName: "Rosé Pine",
        isDark: false,
        primary: Color(red: 180/255, green: 99/255, blue: 122/255),     // Dark Rose (#b4637a)
        secondary: Color(red: 144/255, green: 122/255, blue: 169/255),  // Iris 700 (#907aa9)
        appBackground: Color(red: 250/255, green: 244/255, blue: 237/255), // Rosé Pine Dawn Base
        sidebarBackground: Color(red: 242/255, green: 233/255, blue: 225/255), // Dawn Surface
        panelBackground: Color.white,
        cardBackground: Color(red: 238/255, green: 228/255, blue: 219/255),
        cardBackgroundElevated: Color.white,
        border: Color(red: 218/255, green: 206/255, blue: 195/255),
        borderStrong: Color(red: 180/255, green: 99/255, blue: 122/255).opacity(0.4),
        shadowColor: Color.black,
        shadowOpacity: 0.08
    )
    
    // 5. Slate Minimal (Dark & Light) - Crisp Sky Blue & Emerald Mint on Slate
    public static let slateMinimalDark = ThemeDefinition(
        name: "Slate Minimal",
        displayName: "Slate Minimal",
        isDark: true,
        primary: Color(red: 56/255, green: 189/255, blue: 248/255),     // Sky Blue (#38bdf8)
        secondary: Color(red: 52/255, green: 211/255, blue: 153/255),   // Emerald Mint (#34d399)
        appBackground: Color(red: 15/255, green: 23/255, blue: 42/255),   // Slate 900 (#0f172a)
        sidebarBackground: Color(red: 24/255, green: 34/255, blue: 53/255), // Slate 850
        panelBackground: Color(red: 30/255, green: 41/255, blue: 59/255),   // Slate 800 (#1e293b)
        cardBackground: Color(red: 40/255, green: 53/255, blue: 76/255).opacity(0.65),
        cardBackgroundElevated: Color(red: 51/255, green: 65/255, blue: 85/255), // Slate 700 (#334155)
        border: Color(red: 51/255, green: 65/255, blue: 85/255).opacity(0.7),
        borderStrong: Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.65),
        shadowColor: Color.black,
        shadowOpacity: 0.4
    )
    
    public static let slateMinimalLight = ThemeDefinition(
        name: "Slate Minimal",
        displayName: "Slate Minimal",
        isDark: false,
        primary: Color(red: 2/255, green: 132/255, blue: 199/255),      // Sky 700 (#0284c7)
        secondary: Color(red: 5/255, green: 150/255, blue: 105/255),    // Emerald 600 (#059669)
        appBackground: Color(red: 248/255, green: 250/255, blue: 252/255), // Slate 50
        sidebarBackground: Color(red: 241/255, green: 245/255, blue: 249/255), // Slate 100
        panelBackground: Color.white,
        cardBackground: Color(red: 235/255, green: 241/255, blue: 248/255),
        cardBackgroundElevated: Color.white,
        border: Color(red: 203/255, green: 213/255, blue: 225/255),
        borderStrong: Color(red: 2/255, green: 132/255, blue: 199/255).opacity(0.4),
        shadowColor: Color.black,
        shadowOpacity: 0.08
    )
    
    public static func getDefinition(name: String, isDark: Bool) -> ThemeDefinition {
        switch name {
        case "Obsidian Black": return isDark ? obsidianBlackDark : obsidianBlackLight
        case "Nord Arctic": return isDark ? nordArcticDark : nordArcticLight
        case "Rose Pine": return isDark ? rosePineDark : rosePineLight
        case "Slate Minimal", "Solarized": return isDark ? slateMinimalDark : slateMinimalLight
        default: return isDark ? midnightRoseDark : midnightRoseLight
        }
    }
}

// MARK: - Dynamic Theme Engine & Backwards-Compatible Helpers
public struct ThemeColors {
    public static func definition(_ themeName: String, isDark: Bool = true) -> ThemeDefinition {
        ThemeLibrary.getDefinition(name: themeName, isDark: isDark)
    }
    
    public static func primary(_ themeName: String, isDark: Bool = true) -> Color {
        definition(themeName, isDark: isDark).primary
    }
    
    public static func secondary(_ themeName: String, isDark: Bool = true) -> Color {
        definition(themeName, isDark: isDark).secondary
    }
    
    public static func appBackground(_ isDark: Bool, _ themeName: String) -> Color {
        definition(themeName, isDark: isDark).appBackground
    }
    
    public static func sidebarBackground(_ isDark: Bool, _ themeName: String) -> Color {
        definition(themeName, isDark: isDark).sidebarBackground
    }
    
    public static func panelBackground(_ isDark: Bool, _ themeName: String) -> Color {
        definition(themeName, isDark: isDark).panelBackground
    }
    
    public static func cardBackground(_ isDark: Bool, _ themeName: String) -> Color {
        definition(themeName, isDark: isDark).cardBackground
    }
    
    public static func cardBackgroundElevated(_ isDark: Bool, _ themeName: String) -> Color {
        definition(themeName, isDark: isDark).cardBackgroundElevated
    }
    
    public static func subtleBorder(_ isDark: Bool, _ themeName: String) -> Color {
        definition(themeName, isDark: isDark).border
    }
    
    public static func strongBorder(_ isDark: Bool, _ themeName: String) -> Color {
        definition(themeName, isDark: isDark).borderStrong
    }
}

// MARK: - Color Extensions
extension Color {
    public static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    public static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    
    private static func activeTheme() -> String {
        UserDefaults.standard.string(forKey: "colorTheme") ?? "Midnight Rose"
    }

    public static func appBackground(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.appBackground(isDark, themeName ?? activeTheme())
    }
    
    public static func panelBackground(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.panelBackground(isDark, themeName ?? activeTheme())
    }

    public static func sidebarBackground(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.sidebarBackground(isDark, themeName ?? activeTheme())
    }
    
    public static func cardBackground(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.cardBackground(isDark, themeName ?? activeTheme())
    }
    
    public static func cardBackgroundElevated(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.cardBackgroundElevated(isDark, themeName ?? activeTheme())
    }
    
    public static func subtleBorder(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.subtleBorder(isDark, themeName ?? activeTheme())
    }
    
    public static func strongBorder(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.strongBorder(isDark, themeName ?? activeTheme())
    }

    public static func appText(_ isDark: Bool) -> Color {
        isDark ? Color.white : Color(red: 15/255, green: 23/255, blue: 42/255)
    }
}

// MARK: - Semantic Purpose Colors
public struct SemanticColor {
    // 1. Destructive & Recording (strictly red/crimson)
    public static let record = Color(red: 239/255, green: 68/255, blue: 68/255) // Red 500 (#EF4444)
    public static let recordPulse = Color(red: 248/255, green: 113/255, blue: 113/255) // Red 400
    public static let destructive = Color(red: 220/255, green: 38/255, blue: 38/255) // Red 600 (#DC2626)
    
    // 2. AI Intelligence (distinct Violet/Purple)
    public static let aiAccent = Color(red: 139/255, green: 92/255, blue: 246/255) // Purple 500 (#8B5CF6)
    public static let aiAccentGlow = Color(red: 168/255, green: 85/255, blue: 247/255) // Purple 400 (#A855F7)
    public static let aiAccentSurface = Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.12)
    
    // 3. File-Type Badges & Content Categorization
    public static let pdfBadge = Color(red: 245/255, green: 158/255, blue: 11/255) // Amber 500
    public static let pdfSurface = Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.15)
    public static let audioBadge = Color(red: 59/255, green: 130/255, blue: 246/255) // Blue 500
    public static let audioSurface = Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.15)
    public static let markdownBadge = Color(red: 100/255, green: 116/255, blue: 139/255) // Slate 500
    public static let markdownSurface = Color(red: 100/255, green: 116/255, blue: 139/255).opacity(0.12)
    
    // 4. Statuses
    public static let success = Color(red: 16/255, green: 185/255, blue: 129/255) // Emerald 500
    public static let warning = Color(red: 245/255, green: 158/255, blue: 11/255) // Amber 500
    public static let info = Color(red: 56/255, green: 189/255, blue: 248/255) // Sky 400
}
