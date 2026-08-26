import SwiftUI

// MARK: - Standardized App Loading & Progress Component
public struct AppLoadingIndicatorView: View {
    public let title: String
    public var subtitle: String? = nil
    public var progress: Double? = nil
    public var accentColor: Color? = nil
    
    @AppStorage("colorTheme") private var colorTheme = "Midnight Rose"
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    public init(
        title: String,
        subtitle: String? = nil,
        progress: Double? = nil,
        accentColor: Color? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.accentColor = accentColor
    }
    
    private var activeAccent: Color {
        accentColor ?? ThemeColors.primary(colorTheme, isDark: isDarkMode)
    }
    
    public var body: some View {
        VStack(spacing: AppSpacing.sm) {
            if let progress = progress {
                // Determinate Progress Bar
                VStack(spacing: 6) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(activeAccent)
                        .frame(width: 180)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            } else {
                // Indeterminate Spinner
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
                    .tint(activeAccent)
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)\(subtitle != nil ? ", " + subtitle! : "")")
    }
}
