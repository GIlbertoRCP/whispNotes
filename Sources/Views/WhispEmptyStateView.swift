import SwiftUI

// MARK: - Standardized WhispNotes Empty State Component
public struct WhispEmptyStateView: View {
    public let icon: String
    public let title: String
    public let description: String
    public var actionTitle: String? = nil
    public var shortcutHint: String? = nil
    public var action: (() -> Void)? = nil
    
    @AppStorage("colorTheme") private var colorTheme = "Midnight Rose"
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    public init(
        icon: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        shortcutHint: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.shortcutHint = shortcutHint
        self.action = action
    }
    
    private var primaryAccent: Color {
        ThemeColors.primary(colorTheme, isDark: isDarkMode)
    }
    
    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(primaryAccent.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(primaryAccent)
            }
            .padding(.bottom, 2)
            
            // Title
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                .multilineTextAlignment(.center)
            
            // Description
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            
            // Optional Action Button with Shortcut
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Text(actionTitle)
                            .font(.caption)
                            .fontWeight(.bold)
                        
                        if let shortcut = shortcutHint {
                            Text(shortcut)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(primaryAccent)
                    .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityLabel(actionTitle)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
