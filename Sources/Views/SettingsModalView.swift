import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Modal View
enum SettingsTab: String, CaseIterable, Identifiable {
    case preferences = "Preferences"
    case typography = "Typography"
    case aiProvider = "AI Provider"
    case cloudSync = "Cloud Sync & Vault"
    case audioDevices = "Audio Devices"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .preferences: return "gearshape"
        case .typography: return "textformat"
        case .aiProvider: return "sparkles"
        case .cloudSync: return "folder.badge.gearshape"
        case .audioDevices: return "mic"
        }
    }
}

struct SettingsModalView: View {
    @Binding var isOpen: Bool
    @Binding var notes: [NoteItem]
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("colorTheme") private var colorTheme = "Midnight Rose"
    @AppStorage("editorFontSize") private var editorFontSize = 14.0
    @AppStorage("editorFontDesign") private var editorFontDesign = "Monospaced"
    @AppStorage("defaultSpeakerTemplate") private var defaultSpeakerTemplate = "Speaker 1 / Speaker 2"
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "Auto-Detect Language"
    @AppStorage("whisperModelSize") private var whisperModelSize = "Base (Recommended)"
    @AppStorage("activeWhisperModel") private var activeWhisperModel = "ggml-base.bin"
    @AppStorage("selectedInputMicrophone") private var selectedInputMicrophone = "Default System Microphone"
    @AppStorage("selectedOutputSpeaker") private var selectedOutputSpeaker = "Default System Speaker"
    
    @State private var selectedTab: SettingsTab = .preferences
    @StateObject private var deviceManager = AudioDeviceManager.shared
    @StateObject private var downloader = WhisperModelDownloader.shared
    @StateObject private var gemmaDownloader = GemmaModelDownloader.shared

    var primaryAccent: Color {
        ThemeColors.primary(colorTheme)
    }
    
    let fontDesigns = ["Monospaced", "Sans-Serif", "Serif"]
    let speakerTemplates = ["Speaker 1 / Speaker 2", "Professor / Student", "Interviewer / Candidate", "Presenter / Audience"]
    let languages = ["Auto-Detect Language", "English", "Spanish", "French", "German", "Italian", "Portuguese", "Japanese", "Chinese", "Korean"]
    let modelSizes = ["Tiny", "Base (Recommended)", "Small", "Medium", "Large"]

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(primaryAccent)
                    Text("SETTINGS")
                        .font(.title3)
                        .fontWeight(.heavy)
                }
                .padding(.bottom, 8)
                
                // Tabs List
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button(action: { selectedTab = tab }) {
                            HStack(spacing: 10) {
                                Image(systemName: tab.iconName)
                                    .font(.body)
                                    .frame(width: 20)
                                Text(tab.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? primaryAccent.opacity(0.15) : Color.clear)
                            .foregroundColor(selectedTab == tab ? primaryAccent : .secondary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Bottom Cancel Button
                Button(action: { isOpen = false }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.cardBackground(isDarkMode))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(width: 220)
            .background(Color.sidebarBackground(isDarkMode))
            
            Divider()
                .background(Color.subtleBorder(isDarkMode))
            
            // Right Main Content Panel
            VStack(spacing: 0) {
                // Top Content Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headerTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(headerSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { isOpen = false }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Tab Content
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .preferences:
                            preferencesTabContent
                        case .typography:
                            typographyTabContent
                        case .aiProvider:
                            aiProviderTabContent
                        case .cloudSync:
                            cloudSyncTabContent
                        case .audioDevices:
                            audioDevicesTabContent
                        }
                    }
                    .padding(20)
                }
                
                Spacer()
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Bottom Action Footer
                HStack {
                    Spacer()
                    Button("Cancel") {
                        isOpen = false
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    
                    Button(action: { isOpen = false }) {
                        Text("Save Configuration")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(primaryAccent)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(Color.panelBackground(isDarkMode))
        }
        .frame(width: 740, height: 520)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
        )
        .onAppear {
            deviceManager.refreshDevices()
            downloader.checkDownloadedModels()
        }
    }
    
    private var headerTitle: String {
        switch selectedTab {
        case .preferences: return "Preferences & Theme Presets"
        case .typography: return "Editor Typography & Sizing"
        case .aiProvider: return "AI Speech & Transcriber Engine"
        case .cloudSync: return "Vault Storage & Backup"
        case .audioDevices: return "Audio Capture & Hardware"
        }
    }
    
    private var headerSubtitle: String {
        switch selectedTab {
        case .preferences: return "Manage dark mode, theme palettes, and default speaker tags."
        case .typography: return "Customize font family design and editor font sizes."
        case .aiProvider: return "Download offline Whisper GGUF models for local execution."
        case .cloudSync: return "Manage vault storage backup and JSON export."
        case .audioDevices: return "Select active input microphone and speaker hardware."
        }
    }
    
    private var preferencesTabContent: some View {
        VStack(spacing: 16) {
            // Card 1: Application Dark Mode
            HStack(spacing: 14) {
                Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.title2)
                    .foregroundColor(primaryAccent)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Application Dark Mode")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Toggle between Light theme and high-contrast Dark theme.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isDarkMode)
                    .toggleStyle(.switch)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(12)
            
            // Card 2: Color Theme Presets
            VStack(alignment: .leading, spacing: 10) {
                Text("COLOR THEME PALETTE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $colorTheme) {
                    ForEach(AppColorTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(12)

            // Card 3: Speaker Naming Template
            VStack(alignment: .leading, spacing: 10) {
                Text("DEFAULT SPEAKER NAMING TEMPLATE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $defaultSpeakerTemplate) {
                    ForEach(speakerTemplates, id: \.self) { tpl in
                        Text(tpl).tag(tpl)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(12)
        }
    }

    private var typographyTabContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("FONT SIZE (\(Int(editorFontSize)) pt)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Slider(value: $editorFontSize, in: 12...24, step: 1.0)
                    .accentColor(primaryAccent)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("FONT FAMILY DESIGN")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $editorFontDesign) {
                    ForEach(fontDesigns, id: \.self) { design in
                        Text(design).tag(design)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(12)
        }
    }
    
    private var aiProviderTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OFFLINE WHISPER GGUF MODELS")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text("Download Whisper models from HuggingFace to run 100% offline local transcription.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(downloader.availableModels) { model in
                let isDownloaded = downloader.downloadedModelIds.contains(model.id)
                let isActive = activeWhisperModel == model.fileName
                let isDownloading = downloader.downloadingModelId == model.id
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(model.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                
                                if isActive {
                                    Text("Active Model")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.emerald.opacity(0.2))
                                        .foregroundColor(.emerald)
                                        .cornerRadius(4)
                                } else if isDownloaded {
                                    Text("Downloaded")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(ThemeColors.secondary(colorTheme).opacity(0.2))
                                        .foregroundColor(ThemeColors.secondary(colorTheme))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text("\(model.sizeMB) MB • \(model.description)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isDownloading {
                            Button("Cancel") {
                                downloader.cancelDownload()
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                        } else if isDownloaded {
                            if !isActive {
                                Button("Set Active") {
                                    activeWhisperModel = model.fileName
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ThemeColors.secondary(colorTheme))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                        } else {
                            Button(action: { downloader.startDownload(model: model) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download (\(model.sizeMB) MB)")
                                }
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(primaryAccent)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if isDownloading {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: downloader.downloadProgress)
                                .accentColor(primaryAccent)
                            Text("Downloading from HuggingFace... \(Int(downloader.downloadProgress * 100))%")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(Color.cardBackground(isDarkMode))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? Color.emerald.opacity(0.4) : Color.subtleBorder(isDarkMode), lineWidth: 1)
                )
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Section 2: Gemma 3 Local AI Assistant Model
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(primaryAccent)
                            Text(gemmaDownloader.defaultModel.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            if gemmaDownloader.isDownloaded {
                                Text("Downloaded")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.emerald.opacity(0.2))
                                    .foregroundColor(.emerald)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text("\(gemmaDownloader.defaultModel.sizeMB) MB • \(gemmaDownloader.defaultModel.description)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if gemmaDownloader.isDownloading {
                        Button("Cancel") {
                            gemmaDownloader.cancelDownload()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(primaryAccent)
                    } else if gemmaDownloader.isDownloaded {
                        Button("Delete") {
                            gemmaDownloader.deleteModel()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.red)
                    } else {
                        Button(action: { gemmaDownloader.startDownload() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download (1.6 GB)")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(primaryAccent)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if gemmaDownloader.isDownloading {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: gemmaDownloader.downloadProgress)
                            .accentColor(primaryAccent)
                        Text(gemmaDownloader.statusMessage)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(gemmaDownloader.isDownloaded ? Color.emerald.opacity(0.4) : Color.subtleBorder(isDarkMode), lineWidth: 1)
            )
        }
    }
    
    private var cloudSyncTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LOCAL VAULT STORAGE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text("Stored safely on disk in ~/Library/Application Support/com.whispnotes.app/notes.json.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(12)
            
            HStack(spacing: 12) {
                Button(action: exportBackup) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Export Vault Backup (JSON)")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ThemeColors.secondary(colorTheme))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: importBackup) {
                    HStack {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("Restore Vault Backup")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground(isDarkMode))
                    .foregroundColor(primaryAccent)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(primaryAccent.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var audioDevicesTabContent: some View {
        VStack(spacing: 16) {
            // Microphone selection card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(primaryAccent)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MICROPHONE INPUT DEVICE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedInputMicrophone) {
                            ForEach(deviceManager.inputDevices, id: \.self) { mic in
                                Text(mic).tag(mic)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(12)
            
            // Speaker selection card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(primaryAccent)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AUDIO OUTPUT SPEAKER")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedOutputSpeaker) {
                            ForEach(deviceManager.outputDevices, id: \.self) { speaker in
                                Text(speaker).tag(speaker)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(12)
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "Export Vault Backup"
        panel.nameFieldStringValue = "whispnotes_backup_\(Int(Date().timeIntervalSince1970)).json"
        panel.allowedContentTypes = [UTType.json]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                NotesDataManager.shared.saveNotes(notes)
                if let data = try? JSONEncoder().encode(notes) {
                    try? data.write(to: url)
                }
            }
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.title = "Restore Vault Backup"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
                if let restored = try? JSONDecoder().decode([NoteItem].self, from: data) {
                    notes = restored
                    NotesDataManager.shared.saveNotes(notes)
                }
            }
        }
    }
}
