import SwiftUI

// MARK: - App Update Modal View
public struct AppUpdateModalView: View {
    @ObservedObject var updater: GitHubReleaseUpdater
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("colorTheme") private var colorTheme = "Classic Minimal"
    
    public init(updater: GitHubReleaseUpdater) {
        self.updater = updater
    }
    
    private var primaryAccent: Color {
        ThemeColors.primary(colorTheme)
    }
    
    public var body: some View {
        ZStack {
            Color.cardBackground(isDarkMode)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(primaryAccent.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: isUpdateAvailable ? "sparkles" : "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isUpdateAvailable ? primaryAccent : .emerald)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isUpdateAvailable ? "Software Update Available" : "You're Up to Date")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Text(isUpdateAvailable ? "A new version of WhispNotes is ready to install." : "WhispNotes \(updater.currentVersion) is currently the newest version.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { updater.showUpdateModal = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color.sidebarBackground(isDarkMode))
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Content Body
                VStack(spacing: 16) {
                    if let release = updater.latestRelease, isUpdateAvailable {
                        // Version Transition Pill
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Text("Current:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("v\(updater.currentVersion)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.panelBackground(isDarkMode))
                                    .cornerRadius(4)
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(primaryAccent)
                            
                            HStack(spacing: 6) {
                                Text("Latest:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(release.tagName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(primaryAccent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(primaryAccent.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text(release.formattedDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.panelBackground(isDarkMode))
                        .cornerRadius(8)
                        
                        // Release Notes Markdown Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Release Notes")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(release.body)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(isDarkMode ? Color(red: 226/255, green: 232/255, blue: 240/255) : Color(red: 30/255, green: 41/255, blue: 59/255))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                .padding(12)
                            }
                            .frame(height: 180)
                            .background(Color.sidebarBackground(isDarkMode))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
                            )
                        }
                    } else {
                        // Up-to-date state presentation
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.emerald)
                                .padding(.top, 24)
                            
                            Text("WhispNotes v\(updater.currentVersion)")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("You have the latest version with all recent improvements and native features.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            if let lastCheck = updater.lastCheckDate {
                                Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                            
                            Spacer()
                        }
                        .frame(height: 240)
                    }
                    
                    // Progress bar if downloading
                    if case let .downloading(progress, written, total) = updater.status {
                        VStack(spacing: 6) {
                            HStack {
                                Text("Downloading Update...")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("\(formatBytes(written)) / \(formatBytes(total)) (\(Int(progress * 100))%)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: progress, total: 1.0)
                                .accentColor(primaryAccent)
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    if case let .error(msg) = updater.status {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(20)
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Footer Action Buttons
                HStack(spacing: 12) {
                    if let release = updater.latestRelease, isUpdateAvailable {
                        Button(action: { updater.openReleaseInBrowser(release) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text("View on GitHub")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    if isUpdateAvailable, let release = updater.latestRelease {
                        switch updater.status {
                        case .downloading:
                            Button("Cancel Download") {
                                updater.cancelDownload()
                            }
                            .font(.subheadline)
                            .buttonStyle(.plain)
                            
                        case let .readyToInstall(fileURL, _):
                            Button(action: { updater.installAndRelaunch(fileURL: fileURL) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.app.fill")
                                    Text("Install & Open DMG")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(primaryAccent)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                        default:
                            Button("Remind Me Later") {
                                updater.showUpdateModal = false
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                            
                            Button(action: { updater.startDownload(release: release) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Update Now")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(primaryAccent)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button("Close") {
                            updater.showUpdateModal = false
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(primaryAccent)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.sidebarBackground(isDarkMode))
            }
        }
        .frame(width: 520, height: 460)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
    
    private var isUpdateAvailable: Bool {
        if case .updateAvailable = updater.status { return true }
        if case .downloading = updater.status { return true }
        if case .readyToInstall = updater.status { return true }
        if case .installing = updater.status { return true }
        if let rel = updater.latestRelease, GitHubReleaseUpdater.isVersion(rel.tagName, newerThan: updater.currentVersion) {
            return true
        }
        return false
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
