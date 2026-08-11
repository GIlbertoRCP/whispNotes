import SwiftUI

// MARK: - Dynamic Theme Engine
enum AppColorTheme: String, CaseIterable, Identifiable {
    case midnightRose = "Midnight Rose"
    case obsidianBlack = "Obsidian Black"
    case nordArctic = "Nord Arctic"
    case slateMinimal = "Slate Minimal"
    case rosePine = "Rose Pine"
    
    var id: String { rawValue }
}

struct ThemeColors {
    static func primary(_ themeName: String, isDark: Bool = true) -> Color {
        if isDark {
            switch themeName {
            case "Obsidian Black": return Color(red: 244/255, green: 63/255, blue: 94/255) // Soft Rose Pink (#f43f5e)
            case "Nord Arctic": return Color(red: 136/255, green: 192/255, blue: 208/255) // Frost Cyan (#88c0d0)
            case "Slate Minimal", "Solarized": return Color(red: 56/255, green: 189/255, blue: 248/255) // Sky Blue (#38bdf8)
            case "Rose Pine": return Color(red: 235/255, green: 188/255, blue: 186/255) // Warm Rose (#ebbcba)
            default: return Color(red: 244/255, green: 63/255, blue: 94/255) // Refined Crimson Rose (#f43f5e)
            }
        } else {
            // High-contrast rich shades for Light Mode
            switch themeName {
            case "Obsidian Black": return Color(red: 190/255, green: 24/255, blue: 93/255) // Pink 700 (#be185d)
            case "Nord Arctic": return Color(red: 14/255, green: 116/255, blue: 144/255) // Cyan 700 (#0e7490)
            case "Slate Minimal", "Solarized": return Color(red: 2/255, green: 132/255, blue: 199/255) // Sky 700 (#0284c7)
            case "Rose Pine": return Color(red: 180/255, green: 99/255, blue: 122/255) // Dark Rose (#b4637a)
            default: return Color(red: 190/255, green: 18/255, blue: 60/255) // Rose 700 (#be123c)
            }
        }
    }
    
    static func secondary(_ themeName: String, isDark: Bool = true) -> Color {
        if isDark {
            switch themeName {
            case "Obsidian Black": return Color(red: 168/255, green: 85/255, blue: 247/255) // Soft Violet (#a855f7)
            case "Nord Arctic": return Color(red: 129/255, green: 161/255, blue: 193/255) // Frost Ice (#81a1c1)
            case "Slate Minimal", "Solarized": return Color(red: 52/255, green: 211/255, blue: 153/255) // Emerald (#34d399)
            case "Rose Pine": return Color(red: 196/255, green: 167/255, blue: 231/255) // Warm Lavender (#c4a7e7)
            default: return Color(red: 129/255, green: 140/255, blue: 248/255) // Soft Indigo (#818cf8)
            }
        } else {
            // High-contrast secondary shades for Light Mode
            switch themeName {
            case "Obsidian Black": return Color(red: 126/255, green: 34/255, blue: 206/255) // Purple 700 (#7e22ce)
            case "Nord Arctic": return Color(red: 29/255, green: 78/255, blue: 137/255) // Ice 700
            case "Slate Minimal", "Solarized": return Color(red: 5/255, green: 150/255, blue: 105/255) // Emerald 600 (#059669)
            case "Rose Pine": return Color(red: 144/255, green: 122/255, blue: 169/255) // Iris 700 (#907aa9)
            default: return Color(red: 67/255, green: 56/255, blue: 202/255) // Indigo 700 (#4338ca)
            }
        }
    }
    
    static func appBackground(_ isDark: Bool, _ themeName: String) -> Color {
        if !isDark {
            switch themeName {
            case "Nord Arctic": return Color(red: 241/255, green: 245/255, blue: 249/255)
            case "Rose Pine": return Color(red: 250/255, green: 244/255, blue: 237/255)
            default: return Color(red: 248/255, green: 250/255, blue: 252/255) // Slate 50 (#f8fafc)
            }
        } else {
            switch themeName {
            case "Obsidian Black": return Color(red: 9/255, green: 9/255, blue: 11/255) // True OLED Pitch Charcoal (#09090b)
            case "Nord Arctic": return Color(red: 46/255, green: 52/255, blue: 64/255) // Nord0 (#2e3440)
            case "Slate Minimal", "Solarized": return Color(red: 15/255, green: 23/255, blue: 42/255) // Slate 900 (#0f172a)
            case "Rose Pine": return Color(red: 25/255, green: 23/255, blue: 36/255) // Rosé Pine Base (#191724)
            default: return Color(red: 13/255, green: 15/255, blue: 23/255) // Deep Slate Navy (#0d0f17)
            }
        }
    }
    
    static func sidebarBackground(_ isDark: Bool, _ themeName: String) -> Color {
        if !isDark {
            switch themeName {
            case "Nord Arctic": return Color(red: 241/255, green: 245/255, blue: 249/255)
            case "Rose Pine": return Color(red: 242/255, green: 233/255, blue: 225/255)
            default: return Color(red: 248/255, green: 250/255, blue: 252/255) // Pure crisp Slate 50 (#f8fafc)
            }
        } else {
            switch themeName {
            case "Obsidian Black": return Color(red: 18/255, green: 18/255, blue: 21/255) // #121215
            case "Nord Arctic": return Color(red: 59/255, green: 66/255, blue: 82/255) // Nord1 (#3b4252)
            case "Slate Minimal", "Solarized": return Color(red: 30/255, green: 41/255, blue: 59/255) // Slate 800 (#1e293b)
            case "Rose Pine": return Color(red: 31/255, green: 29/255, blue: 46/255) // Rosé Pine Surface (#1f1d2e)
            default: return Color(red: 22/255, green: 25/255, blue: 34/255) // #161922
            }
        }
    }
    
    static func panelBackground(_ isDark: Bool, _ themeName: String) -> Color {
        if !isDark {
            return Color.white
        } else {
            switch themeName {
            case "Obsidian Black": return Color(red: 24/255, green: 24/255, blue: 27/255) // #18181b
            case "Nord Arctic": return Color(red: 67/255, green: 76/255, blue: 94/255) // Nord2 (#434c5e)
            case "Slate Minimal", "Solarized": return Color(red: 30/255, green: 41/255, blue: 59/255) // Slate 800 (#1e293b)
            case "Rose Pine": return Color(red: 38/255, green: 35/255, blue: 58/255) // Rosé Pine Overlay (#26233a)
            default: return Color(red: 30/255, green: 34/255, blue: 48/255) // #1e2230
            }
        }
    }
    
    static func cardBackground(_ isDark: Bool, _ themeName: String) -> Color {
        isDark ? Color.white.opacity(0.04) : Color(red: 241/255, green: 245/255, blue: 249/255) // Crisp Slate 100 in Light Mode
    }
    
    static func subtleBorder(_ isDark: Bool, _ themeName: String) -> Color {
        isDark ? Color.white.opacity(0.08) : Color(red: 203/255, green: 213/255, blue: 225/255) // Crisp Slate 300 border in Light Mode
    }
}

// MARK: - Color Extensions
extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let amber = Color(red: 129/255, green: 140/255, blue: 248/255)
    
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
        isDark ? Color.white : Color(red: 15/255, green: 23/255, blue: 42/255) // Slate 900
    }
}
