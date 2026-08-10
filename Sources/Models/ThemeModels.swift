import SwiftUI

// MARK: - Dynamic Theme Engine
enum AppColorTheme: String, CaseIterable, Identifiable {
    case midnightRose = "Midnight Rose"
    case obsidianBlack = "Obsidian Black"
    case nordArctic = "Nord Arctic"
    case solarized = "Solarized"
    case rosePine = "Rose Pine"
    
    var id: String { rawValue }
}

struct ThemeColors {
    static func primary(_ themeName: String) -> Color {
        switch themeName {
        case "Obsidian Black": return Color(red: 236/255, green: 72/255, blue: 153/255) // Soft Rose Pink
        case "Nord Arctic": return Color(red: 136/255, green: 192/255, blue: 208/255) // Frost Cyan (#88c0d0)
        case "Solarized": return Color(red: 181/255, green: 137/255, blue: 0/255) // Solarized Gold (#b58900)
        case "Rose Pine": return Color(red: 235/255, green: 188/255, blue: 186/255) // Warm Rose (#ebbcba)
        default: return Color(red: 225/255, green: 29/255, blue: 72/255) // Refined Crimson Rose (#e11d48)
        }
    }
    
    static func secondary(_ themeName: String) -> Color {
        switch themeName {
        case "Obsidian Black": return Color(red: 168/255, green: 85/255, blue: 247/255) // Soft Violet (#a855f7)
        case "Nord Arctic": return Color(red: 129/255, green: 161/255, blue: 193/255) // Frost Ice (#81a1c1)
        case "Solarized": return Color(red: 42/255, green: 161/255, blue: 152/255) // Cyan (#2aa198)
        case "Rose Pine": return Color(red: 196/255, green: 167/255, blue: 231/255) // Warm Lavender (#c4a7e7)
        default: return Color(red: 129/255, green: 140/255, blue: 248/255) // Soft Indigo (#818cf8)
        }
    }
    
    static func appBackground(_ isDark: Bool, _ themeName: String) -> Color {
        if !isDark {
            switch themeName {
            case "Nord Arctic": return Color(red: 236/255, green: 239/255, blue: 244/255)
            case "Solarized": return Color(red: 253/255, green: 246/255, blue: 227/255)
            case "Rose Pine": return Color(red: 250/255, green: 244/255, blue: 237/255)
            default: return Color(red: 246/255, green: 246/255, blue: 248/255)
            }
        } else {
            switch themeName {
            case "Obsidian Black": return Color(red: 14/255, green: 14/255, blue: 16/255) // Deep Pitch Black (#0e0e10)
            case "Nord Arctic": return Color(red: 46/255, green: 52/255, blue: 64/255) // Nord0 (#2e3440)
            case "Solarized": return Color(red: 0/255, green: 43/255, blue: 54/255) // Solarized base03 (#002b36)
            case "Rose Pine": return Color(red: 25/255, green: 23/255, blue: 36/255) // Rosé Pine Base (#191724)
            default: return Color(red: 18/255, green: 18/255, blue: 22/255) // Refined Neutral Dark Charcoal (#121216)
            }
        }
    }
    
    static func sidebarBackground(_ isDark: Bool, _ themeName: String) -> Color {
        if !isDark {
            switch themeName {
            case "Nord Arctic": return Color(red: 229/255, green: 233/255, blue: 240/255)
            case "Solarized": return Color(red: 238/255, green: 232/255, blue: 213/255)
            case "Rose Pine": return Color(red: 242/255, green: 233/255, blue: 225/255)
            default: return Color(red: 240/255, green: 240/255, blue: 243/255)
            }
        } else {
            switch themeName {
            case "Obsidian Black": return Color(red: 20/255, green: 20/255, blue: 23/255) // #141417
            case "Nord Arctic": return Color(red: 59/255, green: 66/255, blue: 82/255) // Nord1 (#3b4252)
            case "Solarized": return Color(red: 7/255, green: 54/255, blue: 66/255) // Solarized base02 (#073642)
            case "Rose Pine": return Color(red: 31/255, green: 29/255, blue: 46/255) // Rosé Pine Surface (#1f1d2e)
            default: return Color(red: 25/255, green: 25/255, blue: 30/255) // #19191e
            }
        }
    }
    
    static func panelBackground(_ isDark: Bool, _ themeName: String) -> Color {
        if !isDark {
            switch themeName {
            case "Nord Arctic": return Color(red: 216/255, green: 222/255, blue: 233/255)
            case "Solarized": return Color(red: 255/255, green: 255/255, blue: 245/255)
            case "Rose Pine": return Color(red: 255/255, green: 250/255, blue: 245/255)
            default: return Color.white
            }
        } else {
            switch themeName {
            case "Obsidian Black": return Color(red: 26/255, green: 26/255, blue: 30/255) // #1a1a1e
            case "Nord Arctic": return Color(red: 67/255, green: 76/255, blue: 94/255) // Nord2 (#434c5e)
            case "Solarized": return Color(red: 12/255, green: 65/255, blue: 78/255) // #0c414e
            case "Rose Pine": return Color(red: 38/255, green: 35/255, blue: 58/255) // Rosé Pine Overlay (#26233a)
            default: return Color(red: 32/255, green: 32/255, blue: 38/255) // #202026
            }
        }
    }
    
    static func cardBackground(_ isDark: Bool, _ themeName: String) -> Color {
        isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }
    
    static func subtleBorder(_ isDark: Bool, _ themeName: String) -> Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
}

// MARK: - Color Extensions
extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    
    private static func activeTheme() -> String {
        UserDefaults.standard.string(forKey: "colorTheme") ?? "Midnight Rose"
    }

    static func appBackground(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.appBackground(isDark, themeName ?? activeTheme())
    }
    
    static func panelBackground(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.panelBackground(isDark, themeName ?? activeTheme())
    }

    static func sidebarBackground(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.sidebarBackground(isDark, themeName ?? activeTheme())
    }
    
    static func cardBackground(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.cardBackground(isDark, themeName ?? activeTheme())
    }
    
    static func subtleBorder(_ isDark: Bool, themeName: String? = nil) -> Color {
        ThemeColors.subtleBorder(isDark, themeName ?? activeTheme())
    }

    static func appText(_ isDark: Bool) -> Color {
        isDark ? Color.white : Color(red: 24/255, green: 24/255, blue: 27/255)
    }
}
