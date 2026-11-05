import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Modal View
enum SettingsTab: String, CaseIterable, Identifiable {
    case preferences = "Preferences"
    case typography = "Editor"
    case aiProvider = "AI Provider"
    case cloudSync = "Cloud Sync & Vault"
    case audioDevices = "Audio & Recording"
    case labs = "Experimental Labs"
    case updates = "Updates & About"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .preferences: return "gearshape"
        case .typography: return "character.cursor.ibeam"
        case .aiProvider: return "sparkles"
        case .cloudSync: return "folder.badge.gearshape"
        case .audioDevices: return "mic"
        case .labs: return "flask.fill"
        case .updates: return "arrow.triangle.2.circlepath.circle"
        }
    }
}

struct SettingsModalView: View {
    @Binding var isOpen: Bool
    @Binding var notes: [NoteItem]
    /// The tab shown when Settings opens.
    var initialTab: SettingsTab = .preferences
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("colorTheme") private var colorTheme = "Classic Minimal"
    @AppStorage("editorFontSize") private var editorFontSize = 14.0
    @AppStorage("editorFontDesign") private var editorFontDesign = "Sans-Serif"
    @AppStorage("defaultSpeakerTemplate") private var defaultSpeakerTemplate = "Speaker 1 / Speaker 2"
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "Auto-Detect Language"
    @AppStorage("whisperModelSize") private var whisperModelSize = "Base (Recommended)"
    @AppStorage("activeWhisperModel") private var activeWhisperModel = "ggml-base.bin"
    @AppStorage("selectedInputMicrophone") private var selectedInputMicrophone = "Default System Microphone"
    @AppStorage("selectedOutputSpeaker") private var selectedOutputSpeaker = "Default System Speaker"
    @AppStorage("enableVimMode") private var enableVimMode = false
    @AppStorage("enableEmacsMode") private var enableEmacsMode = false
    @AppStorage("enableOrgTableAlign") private var enableOrgTableAlign = true
    @AppStorage("enableOrgTaskCycle") private var enableOrgTaskCycle = true
    @AppStorage("enableTypewriterScroll") private var enableTypewriterScroll = false
    @AppStorage("enableAIAutoTagging") private var enableAIAutoTagging = false
    
    @State private var showVimHelpSheet = false
    @State private var showEmacsHelpSheet = false
    @State private var selectedTab: SettingsTab = .preferences
    @AppStorage(EditorPreferenceKey.defaultViewMode) private var defaultViewMode: String = EditModeType.split.rawValue
    @AppStorage(EditorPreferenceKey.readingWidth) private var readingWidth: String = ReadingWidth.standard.rawValue
    @AppStorage(QuickRecordPreferenceKey.showInMenuBar) private var quickRecordInMenuBar = true
    @AppStorage(QuickRecordPreferenceKey.globalShortcut) private var quickRecordShortcut = true
    @StateObject private var deviceManager = AudioDeviceManager.shared
    @StateObject private var downloader = WhisperModelDownloader.shared
    @StateObject private var gemmaDownloader = GemmaModelDownloader.shared
    @StateObject private var updater = GitHubReleaseUpdater.shared

    var primaryAccent: Color {
        ThemeColors.primary(colorTheme)
    }
    
    private var onPrimaryAccentTextColor: Color {
        Color.onAccent(isDarkMode, themeName: colorTheme)
    }
    
    private var subtitleTextColor: Color {
        isDarkMode ? Color(red: 203/255, green: 213/255, blue: 225/255) : Color(red: 71/255, green: 85/255, blue: 105/255)
    }
    
    private var sectionHeaderTextColor: Color {
        isDarkMode ? Color(red: 148/255, green: 163/255, blue: 184/255) : Color(red: 100/255, green: 116/255, blue: 139/255)
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
                    Text("Settings")
                        .font(.headline)
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
                            .background(selectedTab == tab ? (isDarkMode ? Color.white.opacity(0.14) : primaryAccent.opacity(0.12)) : Color.clear)
                            .foregroundColor(selectedTab == tab ? (isDarkMode ? .white : primaryAccent) : (isDarkMode ? Color(red: 160/255, green: 174/255, blue: 192/255) : Color(red: 100/255, green: 116/255, blue: 139/255)))
                            .cornerRadius(AppRadius.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .frame(width: 200)
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
                            .foregroundColor(subtitleTextColor)
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
                        case .labs:
                            labsTabContent
                        case .updates:
                            updatesTabContent
                        }
                    }
                    .padding(20)
                }
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Bottom Action Row
                HStack {
                    Spacer()
                    
                    // Settings apply as you change them, so one button is enough.
                    Button(action: { isOpen = false }) {
                        Text("Done")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(onPrimaryAccentTextColor)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(primaryAccent)
                            .cornerRadius(AppRadius.md)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(14)
            }
            .background(Color.panelBackground(isDarkMode))
        }
        .adaptiveSheetFrame(width: 740, height: 520)
        .cornerRadius(AppRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
        )
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showVimHelpSheet) {
            VimHelpModalView(
                isPresented: $showVimHelpSheet,
                isDark: isDarkMode,
                primaryAccent: primaryAccent
            )
        }
        .sheet(isPresented: $showEmacsHelpSheet) {
            EmacsHelpModalView(
                isPresented: $showEmacsHelpSheet,
                isDark: isDarkMode,
                primaryAccent: primaryAccent
            )
        }
        .onAppear {
            selectedTab = initialTab
            deviceManager.refreshDevices()
            downloader.checkDownloadedModels()
        }
    }
    
    private var headerTitle: String {
        switch selectedTab {
        case .preferences: return "Preferences & Theme Presets"
        case .typography: return "Editor"
        case .aiProvider: return "AI Speech & Transcriber Engine"
        case .cloudSync: return "Vault Storage & Backup"
        case .audioDevices: return "Audio & Recording"
        case .labs: return "Experimental Features & Labs"
        case .updates: return "Software Updates & About"
        }
    }
    
    private var headerSubtitle: String {
        switch selectedTab {
        case .preferences: return "Manage dark mode, theme palettes, and default speaker tags."
        case .typography: return "How notes open, how wide text runs, and the editor font."
        case .aiProvider: return "Download offline Whisper GGUF models for local execution."
        case .cloudSync: return "Manage vault storage backup and JSON export."
        case .audioDevices: return "Microphone, speakers and Quick Record."
        case .labs: return "Test power-user GNU Emacs modal keybindings, Org-Mode tools, and typewriter scrolling."
        case .updates: return "Check for new versions, changelogs, and manage release updates."
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
                        .foregroundColor(subtitleTextColor)
                }
                
                Spacer()
                
                Toggle("", isOn: $isDarkMode)
                    .toggleStyle(.switch)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            
            // Card 2: Color Theme Presets with Live Swatches
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("COLOR THEME PALETTE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(sectionHeaderTextColor)
                    
                    Spacer()
                    
                    Text(colorTheme)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(primaryAccent)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(AppColorTheme.allCases) { theme in
                        ThemeSwatchButton(
                            theme: theme,
                            isSelected: colorTheme == theme.rawValue,
                            isDark: isDarkMode,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    colorTheme = theme.rawValue
                                }
                            }
                        )
                    }
                }
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)

            // Card 3: Speaker Naming Template
            VStack(alignment: .leading, spacing: 10) {
                Text("DEFAULT SPEAKER NAMING TEMPLATE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sectionHeaderTextColor)
                
                Picker("", selection: $defaultSpeakerTemplate) {
                    ForEach(speakerTemplates, id: \.self) { tpl in
                        Text(tpl).tag(tpl)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)

            // Card 4: Vim Keybindings & Modal Editing
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.title2)
                        .foregroundColor(primaryAccent)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Vim Keybindings & Modal Editing")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Navigate and edit notes using Vim Normal, Insert, Visual modes, and : command-line shortcuts.")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $enableVimMode)
                        .toggleStyle(.switch)
                }
                
                if enableVimMode {
                    Divider()
                        .background(Color.subtleBorder(isDarkMode))
                    
                    HStack {
                        Text("Includes :w (save), :q (close tab), :wq (save & close), :tabn, :set nu, and modal motions (h/j/k/l, w, b, dd, yy, p).")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                        
                        Spacer()
                        
                        Button(action: { showVimHelpSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.pages")
                                    .font(.caption)
                                Text("Cheat Sheet")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isDarkMode ? Color.white.opacity(0.14) : primaryAccent.opacity(0.12))
                            .foregroundColor(isDarkMode ? .white : primaryAccent)
                            .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
        }
    }

    /// Label on the left, switch pinned to the right edge, so stacked switches line up.
    private func settingsSwitchRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(subtitleTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var typographyTabContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("DEFAULT VIEW")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sectionHeaderTextColor)

                Picker("", selection: $defaultViewMode) {
                    Text("Edit").tag(EditModeType.edit.rawValue)
                    Text("Split").tag(EditModeType.split.rawValue)
                    Text("Preview").tag(EditModeType.preview.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Notes open this way. Notes with an attached PDF or slides open in the viewer, and empty notes always open in Edit.")
                    .font(.caption)
                    .foregroundColor(subtitleTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)

            VStack(alignment: .leading, spacing: 12) {
                Text("READING WIDTH")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sectionHeaderTextColor)

                Picker("", selection: $readingWidth) {
                    ForEach(ReadingWidth.allCases) { width in
                        Text(width.title).tag(width.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                ReadingWidthPreview(width: ReadingWidth(rawValue: readingWidth) ?? .standard, isDark: isDarkMode, accent: primaryAccent)

                Text("The widest a line of text gets in Edit and Preview. Narrower lines are easier to read; Full Width uses the whole pane.")
                    .font(.caption)
                    .foregroundColor(subtitleTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)

            VStack(alignment: .leading, spacing: 12) {
                Text("FONT SIZE (\(Int(editorFontSize)) pt)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sectionHeaderTextColor)
                
                Slider(value: $editorFontSize, in: 12...24, step: 1.0)
                    .accentColor(primaryAccent)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("FONT FAMILY DESIGN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sectionHeaderTextColor)
                
                Picker("", selection: $editorFontDesign) {
                    ForEach(fontDesigns, id: \.self) { design in
                        Text(design).tag(design)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
        }
    }
    
    private var aiProviderTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OFFLINE WHISPER GGUF MODELS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sectionHeaderTextColor)
                Text("Download Whisper models from HuggingFace to run 100% offline local transcription.")
                    .font(.caption)
                    .foregroundColor(subtitleTextColor)
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
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.emerald.opacity(0.2))
                                        .foregroundColor(.emerald)
                                        .cornerRadius(AppRadius.xs)
                                } else if isDownloaded {
                                    Text("Downloaded")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(ThemeColors.secondary(colorTheme).opacity(0.2))
                                        .foregroundColor(ThemeColors.secondary(colorTheme))
                                        .cornerRadius(AppRadius.xs)
                                }
                            }
                            
                            Text("\(model.sizeMB) MB • \(model.description)")
                                .font(.caption)
                                .foregroundColor(subtitleTextColor)
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
                                .background(isDarkMode ? Color.white.opacity(0.16) : Color.black.opacity(0.08))
                                .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                                .cornerRadius(AppRadius.sm)
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
                                .foregroundColor(onPrimaryAccentTextColor)
                                .cornerRadius(AppRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if isDownloading {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: downloader.downloadProgress)
                                .accentColor(primaryAccent)
                            Text("Downloading from HuggingFace... \(Int(downloader.downloadProgress * 100))%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(subtitleTextColor)
                        }
                    }
                }
                .padding(14)
                .background(Color.cardBackground(isDarkMode))
                .cornerRadius(AppRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
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
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.emerald.opacity(0.2))
                                    .foregroundColor(.emerald)
                                    .cornerRadius(AppRadius.xs)
                            }
                        }
                        
                        Text("\(gemmaDownloader.defaultModel.sizeMB) MB • \(gemmaDownloader.defaultModel.description)")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
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
                            .foregroundColor(onPrimaryAccentTextColor)
                            .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if gemmaDownloader.isDownloading {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: gemmaDownloader.downloadProgress)
                            .accentColor(primaryAccent)
                        Text(gemmaDownloader.statusMessage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(subtitleTextColor)
                    }
                }
            }
            .padding(14)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(gemmaDownloader.isDownloaded ? Color.emerald.opacity(0.4) : Color.subtleBorder(isDarkMode), lineWidth: 1)
            )
        }
    }
    
    private var cloudSyncTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LOCAL VAULT STORAGE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sectionHeaderTextColor)
                Text("Stored safely on disk in ~/Library/Application Support/com.whispnotes.app/notes.json.")
                    .font(.caption)
                    .foregroundColor(subtitleTextColor)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            
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
                    .background(primaryAccent)
                    .foregroundColor(onPrimaryAccentTextColor)
                    .cornerRadius(AppRadius.md)
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
                    .background(isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                    .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                    .cornerRadius(AppRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var audioDevicesTabContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "record.circle")
                        .foregroundColor(SemanticColor.record)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Record")
                            .font(.headline)
                        Text("Start a recording without switching away from your call.")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                }

                Divider().background(Color.subtleBorder(isDarkMode))

                settingsSwitchRow(
                    title: "Show in menu bar",
                    detail: "A waveform icon in the menu bar; it shows the elapsed time while recording.",
                    isOn: $quickRecordInMenuBar
                )

                settingsSwitchRow(
                    title: "Global shortcut \(GlobalHotKey.displayString)",
                    detail: "Works from any app. Records into the open note when WhispNotes is in front and that note has no recording yet; otherwise into a new note. Press again to stop and transcribe.",
                    isOn: $quickRecordShortcut
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)

            // Microphone selection card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(primaryAccent)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MICROPHONE INPUT DEVICE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(sectionHeaderTextColor)
                        
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
            .cornerRadius(AppRadius.lg)
            
            // Speaker selection card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(primaryAccent)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AUDIO OUTPUT SPEAKER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(sectionHeaderTextColor)
                        
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
            .cornerRadius(AppRadius.lg)
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

    // MARK: - Experimental Labs Tab
    private var labsTabContent: some View {
        VStack(spacing: 16) {
            // Card 1: GNU Emacs Keybindings & M-x Minibuffer
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "terminal.fill")
                        .font(.title2)
                        .foregroundColor(primaryAccent)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("GNU Emacs Modal Keybindings & M-x")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Navigate using C-a, C-e, C-f, C-b, C-p, C-n, kill-ring (C-k/C-y/M-y), C-x buffer chords, and M-x command runner.")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $enableEmacsMode)
                        .toggleStyle(.switch)
                }
                
                if enableEmacsMode {
                    Divider()
                        .background(Color.subtleBorder(isDarkMode))
                    
                    HStack {
                        Text("Includes Kill Ring stack, C-x C-s (save), C-x C-f (search), C-x b (buffer), and ⌥X (M-x minibuffer).")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                        
                        Spacer()
                        
                        Button(action: { showEmacsHelpSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.pages")
                                    .font(.caption)
                                Text("Cheat Sheet")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isDarkMode ? Color.white.opacity(0.14) : primaryAccent.opacity(0.12))
                            .foregroundColor(isDarkMode ? .white : primaryAccent)
                            .cornerRadius(AppRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)

            // Card 2: Org-Mode Productivity Tools
            VStack(alignment: .leading, spacing: 12) {
                Text("ORG-MODE PRODUCTIVITY SUITE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sectionHeaderTextColor)
                
                // Toggle 2A: Org-Table Auto-Alignment
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Org-Table Auto-Alignment on TAB")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Pressing TAB inside Markdown tables automatically recalculates column widths and formats pipes.")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    Spacer()
                    Toggle("", isOn: $enableOrgTableAlign)
                        .toggleStyle(.switch)
                }
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                // Toggle 2B: Org Task Cycling
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Task State Cycling (Ctrl-C Ctrl-C)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Quickly cycle task lines between [ ] (TODO), [-] (IN-PROGRESS), and [x] (DONE).")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    Spacer()
                    Toggle("", isOn: $enableOrgTaskCycle)
                        .toggleStyle(.switch)
                }
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)

            // Card 3: Typewriter Center Scrolling
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Typewriter Vertical Center Scrolling")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Locks your active cursor line at the vertical center of the editor canvas during long writing sessions.")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    Spacer()
                    Toggle("", isOn: $enableTypewriterScroll)
                        .toggleStyle(.switch)
                }
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)

            // Card 4: Local AI Auto-Tagging
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local AI Auto-Tagging on Save")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Gemma AI analyzes note contents on save and automatically proposes and inserts relevant #tags.")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    Spacer()
                    Toggle("", isOn: $enableAIAutoTagging)
                        .toggleStyle(.switch)
                }
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
        }
    }

    // MARK: - Updates & About Tab
    private var updatesTabContent: some View {
        VStack(spacing: 16) {
            // App Identity Card
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .fill(primaryAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(primaryAccent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("WhispNotes")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("v\(updater.currentVersion)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isDarkMode ? Color.white.opacity(0.16) : primaryAccent.opacity(0.12))
                            .foregroundColor(isDarkMode ? .white : primaryAccent)
                            .cornerRadius(AppRadius.xs)
                    }
                    
                    Text("Native Intelligent Lecture & Document Notes with Local AI & Vault Sync.")
                        .font(.caption)
                        .foregroundColor(subtitleTextColor)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
            )

            // Real-Time Release Status Card
            liveUpdateStatusCard

            // Auto-Update Configuration & Manual Check Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatic Update Checks")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Silently check for new versions on GitHub releases when WhispNotes launches.")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $updater.autoCheckForUpdates)
                        .toggleStyle(SwitchToggleStyle(tint: primaryAccent))
                }
                
                Divider()
                    .background(Color.subtleBorder(isDarkMode))
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Release Channel")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Public Stable Releases (GitHub: GIlbertoRCP/whispNotes)")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        updater.checkForUpdates(silent: false)
                    }) {
                        HStack(spacing: 6) {
                            if case .checking = updater.status {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(isCheckingForUpdates ? "Checking..." : "Check for Updates Now")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(onPrimaryAccentTextColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(primaryAccent)
                        .cornerRadius(AppRadius.md)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCheckingForUpdates)
                }
                
                if let lastCheck = updater.lastCheckDate {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(subtitleTextColor)
                        Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption2)
                            .foregroundColor(subtitleTextColor)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
            )

            // Support & Diagnostics Card
            HStack(spacing: 12) {
                Button(action: { WhispLogger.exportDiagnosticsBundle(notesCount: notes.count) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "ladybug.fill")
                        Text("Export Diagnostics Bundle")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(primaryAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(primaryAccent.opacity(0.12))
                    .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
                .help("Export local diagnostic logs for bug reports")
                
                Spacer()
                
                Button(action: { updater.openReleaseInBrowser() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                        Text("GitHub Releases")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text("Created for Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Real-Time Update Status Card
    @ViewBuilder
    private var liveUpdateStatusCard: some View {
        switch updater.status {
        case .checking:
            HStack(spacing: 14) {
                ProgressView()
                    .controlSize(.small)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Checking for Updates…")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Contacting GitHub releases repository…")
                        .font(.caption)
                        .foregroundColor(subtitleTextColor)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
            )
            
        case .updateAvailable(let release):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(primaryAccent.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(primaryAccent)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Available: \(release.tagName)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                        
                        Text("Published on \(release.formattedDate)")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    
                    Spacer()
                    
                    Button(action: { updater.showUpdateModal = true }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("View & Install")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(onPrimaryAccentTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(primaryAccent)
                        .cornerRadius(AppRadius.sm)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 8) {
                    Text("Current: v\(updater.currentVersion)")
                        .font(.caption2)
                        .foregroundColor(subtitleTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        .cornerRadius(AppRadius.xs)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(primaryAccent)
                    
                    Text("Latest: \(release.tagName)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(primaryAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryAccent.opacity(0.15))
                        .cornerRadius(AppRadius.xs)
                }
            }
            .padding(16)
            .background(primaryAccent.opacity(0.06))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(primaryAccent.opacity(0.35), lineWidth: 1)
            )
            
        case .upToDate:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.emerald.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.emerald)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're Up to Date")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(isDarkMode ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                        
                        Text("WhispNotes v\(updater.currentVersion) is currently the newest version.")
                            .font(.caption)
                            .foregroundColor(subtitleTextColor)
                    }
                    
                    Spacer()
                    
                    Text("Latest Release")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.emerald)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.emerald.opacity(0.14))
                        .cornerRadius(AppRadius.xs)
                }
                
                if let release = updater.latestRelease {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(.emerald)
                        Text("Verified on GitHub: \(release.tagName) (\(release.formattedDate))")
                            .font(.caption2)
                            .foregroundColor(subtitleTextColor)
                    }
                }
            }
            .padding(16)
            .background(Color.emerald.opacity(0.06))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.emerald.opacity(0.3), lineWidth: 1)
            )
            
        case .error(let msg):
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Check Incomplete")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(subtitleTextColor)
                }
                
                Spacer()
                
                Button(action: { updater.checkForUpdates(silent: false) }) {
                    Text("Retry")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(AppRadius.sm)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
            )
            
        default:
            // Idle state before first manual check
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("WhispNotes v\(updater.currentVersion)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Click 'Check for Updates Now' to verify with GitHub.")
                        .font(.caption)
                        .foregroundColor(subtitleTextColor)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.cardBackground(isDarkMode))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.subtleBorder(isDarkMode), lineWidth: 1)
            )
        }
    }
    
    private var isCheckingForUpdates: Bool {
        if case .checking = updater.status { return true }
        return false
    }
}

// MARK: - Theme Swatch Button Component
struct ThemeSwatchButton: View {
    let theme: AppColorTheme
    let isSelected: Bool
    let isDark: Bool
    let onSelect: () -> Void
    
    var definition: ThemeDefinition {
        ThemeLibrary.getDefinition(name: theme.rawValue, isDark: isDark)
    }
    
    var subtitle: String {
        switch theme {
        case .classicMinimal: return "Apple Slate Monochrome"
        case .obsidianBlack: return "Pitch & Cold Cyan"
        case .nordArctic: return "Polar Frost & Ice"
        case .midnightRose: return "Indigo & Crimson"
        case .rosePine: return "Lavender & Rose"
        case .slateMinimal: return "Sky & Emerald"
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Swatch Palette Preview Box
                ZStack {
                    // Mini Window Base
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(definition.appBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(definition.border, lineWidth: 1)
                        )
                    
                    // Elevated Card Preview with Accents
                    HStack(spacing: 6) {
                        // Diagonal split preview badge
                        ZStack {
                            Circle()
                                .fill(definition.primary)
                                .frame(width: 18, height: 18)
                            
                            Circle()
                                .fill(definition.secondary)
                                .frame(width: 12, height: 12)
                                .offset(x: 3, y: 3)
                        }
                        
                        // Mini preview lines
                        VStack(alignment: .leading, spacing: 3) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(definition.primary.opacity(0.85))
                                .frame(width: 32, height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(definition.secondary.opacity(0.65))
                                .frame(width: 20, height: 3)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(definition.cardBackgroundElevated)
                    .cornerRadius(AppRadius.xs)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.xs)
                            .stroke(definition.border, lineWidth: 0.5)
                    )
                    .padding(5)
                    
                    // High-contrast checkmark badge if selected
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(SemanticColor.success)
                                        .frame(width: 16, height: 16)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)
                            }
                            Spacer()
                        }
                        .padding(2)
                    }
                }
                .frame(height: 48)
                
                // Theme Name & Subtitle
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSelected ? definition.primary : (isDark ? .white : .black))
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .background(isSelected ? definition.primary.opacity(0.1) : Color.cardBackground(isDark))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(isSelected ? definition.primary : Color.subtleBorder(isDark), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Reading width preview
/// A tiny pane with text bars, so the choice is visible before closing Settings.
private struct ReadingWidthPreview: View {
    let width: ReadingWidth
    let isDark: Bool
    let accent: Color

    private var fraction: CGFloat {
        switch width {
        case .narrow: return 0.55
        case .standard: return 0.68
        case .wide: return 0.86
        case .full: return 1
        }
    }

    var body: some View {
        GeometryReader { geo in
            let column = (geo.size.width - 24) * fraction
            VStack(alignment: .leading, spacing: 5) {
                ForEach([1.0, 0.92, 0.97, 0.6], id: \.self) { line in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appTextSecondary(isDark).opacity(0.45))
                        .frame(width: column * line, height: 5)
                }
            }
            .frame(width: column, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .animation(AppAnimation.panel, value: width)
        }
        .frame(height: 52)
        .background(Color.panelBackground(isDark))
        .cornerRadius(AppRadius.sm)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(Color.subtleBorder(isDark), lineWidth: 1))
    }
}
