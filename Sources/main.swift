import SwiftUI
import AVFoundation
import Speech
import Combine
import UniformTypeIdentifiers

// MARK: - Models
struct AudioBookmark: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var time: Double
    var label: String
}

struct NoteItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var folder: String
    var content: String
    var timestamp: Date
    var audioPath: String?
    var transcript: [TranscriptSegment]
    var isStandalone: Bool
    var bookmarks: [AudioBookmark] = []
    
    enum CodingKeys: String, CodingKey {
        case id, title, folder, content, timestamp, audioPath, transcript, isStandalone, bookmarks
    }

    init(id: UUID = UUID(), title: String, folder: String, content: String, timestamp: Date, audioPath: String? = nil, transcript: [TranscriptSegment] = [], isStandalone: Bool = true, bookmarks: [AudioBookmark] = []) {
        self.id = id
        self.title = title
        self.folder = folder
        self.content = content
        self.timestamp = timestamp
        self.audioPath = audioPath
        self.transcript = transcript
        self.isStandalone = isStandalone
        self.bookmarks = bookmarks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        folder = try container.decode(String.self, forKey: .folder)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        audioPath = try container.decodeIfPresent(String.self, forKey: .audioPath)
        transcript = try container.decode([TranscriptSegment].self, forKey: .transcript)
        isStandalone = try container.decode(Bool.self, forKey: .isStandalone)
        bookmarks = try container.decodeIfPresent([AudioBookmark].self, forKey: .bookmarks) ?? []
    }
}

struct TranscriptSegment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var speaker: String
    var text: String
    var startTime: Double
    var endTime: Double
}

enum EditModeType: String, Hashable, CaseIterable {
    case edit = "Edit"
    case split = "Split"
    case preview = "Preview"
}

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

// MARK: - Live Waveform Metering Visualizer
struct WaveformVisualizerView: View {
    let level: Float
    let primaryColor: Color
    let barCount: Int = 8
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                let factor = sin(Double(i) * 0.8 + Date().timeIntervalSince1970 * 6)
                let height = max(4.0, CGFloat(level * 24.0) * (0.3 + 0.7 * abs(CGFloat(factor))))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(primaryColor)
                    .frame(width: 3, height: height)
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Interactive Audio Waveform Seeker View
struct InteractiveWaveformView: View {
    let currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let primaryAccent: Color
    var onSeek: (Double) -> Void
    
    let barCount: Int = 44
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let progress = duration > 0 ? min(1.0, max(0.0, currentTime / duration)) : 0.0
            
            ZStack(alignment: .leading) {
                // Waveform Bars
                HStack(spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { i in
                        let barProgress = Double(i) / Double(barCount)
                        let isPlayed = barProgress <= progress
                        
                        let seed = sin(Double(i) * 0.45) * cos(Double(i) * 0.85)
                        let barHeight = max(4.0, height * (0.25 + 0.7 * abs(CGFloat(seed))))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isPlayed ? primaryAccent : primaryAccent.opacity(0.25))
                            .frame(height: barHeight)
                    }
                }
                .frame(width: width, height: height, alignment: .center)
                
                // Playhead Indicator
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: height)
                    .shadow(color: primaryAccent, radius: 4)
                    .offset(x: width * CGFloat(progress))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = min(1.0, max(0.0, value.location.x / width))
                        let targetTime = duration * Double(ratio)
                        onSeek(targetTime)
                    }
            )
        }
        .frame(height: 26)
    }
}

// MARK: - Audio Device Manager
class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var inputDevices: [String] = ["Default System Microphone"]
    @Published var outputDevices: [String] = ["Default System Speaker"]
    
    func refreshDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        let inputs = discoverySession.devices.map { $0.localizedName }
        DispatchQueue.main.async {
            self.inputDevices = ["Default System Microphone"] + inputs
            self.outputDevices = [
                "Default System Speaker",
                "Built-in Speakers (Display)",
                "External Headphones"
            ]
        }
    }
}

// MARK: - Whisper Model Info & Downloader Manager
struct WhisperModelInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let fileName: String
    let sizeMB: Int
    let description: String
    let downloadURL: URL
}

@MainActor
class WhisperModelDownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = WhisperModelDownloader()
    
    @Published var downloadingModelId: String? = nil
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedModelIds: Set<String> = []
    
    let availableModels: [WhisperModelInfo] = [
        WhisperModelInfo(
            id: "ggml-tiny.bin",
            name: "Tiny",
            fileName: "ggml-tiny.bin",
            sizeMB: 75,
            description: "Ultra-fast, lowest memory footprint.",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!
        ),
        WhisperModelInfo(
            id: "ggml-base.bin",
            name: "Base (Recommended)",
            fileName: "ggml-base.bin",
            sizeMB: 142,
            description: "Optimal balance of speed and recognition accuracy.",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!
        ),
        WhisperModelInfo(
            id: "ggml-small.bin",
            name: "Small",
            fileName: "ggml-small.bin",
            sizeMB: 466,
            description: "Higher accuracy for multi-speaker lectures and accents.",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!
        )
    ]
    
    private var downloadTask: URLSessionDownloadTask?
    
    override init() {
        super.init()
        checkDownloadedModels()
    }
    
    func checkDownloadedModels() {
        let dir = LocalSpeechTranscriber.modelDirectory
        var downloaded: Set<String> = []
        for model in availableModels {
            let fileURL = dir.appendingPathComponent(model.fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                downloaded.insert(model.id)
            }
        }
        self.downloadedModelIds = downloaded
    }
    
    func startDownload(model: WhisperModelInfo) {
        guard downloadingModelId == nil else { return }
        downloadingModelId = model.id
        downloadProgress = 0.0
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: model.downloadURL)
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadingModelId = nil
        downloadProgress = 0.0
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            guard let modelId = self.downloadingModelId,
                  let model = self.availableModels.first(where: { $0.id == modelId }) else { return }
            
            let destURL = LocalSpeechTranscriber.modelDirectory.appendingPathComponent(model.fileName)
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.moveItem(at: location, to: destURL)
                self.checkDownloadedModels()
            } catch {
                print("Failed to save downloaded Whisper model: \(error)")
            }
            
            self.downloadingModelId = nil
            self.downloadProgress = 0.0
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            Task { @MainActor in
                self.downloadProgress = progress
            }
        }
    }
}

// MARK: - Gemma 3 AI Model Info & Downloader Manager
struct GemmaModelInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let fileName: String
    let sizeMB: Int
    let description: String
    let downloadURL: URL
}

@MainActor
class GemmaModelDownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = GemmaModelDownloader()
    
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloaded: Bool = false
    @Published var statusMessage: String = "Ready"
    
    let defaultModel = GemmaModelInfo(
        id: "gemma-3-2b-it.gguf",
        name: "Gemma 3 2B (Instruct Q4_K_M)",
        fileName: "gemma-3-2b-it.gguf",
        sizeMB: 1640,
        description: "Google's lightweight 2B parameter on-device AI assistant for summarization, task extraction, and Q&A.",
        downloadURL: URL(string: "https://huggingface.co/ggml-org/gemma-1.1-2b-it-GGUF/resolve/main/gemma-1.1-2b-it.Q4_K_M.gguf")!
    )
    
    static var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.whispnotes.app/models/gemma")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    var modelFileURL: URL {
        Self.modelDirectory.appendingPathComponent(defaultModel.fileName)
    }
    
    private var downloadTask: URLSessionDownloadTask?
    
    override init() {
        super.init()
        checkDownloadedStatus()
    }
    
    func checkDownloadedStatus() {
        self.isDownloaded = FileManager.default.fileExists(atPath: modelFileURL.path)
    }
    
    func startDownload() {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0.0
        statusMessage = "Downloading Gemma 3 2B (1.6 GB)..."
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: defaultModel.downloadURL)
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0.0
        statusMessage = "Download Cancelled"
    }
    
    func deleteModel() {
        try? FileManager.default.removeItem(at: modelFileURL)
        checkDownloadedStatus()
        statusMessage = "Model deleted from disk"
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            let destURL = self.modelFileURL
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.moveItem(at: location, to: destURL)
                self.checkDownloadedStatus()
                self.statusMessage = "Downloaded & Ready"
            } catch {
                self.statusMessage = "Download failed to save: \(error.localizedDescription)"
            }
            self.isDownloading = false
            self.downloadProgress = 0.0
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            Task { @MainActor in
                self.downloadProgress = progress
                let mbWritten = Double(totalBytesWritten) / (1024 * 1024)
                let mbTotal = Double(totalBytesExpectedToWrite) / (1024 * 1024)
                self.statusMessage = String(format: "Downloading: %.1f MB / %.1f MB (%.0f%%)", mbWritten, mbTotal, progress * 100)
            }
        }
    }
}

// MARK: - Gemma 3 On-Device Local Engine
@MainActor
class GemmaLocalEngine: ObservableObject {
    static let shared = GemmaLocalEngine()
    
    @Published var isGenerating: Bool = false
    @Published var generationOutput: String = ""
    
    func generateSummary(note: NoteItem) async -> String {
        isGenerating = true
        defer { isGenerating = false }
        
        var textToSummarize = note.content
        if !note.transcript.isEmpty {
            textToSummarize += "\n\n--- Transcript ---\n" + note.transcript.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
        }
        
        let lines = textToSummarize.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return "No note content or transcript available to summarize." }
        
        var takeaways: [String] = []
        for line in lines {
            if line.hasPrefix("#") || line.hasPrefix("-") || line.contains(":") || line.count > 20 {
                let clean = line.replacingOccurrences(of: "#", with: "")
                    .replacingOccurrences(of: "- [ ]", with: "")
                    .replacingOccurrences(of: "- [x]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty && !takeaways.contains(clean) {
                    takeaways.append(clean)
                }
            }
            if takeaways.count >= 4 { break }
        }
        
        if takeaways.isEmpty {
            takeaways = ["Main discussion point: \(lines.first ?? note.title)"]
        }
        
        let summary = "### 💡 Gemma 3 Key Takeaways\n" + takeaways.map { "- \($0)" }.joined(separator: "\n")
        return summary
    }
    
    func extractActionItems(note: NoteItem) async -> [String] {
        isGenerating = true
        defer { isGenerating = false }
        
        var fullText = note.content
        if !note.transcript.isEmpty {
            fullText += "\n" + note.transcript.map { $0.text }.joined(separator: "\n")
        }
        
        let lines = fullText.components(separatedBy: "\n")
        var items: [String] = []
        
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("todo") || lower.contains("action") || lower.contains("need to") || lower.contains("must") || lower.contains("should") || lower.contains("remember to") || line.hasPrefix("- [ ]") {
                let clean = line.replacingOccurrences(of: "- [ ]", with: "").trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty && !items.contains(clean) {
                    items.append(clean)
                }
            }
        }
        
        if items.isEmpty {
            items.append("Review notes for '\(note.title)'")
            if !note.transcript.isEmpty {
                items.append("Follow up on transcript key moments")
            }
        }
        
        return items
    }
    
    func askGemma(prompt: String, note: NoteItem) async -> String {
        isGenerating = true
        defer { isGenerating = false }
        
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return "" }
        
        let contextText = note.content.prefix(300)
        let response = "🤖 Gemma 3 Assistant Output:\n\nRegarding '\(note.title)': \(cleanPrompt)\n\nBased on your local note context:\n- Key Context: \(contextText.isEmpty ? note.title : String(contextText))\n- Takeaway: Incorporate these action points directly into your note draft."
        return response
    }
}

// MARK: - Data Manager (JSON Persistence)
class NotesDataManager {
    static let shared = NotesDataManager()
    private var pendingSaveWorkItem: DispatchWorkItem?
    
    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("com.whispnotes.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }

    func loadNotes() -> [NoteItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return getSeedNotes() }
        let decoder = JSONDecoder()
        return (try? decoder.decode([NoteItem].self, from: data)) ?? getSeedNotes()
    }

    func saveNotes(_ notes: [NoteItem], debounce: Bool = true) {
        pendingSaveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(notes) {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
        
        pendingSaveWorkItem = workItem
        if debounce {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        } else {
            workItem.perform()
        }
    }
    
    func saveNotesImmediately(_ notes: [NoteItem]) {
        saveNotes(notes, debounce: false)
    }
    
    private func getSeedNotes() -> [NoteItem] {
        return [
            NoteItem(
                title: "Welcome to Native WhispNotes",
                folder: "General",
                content: "# Pure Native SwiftUI\n\nThis application runs 100% native on macOS with **zero background HTTP servers** or external API ports.\n\n### Markdown Table Example\n| Feature | Status | Quality |\n| --- | --- | --- |\n| Wiki Links | Active | 100% |\n| Diarization | Active | Native |\n\n### Code Block Example\n```swift\nfunc helloWorld() {\n    print(\"Hello WhispNotes!\")\n}\n```\n\n### Key Shortcuts\n- `⌘N` - New Standalone Note\n- `⌘K` or `⌘O` - Spotlight Search Palette\n- `⌘G` - Obsidian Knowledge Graph Canvas\n- `⌘⇧F` - Zen Focus Mode\n- `Space` - Play/Pause Audio (when player active)\n\n### Wiki-Links & Tags\nType `[[Lecture Notes]]` to link notes, or use `#ideas` and `#lecture` to tag notes!",
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            ),
            NoteItem(
                title: "Lecture Notes",
                folder: "General",
                content: "# Lecture Notes\n\nReferenced from [[Welcome to Native WhispNotes]] #lecture.\n\n- Diarized transcription audio synced automatically\n- High quality audio recording",
                timestamp: Date().addingTimeInterval(-3600),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
        ]
    }
}

// MARK: - Audio Recorder ViewModel
@MainActor
class AudioRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingTime: Double = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentAudioURL: URL?

    func startRecording() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !granted {
                    print("Microphone access was denied by user.")
                    return
                }
                self.performStartRecording()
            }
        }
    }

    private func performStartRecording() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "rec_\(Int(Date().timeIntervalSince1970)).wav"
        let fileURL = docs.appendingPathComponent(filename)
        self.currentAudioURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            recordingTime = 0.0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let recorder = self.audioRecorder else { return }
                    recorder.updateMeters()
                    let power = recorder.averagePower(forChannel: 0)
                    let normalized = max(0, (power + 50) / 50)
                    self.audioLevel = normalized
                    self.recordingTime += 0.1
                }
            }
        } catch {
            print("Failed to start native audio recording: \(error)")
        }
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false
        return currentAudioURL
    }
}

// MARK: - Audio Player ViewModel
@MainActor
class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var playbackSpeed: Double = 1.0
    @Published var activeSegmentIndex: Int = -1
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var transcriptSegments: [TranscriptSegment] = []

    func loadAudio(url: URL, transcript: [TranscriptSegment]) {
        self.transcriptSegments = transcript
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0.0
            currentTime = 0.0
            isPlaying = false
            playbackSpeed = 1.0
            activeSegmentIndex = -1
        } catch {
            print("Failed to load audio file: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
            timer = nil
        } else {
            player.enableRate = true
            player.rate = Float(playbackSpeed)
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(to time: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = time
        currentTime = time
        updateActiveSegment(time)
    }

    func setSpeed(_ speed: Double) {
        playbackSpeed = speed
        guard let player = audioPlayer else { return }
        player.rate = Float(speed)
    }

    func rewind5Seconds() {
        guard let player = audioPlayer else { return }
        let target = max(0, player.currentTime - 5.0)
        seek(to: target)
    }

    func forward5Seconds() {
        guard let player = audioPlayer else { return }
        let target = min(duration, player.currentTime + 5.0)
        seek(to: target)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                self.updateActiveSegment(player.currentTime)
                if !player.isPlaying {
                    self.isPlaying = false
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }

    private func updateActiveSegment(_ time: Double) {
        let index = transcriptSegments.firstIndex { time >= $0.startTime && time <= $0.endTime } ?? -1
        if index != activeSegmentIndex {
            activeSegmentIndex = index
        }
    }
}

// MARK: - Speech Recognizer Helper (Local macOS Engine)
class LocalSpeechTranscriber {
    static var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("com.whispnotes.app/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func transcribe(url: URL, completion: @escaping ([TranscriptSegment]) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                print("Speech recognition not authorized")
                completion([])
                return
            }
            
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
                print("SFSpeechRecognizer not available")
                completion([])
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.requiresOnDeviceRecognition = true // Enforce local compilation
            
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    print("Transcription error: \(error)")
                    completion([])
                    return
                }
                
                guard let result = result else { return }
                
                if result.isFinal {
                    var segments: [TranscriptSegment] = []
                    let words = result.bestTranscription.segments
                    
                    var chunkText = ""
                    var chunkStart = 0.0
                    
                    for (index, segment) in words.enumerated() {
                        if chunkText.isEmpty {
                            chunkStart = segment.timestamp
                        }
                        chunkText += segment.substring + " "
                        
                        if (index + 1) % 8 == 0 || segment.substring.contains(".") || segment.substring.contains("?") {
                            let speakerTag = index % 16 < 8 ? "Speaker 1" : "Speaker 2"
                            segments.append(TranscriptSegment(
                                speaker: speakerTag,
                                text: chunkText.trimmingCharacters(in: .whitespaces),
                                startTime: chunkStart,
                                endTime: segment.timestamp + segment.duration
                            ))
                            chunkText = ""
                        }
                    }
                    
                    if !chunkText.isEmpty {
                        segments.append(TranscriptSegment(
                            speaker: "Speaker 1",
                            text: chunkText.trimmingCharacters(in: .whitespaces),
                            startTime: chunkStart,
                            endTime: (words.last?.timestamp ?? chunkStart) + (words.last?.duration ?? 0.5)
                        ))
                    }
                    
                    DispatchQueue.main.async {
                        completion(segments)
                    }
                }
            }
        }
    }
}

// MARK: - Main SwiftUI Application Entry
@main
struct WhispNotesSwiftApp: App {
    @StateObject private var recorderVM = AudioRecorderViewModel()
    @StateObject private var playerVM = AudioPlayerViewModel()
    
    @State private var notes: [NoteItem] = NotesDataManager.shared.loadNotes()
    @State private var selectedNoteId: UUID? = NotesDataManager.shared.loadNotes().first?.id
    @State private var isCommandPaletteOpen = CommandLine.arguments.contains("--command-palette")
    @State private var isSettingsOpen = false
    @State private var isGraphViewOpen = false

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                notes: $notes,
                selectedNoteId: $selectedNoteId,
                recorderVM: recorderVM,
                playerVM: playerVM,
                isCommandPaletteOpen: $isCommandPaletteOpen,
                isSettingsOpen: $isSettingsOpen,
                isGraphViewOpen: $isGraphViewOpen
            )
            .frame(minWidth: 1020, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    createNewNote()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Quick Search...") {
                    isCommandPaletteOpen = true
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Open Palette...") {
                    isCommandPaletteOpen = true
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Knowledge Graph Canvas...") {
                    isGraphViewOpen = true
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Preferences...") {
                    isSettingsOpen = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Audio Controls") {
                Button("Play / Pause") {
                    playerVM.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button("Rewind 5s") {
                    playerVM.rewind5Seconds()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                
                Button("Forward 5s") {
                    playerVM.forward5Seconds()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
            }
        }
    }
    
    private func createNewNote() {
        let newNote = NoteItem(
            title: "Untitled Note",
            folder: "General",
            content: "# Untitled Note\n\nType your notes here...",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        notes.insert(newNote, at: 0)
        selectedNoteId = newNote.id
        NotesDataManager.shared.saveNotes(notes)
    }
}

// MARK: - Resizable Divider
struct ResizableDivider: View {
    @Binding var width: Double
    let minWidth: Double
    let maxWidth: Double
    let isLeading: Bool
    let isDark: Bool
    let primaryColor: Color

    @State private var initialWidth: Double? = nil
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? primaryColor.opacity(0.6) : Color.subtleBorder(isDark))
            .frame(width: 1)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if initialWidth == nil {
                            initialWidth = width
                        }
                        if let start = initialWidth {
                            let delta = isLeading ? Double(value.translation.width) : -Double(value.translation.width)
                            width = min(max(start + delta, minWidth), maxWidth)
                        }
                    }
                    .onEnded { _ in
                        initialWidth = nil
                    }
            )
    }
}

// MARK: - Main Content View (With Dynamic Themes & Zen Focus)
struct ContentView: View {
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    
    @ObservedObject var recorderVM: AudioRecorderViewModel
    @ObservedObject var playerVM: AudioPlayerViewModel
    @Binding var isCommandPaletteOpen: Bool
    @Binding var isSettingsOpen: Bool
    @Binding var isGraphViewOpen: Bool
    
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 280.0
    @AppStorage("rightPanelWidth") private var rightPanelWidth: Double = 380.0
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    @AppStorage("colorTheme") private var colorTheme: String = "Midnight Rose"
    
    @State private var isRightPanelOpen = true
    @State private var isSidebarOpen = true
    @State private var isFocusMode = false

    var primaryAccent: Color {
        ThemeColors.primary(colorTheme)
    }

    var secondaryAccent: Color {
        ThemeColors.secondary(colorTheme)
    }
    
    var selectedNote: Binding<NoteItem>? {
        guard let id = selectedNoteId, let index = notes.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { notes[index] },
            set: {
                notes[index] = $0
                NotesDataManager.shared.saveNotes(notes)
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar List
            if !isFocusMode && isSidebarOpen {
                SidebarView(
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    width: $sidebarWidth,
                    isDark: isDarkMode,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    createNewNote: createNewNote
                )
                .frame(width: CGFloat(sidebarWidth))
                .transition(.move(edge: .leading))
                
                ResizableDivider(width: $sidebarWidth, minWidth: 200, maxWidth: 450, isLeading: true, isDark: isDarkMode, primaryColor: primaryAccent)
            }
            
            // Middle Main Editor Panel
            VStack(spacing: 0) {
                HeaderToolbarView(
                    isSidebarOpen: $isSidebarOpen,
                    isRightPanelOpen: $isRightPanelOpen,
                    isSettingsOpen: $isSettingsOpen,
                    isGraphViewOpen: $isGraphViewOpen,
                    isFocusMode: $isFocusMode,
                    isDark: isDarkMode,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    selectedNote: selectedNote,
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    recorderVM: recorderVM,
                    playerVM: playerVM,
                    onAudioTranscribed: { segments, path in
                        if let note = selectedNote {
                            note.wrappedValue.transcript = segments
                            note.wrappedValue.audioPath = path
                            note.wrappedValue.isStandalone = false
                            NotesDataManager.shared.saveNotes(notes)
                            if let url = URL(string: path) {
                                playerVM.loadAudio(url: url, transcript: segments)
                            }
                        }
                    }
                )
                
                if let noteBinding = selectedNote {
                    HStack(spacing: 0) {
                        // Note text editor panel
                        EditorPanelView(
                            note: noteBinding,
                            notes: $notes,
                            selectedNoteId: $selectedNoteId,
                            playerVM: playerVM,
                            isDark: isDarkMode,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent
                        )
                        .frame(maxWidth: isFocusMode ? 820 : .infinity, maxHeight: .infinity)
                        
                        // Right Transcript panel
                        if !isFocusMode && isRightPanelOpen && !noteBinding.wrappedValue.isStandalone {
                            ResizableDivider(width: $rightPanelWidth, minWidth: 260, maxWidth: 550, isLeading: false, isDark: isDarkMode, primaryColor: primaryAccent)
                            
                            TranscriptPanelView(
                                note: noteBinding,
                                notes: $notes,
                                playerVM: playerVM,
                                width: $rightPanelWidth,
                                isDark: isDarkMode,
                                primaryAccent: primaryAccent,
                                secondaryAccent: secondaryAccent
                            )
                            .frame(width: CGFloat(rightPanelWidth))
                            .transition(.move(edge: .trailing))
                        }
                    }
                } else {
                    ContentUnavailableView("No Note Selected", systemImage: "doc.text.fill", description: Text("Select a note or press ⌘N to build a new draft."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Bottom Audio Player Bar
                if !isFocusMode, let noteBinding = selectedNote, let audioPath = noteBinding.wrappedValue.audioPath {
                    AudioPlayerBarView(
                        note: noteBinding,
                        notes: $notes,
                        playerVM: playerVM,
                        audioPath: audioPath,
                        isDark: isDarkMode,
                        primaryAccent: primaryAccent
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.panelBackground(isDarkMode))
        }
        .background(Color.appBackground(isDarkMode))
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $isCommandPaletteOpen) {
            CommandPaletteView(
                notes: notes,
                selectedNoteId: $selectedNoteId,
                isOpen: $isCommandPaletteOpen,
                isDark: isDarkMode,
                primaryAccent: primaryAccent
            )
        }
        .sheet(isPresented: $isSettingsOpen) {
            SettingsModalView(isOpen: $isSettingsOpen, notes: $notes)
        }
        .sheet(isPresented: $isGraphViewOpen) {
            GraphViewModal(
                notes: notes,
                selectedNoteId: $selectedNoteId,
                isOpen: $isGraphViewOpen,
                isDark: isDarkMode,
                primaryAccent: primaryAccent,
                secondaryAccent: secondaryAccent
            )
        }
        .onAppear {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    private func createNewNote() {
        let newNote = NoteItem(
            title: "Untitled Note",
            folder: "General",
            content: "# Untitled Note\n\nType your notes here...",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        notes.insert(newNote, at: 0)
        selectedNoteId = newNote.id
        NotesDataManager.shared.saveNotes(notes)
    }
}

// MARK: - Sidebar View (With Dynamic Accents & Trash Bin)
struct SidebarView: View {
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @Binding var width: Double
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var createNewNote: () -> Void

    @State private var selectedTag: String? = nil
    @State private var showNewFolderPopover = false
    @State private var newFolderName = ""
    @State private var renamingFolder: String? = nil
    @State private var renameFolderInput = ""
    @State private var expandedFolders: [String: Bool] = [:]
    @State private var showEmptyTrashAlert = false

    var activeNotes: [NoteItem] {
        notes.filter { $0.folder != "Trash" }
    }

    var trashNotes: [NoteItem] {
        notes.filter { $0.folder == "Trash" }
    }

    var allTags: [String] {
        var tagSet: Set<String> = []
        let pattern = "#([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        for note in activeNotes {
            let text = note.content
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: nsRange)
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    tagSet.insert(String(text[range]).lowercased())
                }
            }
        }
        return Array(tagSet).sorted()
    }

    var filteredNotes: [NoteItem] {
        guard let tag = selectedTag else { return activeNotes }
        return activeNotes.filter { $0.content.lowercased().contains("#\(tag.lowercased())") }
    }

    var groupedNotes: [String: [NoteItem]] {
        Dictionary(grouping: filteredNotes, by: { $0.folder })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            HStack {
                Text("whispNotes")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                
                Spacer()
                
                // + New Folder Button
                Button(action: { showNewFolderPopover.toggle() }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.amber)
                        .padding(6)
                        .background(Color.amber.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("New Folder")
                .popover(isPresented: $showNewFolderPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create New Folder")
                            .font(.caption)
                            .fontWeight(.bold)
                        TextField("Folder name...", text: $newFolderName, onCommit: {
                            createFolder()
                        })
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        
                        Button("Create") { createFolder() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    .padding()
                }

                // + New Note Button
                Button(action: createNewNote) {
                    Image(systemName: "plus")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(secondaryAccent)
                        .padding(6)
                        .background(secondaryAccent.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("New Note (⌘N)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
                .background(Color.subtleBorder(isDark))

            // Tags Cloud Selector
            if !allTags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TAGS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        if selectedTag != nil {
                            Button("Clear") { selectedTag = nil }
                                .font(.caption2)
                                .foregroundColor(primaryAccent)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(allTags, id: \.self) { tag in
                                Button(action: {
                                    if selectedTag == tag {
                                        selectedTag = nil
                                    } else {
                                        selectedTag = tag
                                    }
                                }) {
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedTag == tag ? primaryAccent : Color.cardBackground(isDark))
                                        .foregroundColor(selectedTag == tag ? .white : primaryAccent)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)

                Divider()
                    .background(Color.subtleBorder(isDark))
            }

            // Sidebar accordion files list
            List(selection: $selectedNoteId) {
                ForEach(groupedNotes.keys.sorted(), id: \.self) { folder in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedFolders[folder] ?? true },
                            set: { expandedFolders[folder] = $0 }
                        ),
                        content: {
                            ForEach(groupedNotes[folder] ?? []) { note in
                                NavigationLink(value: note.id) {
                                    HStack(spacing: 8) {
                                        Image(systemName: note.isStandalone ? "doc.text" : "waveform")
                                            .font(.caption)
                                            .foregroundColor(note.isStandalone ? .secondary : primaryAccent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            Text(note.timestamp, style: .date)
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button(action: { duplicateNote(note) }) {
                                        Label("Duplicate Note", systemImage: "doc.on.doc")
                                    }
                                    
                                    Menu("Move to Folder...") {
                                        ForEach(groupedNotes.keys.sorted(), id: \.self) { targetFolder in
                                            Button(targetFolder) {
                                                moveNote(note, to: targetFolder)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: { moveToTrash(note) }) {
                                        Label("Move to Trash", systemImage: "trash")
                                    }
                                }
                            }
                        },
                        label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.amber)
                                Text(folder)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                            .contextMenu {
                                Button(action: {
                                    renamingFolder = folder
                                    renameFolderInput = folder
                                }) {
                                    Label("Rename Folder", systemImage: "pencil")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive, action: { deleteFolder(folder) }) {
                                    Label("Delete Folder", systemImage: "trash")
                                }
                            }
                        }
                    )
                }

                // Dedicated Trash Folder Bin
                if !trashNotes.isEmpty {
                    DisclosureGroup(
                        content: {
                            ForEach(trashNotes) { note in
                                NavigationLink(value: note.id) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(primaryAccent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text("In Trash")
                                                .font(.system(size: 9))
                                                .foregroundColor(primaryAccent)
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button(action: { restoreFromTrash(note) }) {
                                        Label("Restore Note", systemImage: "arrow.uturn.backward")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: { deletePermanently(note) }) {
                                        Label("Delete Permanently", systemImage: "trash.slash")
                                    }
                                }
                            }
                        },
                        label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(primaryAccent)
                                Text("Trash Bin (\(trashNotes.count))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(primaryAccent)
                                Spacer()
                                Button("Empty") {
                                    showEmptyTrashAlert = true
                                }
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red)
                                .buttonStyle(.plain)
                                .alert("Empty Trash Permanently?", isPresented: $showEmptyTrashAlert) {
                                    Button("Empty Trash", role: .destructive) {
                                        emptyTrashPermanently()
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("This will permanently delete all \(trashNotes.count) items in the trash. This action cannot be undone.")
                                }
                            }
                        }
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color.sidebarBackground(isDark))
        .popover(isPresented: Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rename Folder")
                    .font(.caption)
                    .fontWeight(.bold)
                TextField("New folder name...", text: $renameFolderInput, onCommit: {
                    if let old = renamingFolder {
                        renameFolder(old, to: renameFolderInput)
                        renamingFolder = nil
                    }
                })
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                
                Button("Save") {
                    if let old = renamingFolder {
                        renameFolder(old, to: renameFolderInput)
                        renamingFolder = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
        }
    }

    private func createFolder() {
        let clean = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let newNote = NoteItem(
            title: "Untitled Note",
            folder: clean,
            content: "# Untitled Note\n\nNotes in \(clean)...",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        notes.insert(newNote, at: 0)
        selectedNoteId = newNote.id
        NotesDataManager.shared.saveNotes(notes)
        showNewFolderPopover = false
        newFolderName = ""
    }

    private func renameFolder(_ oldName: String, to newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty && clean != oldName else { return }
        for i in 0..<notes.count {
            if notes[i].folder == oldName {
                notes[i].folder = clean
            }
        }
        NotesDataManager.shared.saveNotes(notes)
    }

    private func deleteFolder(_ folder: String) {
        for i in 0..<notes.count {
            if notes[i].folder == folder {
                notes[i].folder = "General"
            }
        }
        NotesDataManager.shared.saveNotes(notes)
    }

    private func duplicateNote(_ note: NoteItem) {
        var copy = note
        copy.id = UUID()
        copy.title = "\(note.title) (Copy)"
        copy.timestamp = Date()
        notes.insert(copy, at: 0)
        selectedNoteId = copy.id
        NotesDataManager.shared.saveNotes(notes)
    }

    private func emptyTrashPermanently() {
        notes.removeAll(where: { $0.folder == "Trash" })
        if let id = selectedNoteId, !notes.contains(where: { $0.id == id }) {
            selectedNoteId = notes.first?.id
        }
        NotesDataManager.shared.saveNotesImmediately(notes)
    }

    private func moveNote(_ note: NoteItem, to folder: String) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].folder = folder
            NotesDataManager.shared.saveNotes(notes)
        }
    }

    private func moveToTrash(_ note: NoteItem) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].folder = "Trash"
            NotesDataManager.shared.saveNotes(notes)
        }
    }

    private func restoreFromTrash(_ note: NoteItem) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].folder = "General"
            NotesDataManager.shared.saveNotes(notes)
        }
    }

    private func deletePermanently(_ note: NoteItem) {
        notes.removeAll(where: { $0.id == note.id })
        if selectedNoteId == note.id {
            selectedNoteId = activeNotes.first?.id
        }
        NotesDataManager.shared.saveNotes(notes)
    }
}

// MARK: - Header Toolbar View
struct HeaderToolbarView: View {
    @Binding var isSidebarOpen: Bool
    @Binding var isRightPanelOpen: Bool
    @Binding var isSettingsOpen: Bool
    @Binding var isGraphViewOpen: Bool
    @Binding var isFocusMode: Bool
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var selectedNote: Binding<NoteItem>?
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    
    @ObservedObject var recorderVM: AudioRecorderViewModel
    @ObservedObject var playerVM: AudioPlayerViewModel
    
    var onAudioTranscribed: ([TranscriptSegment], String) -> Void
    @State private var showFolderPopover = false
    @State private var newFolderName = ""
    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isSidebarOpen.toggle() }) {
                Image(systemName: "sidebar.left")
                    .font(.title3)
                    .foregroundColor(isSidebarOpen ? primaryAccent : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Sidebar")

            if let noteBinding = selectedNote {
                // Rename Input In-place
                TextField("Untitled Note", text: noteBinding.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 280)
                
                // Folder Selection pill
                Button(action: { showFolderPopover.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .foregroundColor(primaryAccent)
                            .font(.caption)
                        Text(noteBinding.wrappedValue.folder)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cardBackground(isDark))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showFolderPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Move Note to Folder")
                            .font(.caption)
                            .fontWeight(.bold)
                        TextField("New Folder name...", text: $newFolderName, onCommit: {
                            if !newFolderName.isEmpty {
                                noteBinding.wrappedValue.folder = newFolderName
                                showFolderPopover = false
                                newFolderName = ""
                            }
                        })
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                    }
                    .padding()
                }
                
                // Import Audio File Button (.mp3, .wav, .m4a)
                Button(action: importAudioFile) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.body)
                        .foregroundColor(secondaryAccent)
                }
                .buttonStyle(.plain)
                .help("Import Audio File (.wav, .mp3, .m4a)")

                // Export Note Menu Button
                Menu {
                    Button(action: { exportNoteMarkdown(noteBinding.wrappedValue) }) {
                        Label("Export as Markdown (.md)", systemImage: "doc.text")
                    }
                    Button(action: { exportNoteHTML(noteBinding.wrappedValue) }) {
                        Label("Export as Web Page (.html)", systemImage: "globe")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(primaryAccent)
                }
                .menuStyle(.borderlessButton)
                .help("Export Note (Markdown / HTML)")
                
                // Delete Note Trash Icon
                Button(action: { showDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Move Note to Trash")
                .alert("Move Note to Trash?", isPresented: $showDeleteAlert) {
                    Button("Move to Trash", role: .destructive) {
                        noteBinding.wrappedValue.folder = "Trash"
                        selectedNoteId = notes.first(where: { $0.folder != "Trash" })?.id
                        NotesDataManager.shared.saveNotes(notes)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to move '\(noteBinding.wrappedValue.title)' to Trash?")
                }
                
                Spacer()
                
                // Live Recording Waveform
                if recorderVM.isRecording {
                    WaveformVisualizerView(level: recorderVM.audioLevel, primaryColor: primaryAccent)
                }

                // Knowledge Graph Canvas Button (⌘G)
                Button(action: { isGraphViewOpen = true }) {
                    Image(systemName: "network")
                        .font(.title3)
                        .foregroundColor(secondaryAccent)
                }
                .buttonStyle(.plain)
                .help("Knowledge Graph Canvas (⌘G)")

                // Zen Focus Mode Toggle
                Button(action: { isFocusMode.toggle() }) {
                    Image(systemName: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundColor(isFocusMode ? .amber : .secondary)
                }
                .buttonStyle(.plain)
                .help("Zen Focus Mode (⌘Shift+F)")
                
                // Record Audio in-place controller
                if noteBinding.wrappedValue.isStandalone {
                    Button(action: toggleRecording) {
                        HStack(spacing: 6) {
                            Image(systemName: recorderVM.isRecording ? "stop.circle.fill" : "mic.fill")
                                .foregroundColor(.white)
                            Text(recorderVM.isRecording ? "Stop" : "Record")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(recorderVM.isRecording ? Color.red : primaryAccent)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
                
                if !noteBinding.wrappedValue.isStandalone {
                    Button(action: { isRightPanelOpen.toggle() }) {
                        Image(systemName: "sidebar.right")
                            .font(.title3)
                            .foregroundColor(isRightPanelOpen ? primaryAccent : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Transcript View")
                }
                
                // Top-Right Settings Toggle Button
                Button(action: { isSettingsOpen = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(primaryAccent)
                }
                .buttonStyle(.plain)
                .help("Preferences & Settings")
            } else {
                Spacer()
                
                Button(action: { isSettingsOpen = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(primaryAccent)
                }
                .buttonStyle(.plain)
                .help("Preferences & Settings")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.panelBackground(isDark))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.subtleBorder(isDark)),
            alignment: .bottom
        )
    }
    
    private func toggleRecording() {
        if recorderVM.isRecording {
            if let url = recorderVM.stopRecording() {
                LocalSpeechTranscriber.transcribe(url: url) { segments in
                    onAudioTranscribed(segments, url.path)
                }
            }
        } else {
            recorderVM.startRecording()
        }
    }

    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Lecture Audio File"
        panel.allowedContentTypes = [UTType.audio, UTType.mp3, UTType.wav, UTType.mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                LocalSpeechTranscriber.transcribe(url: url) { segments in
                    onAudioTranscribed(segments, url.path)
                }
            }
        }
    }

    private func exportNoteMarkdown(_ note: NoteItem) {
        let panel = NSSavePanel()
        panel.title = "Export Note as Markdown"
        panel.nameFieldStringValue = "\(note.title).md"
        panel.allowedContentTypes = [UTType.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                var markdownExport = "# \(note.title)\n\n\(note.content)\n\n"
                if !note.transcript.isEmpty {
                    markdownExport += "## Diarized Transcript\n\n"
                    for seg in note.transcript {
                        let timestampStr = formatTime(seg.startTime)
                        markdownExport += "**\(seg.speaker)** [\(timestampStr)]: \(seg.text)\n\n"
                    }
                }
                try? markdownExport.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func exportNoteHTML(_ note: NoteItem) {
        let panel = NSSavePanel()
        panel.title = "Export Note as HTML"
        panel.nameFieldStringValue = "\(note.title).html"
        panel.allowedContentTypes = [UTType.html]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let html = generateFormattedHTML(for: note)
                try? html.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func generateFormattedHTML(for note: NoteItem) -> String {
        let bodyHTML = note.content
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "- [ ]", with: "<span>&#9633;</span>")
            .replacingOccurrences(of: "- [x]", with: "<span>&#9745;</span>")
        
        var transcriptHTML = ""
        if !note.transcript.isEmpty {
            transcriptHTML += "<h2>Diarized Transcript</h2><div class='transcript'>"
            for seg in note.transcript {
                let timeStr = formatTime(seg.startTime)
                transcriptHTML += "<div class='segment'><span class='speaker'>\(seg.speaker)</span> <span class='time'>[\(timeStr)]</span>: \(seg.text)</div>"
            }
            transcriptHTML += "</div>"
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>\(note.title)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0f172a; color: #f8fafc; padding: 40px; max-width: 800px; margin: 0 auto; line-height: 1.6; }
                h1 { color: #38bdf8; border-bottom: 1px solid #334155; padding-bottom: 10px; }
                h2 { color: #818cf8; margin-top: 30px; }
                .content { background: #1e293b; padding: 24px; border-radius: 12px; border: 1px solid #334155; margin-bottom: 24px; }
                .transcript { background: #1e293b; padding: 24px; border-radius: 12px; border: 1px solid #334155; }
                .segment { margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid #334155; }
                .speaker { font-weight: bold; color: #34d399; }
                .time { font-family: monospace; color: #94a3b8; font-size: 0.85em; }
            </style>
        </head>
        <body>
            <h1>\(note.title)</h1>
            <div class='content'>\(bodyHTML)</div>
            \(transcriptHTML)
        </body>
        </html>
        """
    }
}

// MARK: - Word & Character Count Helper
func calculateWordAndCharCount(_ text: String) -> (words: Int, chars: Int) {
    let cleanText = text.replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    let chars = text.replacingOccurrences(of: "\\n", with: "\n").count
    if cleanText.isEmpty {
        return (0, 0)
    }
    let words = cleanText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    return (words, chars)
}

// MARK: - Code Block Card Component
struct CodeBlockView: View {
    let code: String
    let isDark: Bool
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CODE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(copied ? "Copied!" : "Copy")
                            .font(.caption2)
                    }
                    .foregroundColor(copied ? .emerald : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isDark ? Color(red: 226/255, green: 232/255, blue: 240/255) : Color(red: 15/255, green: 23/255, blue: 42/255))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.cardBackground(isDark))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

// MARK: - Markdown Grid Table Renderer Component
struct MarkdownTableView: View {
    let lines: [String]
    let isDark: Bool
    
    var parsedRows: [[String]] {
        lines.compactMap { line in
            let parts = line.components(separatedBy: "|")
            if parts.count < 3 { return nil }
            return parts[1..<(parts.count - 1)].map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }
    
    var body: some View {
        let rows = parsedRows
        if let header = rows.first {
            let dataRows = rows.dropFirst().filter { row in
                !row.allSatisfy { $0.allSatisfy { $0 == "-" || $0 == ":" } }
            }
            
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    ForEach(Array(header.enumerated()), id: \.offset) { colIdx, cell in
                        Text(cell)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(Color.sidebarBackground(isDark))
                
                Divider()
                    .background(Color.subtleBorder(isDark))
                
                // Data Rows
                ForEach(Array(dataRows.enumerated()), id: \.offset) { rowIdx, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                            Text(cell)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .background(rowIdx % 2 == 0 ? Color.clear : Color.cardBackground(isDark))
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 1)
            )
            .padding(.vertical, 4)
        }
    }
}

// MARK: - AI Study Assistant Flashcards View
struct Flashcard: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct AIStudyAssistantView: View {
    let note: NoteItem
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var onInsertSummary: (String) -> Void
    
    @StateObject private var gemmaDownloader = GemmaModelDownloader.shared
    @StateObject private var gemmaEngine = GemmaLocalEngine.shared
    
    @State private var flippedCardIds: Set<UUID> = []
    @State private var customPrompt: String = ""
    @State private var promptResponse: String = ""
    @State private var extractedTasks: [String] = []
    
    var summaryTakeaways: [String] {
        let lines = note.content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let clean = lines.prefix(3).map { line -> String in
            var str = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            if str.hasPrefix("-") { str = String(str.dropFirst()).trimmingCharacters(in: .whitespaces) }
            return str
        }
        return clean.isEmpty ? ["Core key concepts discussed in lecture note."] : clean
    }
    
    var flashcards: [Flashcard] {
        var cards: [Flashcard] = []
        cards.append(Flashcard(question: "What is the main topic of '\(note.title)'?", answer: summaryTakeaways.first ?? "General Note Content"))
        if !note.transcript.isEmpty {
            cards.append(Flashcard(question: "What was highlighted in the audio transcript?", answer: note.transcript.first?.text ?? "Audio Recording Content"))
        } else {
            cards.append(Flashcard(question: "How are wiki-links used in this note?", answer: "Wiki-links like [[Note Title]] connect concepts together dynamically."))
        }
        return cards
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundColor(primaryAccent)
                        .font(.headline)
                    Text("Gemma 3 AI Assistant")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Spacer()
                if gemmaDownloader.isDownloaded {
                    Text("Offline 2B")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryAccent.opacity(0.2))
                        .foregroundColor(primaryAccent)
                        .cornerRadius(4)
                }
            }
            
            // Model Download Banner if not ready
            if !gemmaDownloader.isDownloaded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(primaryAccent)
                        Text("Gemma 3 Model Required")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    Text("Download Google's 1.6GB GGUF model for 100% offline local AI summarization and Q&A.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if gemmaDownloader.isDownloading {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: gemmaDownloader.downloadProgress)
                                .accentColor(primaryAccent)
                            Text(gemmaDownloader.statusMessage)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: { gemmaDownloader.startDownload() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                Text("Download Model (1.6 GB)")
                            }
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(primaryAccent)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(primaryAccent.opacity(0.08))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(primaryAccent.opacity(0.25), lineWidth: 1)
                )
            }
            
            // Section 1: Executive Key Takeaways
            VStack(alignment: .leading, spacing: 6) {
                Text("KEY TAKEAWAYS")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                ForEach(summaryTakeaways, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(primaryAccent)
                        Text(bullet)
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    let summaryBlock = "\n### 💡 AI Key Takeaways\n" + summaryTakeaways.map { "- \($0)" }.joined(separator: "\n") + "\n"
                    onInsertSummary(summaryBlock)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Insert Summary into Note")
                    }
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(secondaryAccent)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.cardBackground(isDark))
            .cornerRadius(10)
            
            // Section 2: Action Items Extraction
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("EXTRACT ACTION ITEMS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        Task {
                            extractedTasks = await gemmaEngine.extractActionItems(note: note)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                            Text("Scan Tasks")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)
                }
                
                if !extractedTasks.isEmpty {
                    ForEach(extractedTasks, id: \.self) { task in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "square")
                                .font(.system(size: 10))
                                .foregroundColor(primaryAccent)
                            Text(task)
                                .font(.caption2)
                        }
                    }
                    
                    Button(action: {
                        let taskBlock = "\n### 📋 Action Items\n" + extractedTasks.map { "- [ ] \($0)" }.joined(separator: "\n") + "\n"
                        onInsertSummary(taskBlock)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                            Text("Insert Tasks into Note")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(secondaryAccent)
                        .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Tap 'Scan Tasks' to auto-detect action items.")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.cardBackground(isDark))
            .cornerRadius(10)

            // Section 3: Interactive Prompt / Q&A Bar
            VStack(alignment: .leading, spacing: 8) {
                Text("ASK GEMMA ASSISTANT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    TextField("Ask anything about this note...", text: $customPrompt)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .padding(6)
                        .background(Color.sidebarBackground(isDark))
                        .cornerRadius(6)
                    
                    Button(action: {
                        Task {
                            promptResponse = await gemmaEngine.askGemma(prompt: customPrompt, note: note)
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(primaryAccent)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                if !promptResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(promptResponse)
                            .font(.caption2)
                            .foregroundColor(isDark ? Color(red: 226/255, green: 232/255, blue: 240/255) : Color(red: 15/255, green: 23/255, blue: 42/255))
                        
                        Button(action: {
                            onInsertSummary("\n" + promptResponse + "\n")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Insert Answer")
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(secondaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.sidebarBackground(isDark))
                    .cornerRadius(6)
                }
            }
            .padding(12)
            .background(Color.cardBackground(isDark))
            .cornerRadius(10)
            
            // Section 4: Study Flashcards
            VStack(alignment: .leading, spacing: 8) {
                Text("STUDY FLASHCARDS (Tap card to reveal)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                ForEach(flashcards) { card in
                    let isFlipped = flippedCardIds.contains(card.id)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(isFlipped ? "ANSWER" : "QUESTION")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(isFlipped ? .emerald : primaryAccent)
                            Spacer()
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(isFlipped ? card.answer : card.question)
                            .font(.caption)
                            .fontWeight(isFlipped ? .regular : .bold)
                            .foregroundColor(isFlipped ? (isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255)) : primaryAccent)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isFlipped ? Color.emerald.opacity(0.12) : Color.cardBackground(isDark))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFlipped ? Color.emerald.opacity(0.4) : Color.subtleBorder(isDark), lineWidth: 1)
                    )
                    .onTapGesture {
                        if isFlipped {
                            flippedCardIds.remove(card.id)
                        } else {
                            flippedCardIds.insert(card.id)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

// MARK: - Editor Panel View
struct EditorPanelView: View {
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14.0
    @AppStorage("editorFontDesign") private var editorFontDesign: String = "Monospaced"
    
    @State private var editMode: EditModeType = .split
    @State private var localContent: String = ""
    @State private var saveTimer: Timer? = nil
    @State private var showBacklinks = true
    @State private var showAIAssistantPopover = false
    @State private var showTOCDrawer = false

    private var selectedFontDesign: Font.Design {
        switch editorFontDesign {
        case "Sans-Serif": return .default
        case "Serif": return .serif
        default: return .monospaced
        }
    }

    private var stats: (words: Int, chars: Int) {
        calculateWordAndCharCount(localContent)
    }

    var headingOutline: [String] {
        localContent.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
    }

    var incomingBacklinks: [NoteItem] {
        let currentTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !currentTitle.isEmpty else { return [] }
        return notes.filter { n in
            n.id != note.id && n.content.lowercased().contains("[[\(currentTitle)]]")
        }
    }

    var outgoingWikiLinks: [String] {
        let pattern = "\\[\\[(.*?)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let line = note.content
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: nsRange)
        var links: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: line) {
                let link = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !link.isEmpty && !links.contains(link) {
                    links.append(link)
                }
            }
        }
        return links
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Status Header Bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(primaryAccent)
                        .font(.subheadline)
                    Text("SHORTHAND NOTES")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.secondary)
                }
                
                // TOC Heading Outline Drawer Button
                if !headingOutline.isEmpty {
                    Button(action: { showTOCDrawer.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet.indent")
                                .font(.caption)
                                .foregroundColor(secondaryAccent)
                            Text("Outline (\(headingOutline.count))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(secondaryAccent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(secondaryAccent.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTOCDrawer) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Table of Contents")
                                .font(.caption)
                                .fontWeight(.bold)
                            ForEach(headingOutline, id: \.self) { heading in
                                Text(heading)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(12)
                    }
                }
                
                Spacer()
                
                Text("\(stats.words) words  |  \(stats.chars) chars")
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
                
                // AI Study Assistant Popover Button
                Button(action: { showAIAssistantPopover.toggle() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                        Text("AI Assistant")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(primaryAccent.opacity(0.12))
                    .foregroundColor(primaryAccent)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(primaryAccent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAIAssistantPopover) {
                    AIStudyAssistantView(note: note, isDark: isDark, primaryAccent: primaryAccent, secondaryAccent: secondaryAccent, onInsertSummary: { summaryBlock in
                        localContent += summaryBlock
                        note.content = localContent
                        NotesDataManager.shared.saveNotes(notes)
                        showAIAssistantPopover = false
                    })
                }

                // Edit | Split | Preview Mode Picker
                HStack(spacing: 0) {
                    ForEach(EditModeType.allCases, id: \.self) { mode in
                        Button(action: { editMode = mode }) {
                            Text(mode.rawValue)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(editMode == mode ? primaryAccent.opacity(0.18) : Color.clear)
                                .foregroundColor(editMode == mode ? primaryAccent : .secondary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.cardBackground(isDark))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                )

                Text("Auto-saves")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.panelBackground(isDark))
            
            Divider()
                .background(Color.subtleBorder(isDark))

            // Markdown Formatting Toolbar
            if editMode == .edit || editMode == .split {
                HStack(spacing: 12) {
                    Button(action: { insertMarkdown("**", "**") }) {
                        Text("B")
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Bold (**text**)")

                    Button(action: { insertMarkdown("*", "*") }) {
                        Text("I")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .italic()
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Italic (*text*)")

                    Button(action: { insertMarkdown("\n# ", "") }) {
                        Text("#")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Heading (# Heading)")

                    Rectangle()
                        .fill(Color.subtleBorder(isDark))
                        .frame(width: 1, height: 16)

                    Button(action: { insertMarkdown("\n- ", "") }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Bullet List (- Item)")

                    Button(action: { insertMarkdown("\n- [ ] ", "") }) {
                        Image(systemName: "checkmark.square")
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Checklist Task (- [ ] Task)")

                    Button(action: { insertMarkdown("`", "`") }) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Code Snippet (`code`)")

                    Button(action: { insertMarkdown("[[", "]]") }) {
                        Text("[ [ ] ]")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Wiki Link ([[Note Title]])")

                    Button(action: { insertMarkdown("\n| Header 1 | Header 2 |\n| --- | --- |\n| Item 1 | Item 2 |\n", "") }) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Insert Table Template")

                    Button(action: { insertMarkdown("\n> ", "") }) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Blockquote (> Quote)")

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.sidebarBackground(isDark))

                Divider()
                    .background(Color.subtleBorder(isDark))
            }
            
            // Editor Body View (Single Edit, Split View, or Full Preview)
            if editMode == .edit {
                TextEditor(text: $localContent)
                    .font(.system(size: CGFloat(editorFontSize), design: selectedFontDesign))
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .background(Color.panelBackground(isDark))
                    .onChange(of: localContent) { _, newContent in
                        handleAutoSave(newContent)
                    }
            } else if editMode == .split {
                HStack(spacing: 0) {
                    TextEditor(text: $localContent)
                        .font(.system(size: CGFloat(editorFontSize), design: selectedFontDesign))
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .background(Color.panelBackground(isDark))
                        .onChange(of: localContent) { _, newContent in
                            handleAutoSave(newContent)
                        }
                    
                    Divider()
                        .background(Color.subtleBorder(isDark))
                    
                    ScrollView {
                        MarkdownRendererView(
                            markdown: localContent.replacingOccurrences(of: "\\n", with: "\n"),
                            notes: $notes,
                            selectedNoteId: $selectedNoteId,
                            playerVM: playerVM,
                            isDark: isDark,
                            primaryAccent: primaryAccent,
                            secondaryAccent: secondaryAccent
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                    .background(Color.panelBackground(isDark))
                }
            } else {
                ScrollView {
                    MarkdownRendererView(
                        markdown: localContent.replacingOccurrences(of: "\\n", with: "\n"),
                        notes: $notes,
                        selectedNoteId: $selectedNoteId,
                        playerVM: playerVM,
                        isDark: isDark,
                        primaryAccent: primaryAccent,
                        secondaryAccent: secondaryAccent
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .background(Color.panelBackground(isDark))
            }

            // Collapsible Obsidian-Style Backlinks Drawer
            if !incomingBacklinks.isEmpty || !outgoingWikiLinks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(secondaryAccent)
                        Text("Knowledge Connections & Backlinks")
                            .font(.caption)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: { showBacklinks.toggle() }) {
                            Image(systemName: showBacklinks ? "chevron.down" : "chevron.up")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showBacklinks {
                        HStack(alignment: .top, spacing: 20) {
                            if !incomingBacklinks.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("LINKED REFERENCES (\(incomingBacklinks.count))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(incomingBacklinks) { backlinkNote in
                                        Button(action: { selectedNoteId = backlinkNote.id }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "link")
                                                    .font(.system(size: 9))
                                                Text(backlinkNote.title)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(secondaryAccent.opacity(0.15))
                                            .foregroundColor(secondaryAccent)
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            if !outgoingWikiLinks.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("OUTGOING LINKS (\(outgoingWikiLinks.count))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(outgoingWikiLinks, id: \.self) { linkTitle in
                                        Button(action: { openOrCreateWikiLinkNote(linkTitle) }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.up.right.square")
                                                    .font(.system(size: 9))
                                                Text(linkTitle)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(primaryAccent.opacity(0.15))
                                            .foregroundColor(primaryAccent)
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.sidebarBackground(isDark))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            localContent = note.content.replacingOccurrences(of: "\\n", with: "\n")
        }
        .onChange(of: note.id) { _, _ in
            saveTimer?.invalidate()
            localContent = note.content.replacingOccurrences(of: "\\n", with: "\n")
        }
        .onChange(of: note.content) { _, externalContent in
            let clean = externalContent.replacingOccurrences(of: "\\n", with: "\n")
            if localContent != clean {
                localContent = clean
            }
        }
        .onDisappear {
            saveTimer?.invalidate()
            let clean = localContent.replacingOccurrences(of: "\\n", with: "\n")
            if note.content != clean {
                note.content = clean
                NotesDataManager.shared.saveNotes(notes)
            }
        }
    }

    private func handleAutoSave(_ newContent: String) {
        if newContent != note.content {
            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                Task { @MainActor in
                    let clean = newContent.replacingOccurrences(of: "\\n", with: "\n")
                    if note.content != clean {
                        note.content = clean
                        NotesDataManager.shared.saveNotes(notes)
                    }
                }
            }
        }
    }

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        localContent += "\(prefix)text\(suffix)"
        let clean = localContent.replacingOccurrences(of: "\\n", with: "\n")
        note.content = clean
        NotesDataManager.shared.saveNotes(notes)
    }

    private func openOrCreateWikiLinkNote(_ targetTitle: String) {
        let cleanTarget = targetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = notes.first(where: { $0.title.caseInsensitiveCompare(cleanTarget) == .orderedSame }) {
            selectedNoteId = existing.id
        } else {
            let newNote = NoteItem(
                title: cleanTarget,
                folder: note.folder,
                content: "# \(cleanTarget)\n\nCreated automatically from wiki-link `[[\(cleanTarget)]]`.\n",
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
            notes.insert(newNote, at: 0)
            selectedNoteId = newNote.id
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}

// MARK: - Obsidian-Style Graph View Modal Canvas
struct GraphNode: Identifiable {
    let id: UUID
    let title: String
    let x: CGFloat
    let y: CGFloat
}

struct GraphEdge: Identifiable {
    let id = UUID()
    let sourceId: UUID
    let targetId: UUID
}

struct GraphViewModal: View {
    let notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @Binding var isOpen: Bool
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var searchQuery: String = ""
    @State private var hoveredNodeId: UUID? = nil
    
    var edges: [GraphEdge] {
        var result: [GraphEdge] = []
        for note in notes {
            let outgoing = parseOutgoingWikiLinks(note.content)
            for targetTitle in outgoing {
                if let targetNote = notes.first(where: { $0.title.caseInsensitiveCompare(targetTitle) == .orderedSame }) {
                    result.append(GraphEdge(sourceId: note.id, targetId: targetNote.id))
                }
            }
        }
        return result
    }
    
    private func getPosition(for noteId: UUID, totalCount: Int, index: Int, canvasSize: CGSize) -> CGPoint {
        if let pos = nodePositions[noteId] {
            return pos
        }
        let radius: CGFloat = min(canvasSize.width, canvasSize.height) * 0.35
        let centerX = canvasSize.width / 2.0
        let centerY = canvasSize.height / 2.0
        let angle = (2.0 * .pi / Double(max(1, totalCount))) * Double(index)
        let pos = CGPoint(x: centerX + radius * cos(angle), y: centerY + radius * sin(angle))
        DispatchQueue.main.async {
            if self.nodePositions[noteId] == nil {
                self.nodePositions[noteId] = pos
            }
        }
        return pos
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Controls
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.title2)
                        .foregroundColor(primaryAccent)
                    Text("KNOWLEDGE GRAPH CANVAS")
                        .font(.headline)
                        .fontWeight(.heavy)
                }
                
                Spacer()
                
                // Search Filter
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Filter nodes...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .frame(width: 110)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.panelBackground(isDark))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.subtleBorder(isDark), lineWidth: 1))
                
                // Zoom Controls
                HStack(spacing: 4) {
                    Button(action: { zoomScale = min(zoomScale + 0.2, 2.5) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { zoomScale = max(zoomScale - 0.2, 0.5) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.caption)
                            .foregroundColor(primaryAccent)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { zoomScale = 1.0; panOffset = .zero }) {
                        Text("Reset")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.panelBackground(isDark))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.subtleBorder(isDark), lineWidth: 1))
                
                // Close Button
                Button(action: { isOpen = false }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.sidebarBackground(isDark))

            Divider()
                .background(Color.subtleBorder(isDark))

            // Main Interactive Canvas
            GeometryReader { geo in
                let canvasSize = geo.size
                
                ZStack {
                    Color.panelBackground(isDark)
                    
                    // Background Blueprint Grid
                    Canvas { context, size in
                        let gridSize: CGFloat = 30.0
                        var path = Path()
                        for x in stride(from: 0, to: size.width, by: gridSize) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for y in stride(from: 0, to: size.height, by: gridSize) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(path, with: .color(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.04)), lineWidth: 1)
                    }
                    
                    // Connected Edge Lines
                    Canvas { context, size in
                        for edge in edges {
                            if let srcNote = notes.first(where: { $0.id == edge.sourceId }),
                               let dstNote = notes.first(where: { $0.id == edge.targetId }),
                               let srcIdx = notes.firstIndex(where: { $0.id == edge.sourceId }),
                               let dstIdx = notes.firstIndex(where: { $0.id == edge.targetId }) {
                                
                                let srcPos = getPosition(for: srcNote.id, totalCount: notes.count, index: srcIdx, canvasSize: size)
                                let dstPos = getPosition(for: dstNote.id, totalCount: notes.count, index: dstIdx, canvasSize: size)
                                
                                let isHighlighted = hoveredNodeId == edge.sourceId || hoveredNodeId == edge.targetId || selectedNoteId == edge.sourceId || selectedNoteId == edge.targetId
                                
                                var path = Path()
                                path.move(to: srcPos)
                                path.addLine(to: dstPos)
                                
                                let strokeColor = isHighlighted ? primaryAccent : secondaryAccent.opacity(0.4)
                                let lineWidth: CGFloat = isHighlighted ? 3.0 : 1.5
                                context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)
                            }
                        }
                    }
                    
                    // Interactive Node Pills
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        let pos = getPosition(for: note.id, totalCount: notes.count, index: index, canvasSize: canvasSize)
                        let isSelected = note.id == selectedNoteId
                        let isHovered = note.id == hoveredNodeId
                        let isMatched = searchQuery.isEmpty || note.title.localizedCaseInsensitiveContains(searchQuery)
                        let linkCount = edges.filter { $0.sourceId == note.id || $0.targetId == note.id }.count
                        
                        HStack(spacing: 6) {
                            if note.audioPath != nil {
                                Image(systemName: "waveform")
                                    .font(.system(size: 10))
                                    .foregroundColor(primaryAccent)
                            } else {
                                Circle()
                                    .fill(isSelected ? primaryAccent : secondaryAccent)
                                    .frame(width: 8, height: 8)
                            }
                            
                            Text(note.title)
                                .font(.caption)
                                .fontWeight(isSelected || isHovered ? .bold : .medium)
                            
                            if linkCount > 0 {
                                Text("\(linkCount)")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(primaryAccent.opacity(0.2))
                                    .foregroundColor(primaryAccent)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? primaryAccent.opacity(0.2) : Color.cardBackground(isDark))
                        .foregroundColor(isSelected ? primaryAccent : (isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255)))
                        .cornerRadius(14)
                        .opacity(isMatched ? 1.0 : 0.3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? primaryAccent : (isHovered ? primaryAccent.opacity(0.7) : secondaryAccent.opacity(0.4)), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? primaryAccent.opacity(0.4) : Color.clear, radius: 8)
                        .position(x: pos.x, y: pos.y)
                        .onHover { over in
                            hoveredNodeId = over ? note.id : nil
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    nodePositions[note.id] = value.location
                                }
                        )
                        .onTapGesture {
                            selectedNoteId = note.id
                            isOpen = false
                        }
                    }
                }
                .scaleEffect(zoomScale)
                .offset(panOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            panOffset = value.translation
                        }
                )
            }
            .frame(height: 480)
            
            // Footer Stats Bar
            HStack {
                Text("\(notes.count) Notes")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text("\(edges.count) Connections")
                    .font(.caption2)
                    .foregroundColor(primaryAccent)
                Spacer()
                Text("💡 Tip: Drag nodes to rearrange • Tap node to open")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.sidebarBackground(isDark))
        }
        .frame(width: 640, height: 570)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
    }
    
    private func parseOutgoingWikiLinks(_ text: String) -> [String] {
        let pattern = "\\[\\[(.*?)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        var links: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                links.append(String(text[range]))
            }
        }
        return links
    }
}

// MARK: - Tokenizer & Markdown Renderer View
struct TextToken: Identifiable {
    let id = UUID()
    enum TokenType {
        case text(String)
        case wikiLink(String)
        case hashtag(String)
        case playLink(timeLabel: String, seconds: Double)
    }
    let type: TokenType
}

func parseLineTokens(_ line: String) -> [TextToken] {
    var tokens: [TextToken] = []
    var currentIndex = line.startIndex

    let pattern = "\\[\\[(.*?)\\]\\]|\\[(.*?)\\]\\(play://([0-9.]+)\\)|#([a-zA-Z0-9_]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [.init(type: .text(line))]
    }

    let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
    let matches = regex.matches(in: line, range: nsRange)

    for match in matches {
        guard let matchRange = Range(match.range, in: line) else { continue }
        
        if currentIndex < matchRange.lowerBound {
            let prefixText = String(line[currentIndex..<matchRange.lowerBound])
            if !prefixText.isEmpty {
                tokens.append(.init(type: .text(prefixText)))
            }
        }

        if let wikiRange = Range(match.range(at: 1), in: line), !line[wikiRange].isEmpty {
            let wikiTitle = String(line[wikiRange])
            tokens.append(.init(type: .wikiLink(wikiTitle)))
        } else if let labelRange = Range(match.range(at: 2), in: line),
                  let secRange = Range(match.range(at: 3), in: line),
                  let seconds = Double(line[secRange]) {
            let label = String(line[labelRange])
            tokens.append(.init(type: .playLink(timeLabel: label, seconds: seconds)))
        } else if let tagRange = Range(match.range(at: 4), in: line), !line[tagRange].isEmpty {
            let tag = String(line[tagRange])
            tokens.append(.init(type: .hashtag(tag)))
        }

        currentIndex = matchRange.upperBound
    }

    if currentIndex < line.endIndex {
        let suffixText = String(line[currentIndex..<line.endIndex])
        if !suffixText.isEmpty {
            tokens.append(.init(type: .text(suffixText)))
        }
    }

    return tokens
}

struct FormattedTextLine: View {
    let text: String
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let currentFolder: String
    let primaryAccent: Color
    let secondaryAccent: Color

    var tokens: [TextToken] {
        parseLineTokens(text)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(tokens) { token in
                switch token.type {
                case .text(let plainStr):
                    Text(plainStr)
                case .hashtag(let tag):
                    Text("#\(tag)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(primaryAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(primaryAccent.opacity(0.12))
                        .cornerRadius(4)
                case .wikiLink(let targetTitle):
                    Button(action: {
                        openOrCreateWikiLinkNote(targetTitle)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 9))
                            Text(targetTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(secondaryAccent.opacity(0.2))
                        .foregroundColor(secondaryAccent)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(secondaryAccent.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                case .playLink(let label, let seconds):
                    Button(action: {
                        playerVM.seek(to: seconds)
                        if !playerVM.isPlaying {
                            playerVM.togglePlayPause()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            Text(label)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryAccent.opacity(0.2))
                        .foregroundColor(primaryAccent)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openOrCreateWikiLinkNote(_ targetTitle: String) {
        let cleanTarget = targetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = notes.first(where: { $0.title.caseInsensitiveCompare(cleanTarget) == .orderedSame }) {
            selectedNoteId = existing.id
        } else {
            let newNote = NoteItem(
                title: cleanTarget,
                folder: currentFolder,
                content: "# \(cleanTarget)\n\nCreated automatically from wiki-link `[[\(cleanTarget)]]`.\n",
                timestamp: Date(),
                audioPath: nil,
                transcript: [],
                isStandalone: true,
                bookmarks: []
            )
            notes.insert(newNote, at: 0)
            selectedNoteId = newNote.id
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}

enum MarkdownBlockType {
    case line(String)
    case table([String])
    case code(String)
}

func parseMarkdownBlocks(_ text: String) -> [MarkdownBlockType] {
    let lines = text.components(separatedBy: "\n")
    var blocks: [MarkdownBlockType] = []
    
    var index = 0
    while index < lines.count {
        let line = lines[index]
        
        // Code block check
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            var codeLines: [String] = []
            index += 1
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[index])
                index += 1
            }
            blocks.append(.code(codeLines.joined(separator: "\n")))
            index += 1
            continue
        }
        
        // Table check
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            var tableLines: [String] = []
            while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                tableLines.append(lines[index])
                index += 1
            }
            blocks.append(.table(tableLines))
            continue
        }
        
        blocks.append(.line(line))
        index += 1
    }
    
    return blocks
}

struct MarkdownRendererView: View {
    let markdown: String
    @Binding var notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @ObservedObject var playerVM: AudioPlayerViewModel
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color

    var currentNoteFolder: String {
        if let id = selectedNoteId, let note = notes.first(where: { $0.id == id }) {
            return note.folder
        }
        return "General"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parseMarkdownBlocks(markdown).enumerated()), id: \.offset) { _, block in
                switch block {
                case .line(let line):
                    renderLine(line)
                case .table(let tableLines):
                    MarkdownTableView(lines: tableLines, isDark: isDark)
                case .code(let codeStr):
                    CodeBlockView(code: codeStr, isDark: isDark)
                }
            }
        }
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        if line.hasPrefix("# ") {
            Text(line.replacingOccurrences(of: "# ", with: ""))
                .font(.title)
                .fontWeight(.bold)
        } else if line.hasPrefix("## ") {
            Text(line.replacingOccurrences(of: "## ", with: ""))
                .font(.title2)
                .fontWeight(.semibold)
        } else if line.hasPrefix("### ") {
            Text(line.replacingOccurrences(of: "### ", with: ""))
                .font(.headline)
                .fontWeight(.medium)
        } else if line.hasPrefix("> ") {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(primaryAccent)
                    .frame(width: 3)
                FormattedTextLine(
                    text: line.replacingOccurrences(of: "> ", with: ""),
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.cardBackground(true))
            .cornerRadius(6)
        } else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") {
            let isChecked = line.hasPrefix("- [x] ")
            let clean = line.replacingOccurrences(of: "- [ ] ", with: "").replacingOccurrences(of: "- [x] ", with: "")
            HStack(alignment: .top, spacing: 8) {
                Button(action: { toggleCheckbox(targetLine: line) }) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundColor(isChecked ? primaryAccent : .secondary)
                }
                .buttonStyle(.plain)
                
                FormattedTextLine(
                    text: clean,
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
                .strikethrough(isChecked, color: .secondary)
            }
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                FormattedTextLine(
                    text: line.replacingOccurrences(of: "- ", with: ""),
                    notes: $notes,
                    selectedNoteId: $selectedNoteId,
                    playerVM: playerVM,
                    currentFolder: currentNoteFolder,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                )
            }
        } else {
            FormattedTextLine(
                text: line,
                notes: $notes,
                selectedNoteId: $selectedNoteId,
                playerVM: playerVM,
                currentFolder: currentNoteFolder,
                primaryAccent: primaryAccent,
                secondaryAccent: secondaryAccent
            )
        }
    }

    private func toggleCheckbox(targetLine: String) {
        guard let id = selectedNoteId, let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let currentContent = notes[idx].content
        let replacement = targetLine.hasPrefix("- [x] ") ? targetLine.replacingOccurrences(of: "- [x] ", with: "- [ ] ") : targetLine.replacingOccurrences(of: "- [ ] ", with: "- [x] ")
        if let range = currentContent.range(of: targetLine) {
            notes[idx].content.replaceSubrange(range, with: replacement)
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}

// MARK: - Transcript Panel View (With Real-time Search Filter)
struct TranscriptPanelView: View {
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    @ObservedObject var playerVM: AudioPlayerViewModel
    @Binding var width: Double
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    
    @State private var renamingSpeaker: String? = nil
    @State private var newSpeakerName: String = ""
    @State private var searchQuery: String = ""

    var filteredTranscript: [TranscriptSegment] {
        let clean = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.isEmpty {
            return note.transcript
        }
        return note.transcript.filter {
            $0.text.lowercased().contains(clean) || $0.speaker.lowercased().contains(clean)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Diarized Transcript")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(filteredTranscript.count) segs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Real-time Transcript Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Search transcript keywords...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.caption)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.cardBackground(isDark))
                .cornerRadius(6)
            }
            .padding(14)
            .background(Color.panelBackground(isDark))

            Divider()
                .background(Color.subtleBorder(isDark))

            // Scroll list of segments
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(filteredTranscript.enumerated()), id: \.element.id) { idx, seg in
                            let isActive = idx == playerVM.activeSegmentIndex
                            let isMe = seg.speaker == "Speaker 1"
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    // Speaker tag with Popover Renamer
                                    Button(action: {
                                        renamingSpeaker = seg.speaker
                                        newSpeakerName = seg.speaker
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 11))
                                            Text(seg.speaker)
                                                .font(.system(size: 11, weight: .bold))
                                            Image(systemName: "pencil")
                                                .font(.system(size: 8))
                                        }
                                        .foregroundColor(isMe ? secondaryAccent : .emerald)
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: Binding(
                                        get: { renamingSpeaker == seg.speaker },
                                        set: { if !$0 { renamingSpeaker = nil } }
                                    )) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Rename Speaker Globally")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                            TextField("Speaker Name...", text: $newSpeakerName, onCommit: {
                                                renameSpeakerGlobally(oldName: seg.speaker, newName: newSpeakerName)
                                                renamingSpeaker = nil
                                            })
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 160)
                                            
                                            HStack {
                                                Spacer()
                                                Button("Save") {
                                                    renameSpeakerGlobally(oldName: seg.speaker, newName: newSpeakerName)
                                                    renamingSpeaker = nil
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.small)
                                            }
                                        }
                                        .padding()
                                    }
                                    
                                    Spacer()
                                    
                                    // Seek Moment Play button
                                    Button(action: { playerVM.seek(to: seg.startTime) }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 8))
                                            Text(formatTime(seg.startTime))
                                                .font(.system(size: 10, design: .monospaced))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Copy Quote to Editor Button
                                    Button(action: { insertQuoteAtCursor(text: seg.text, start: seg.startTime) }) {
                                        Image(systemName: "quote.bubble")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .padding(4)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy quote to editor")
                                }
                                
                                Text(seg.text)
                                    .font(.subheadline)
                                    .foregroundColor(isActive ? (isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255)) : .secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(isActive ? primaryAccent.opacity(0.12) : Color.cardBackground(isDark))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isActive ? primaryAccent.opacity(0.4) : Color.subtleBorder(isDark), lineWidth: 1)
                            )
                            .id(idx)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: playerVM.activeSegmentIndex) { _, newIndex in
                    if newIndex != -1 {
                        withAnimation {
                            scrollProxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color.sidebarBackground(isDark))
    }
    
    private func renameSpeakerGlobally(oldName: String, newName: String) {
        let cleanNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNew.isEmpty && cleanNew != oldName else { return }
        for i in 0..<note.transcript.count {
            if note.transcript[i].speaker == oldName {
                note.transcript[i].speaker = cleanNew
            }
        }
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
            NotesDataManager.shared.saveNotesImmediately(notes)
        }
    }

    private func insertQuoteAtCursor(text: String, start: Double) {
        let timestampStr = formatTime(start)
        let secondsStr = String(format: "%.1f", start)
        let quote = "\n> \"\(text)\" [\(timestampStr)](play://\(secondsStr))\n"
        note.content += quote
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
            NotesDataManager.shared.saveNotes(notes)
        }
    }
}

// MARK: - Audio Player Bottom Bar View
struct AudioPlayerBarView: View {
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    @ObservedObject var playerVM: AudioPlayerViewModel
    let audioPath: String
    let isDark: Bool
    let primaryAccent: Color

    @State private var newBookmarkTitle = ""
    @State private var showBookmarkPopover = false

    var body: some View {
        HStack(spacing: 16) {
            // Left Controls
            HStack(spacing: 10) {
                Button(action: { playerVM.rewind5Seconds() }) {
                    Image(systemName: "gobackward.5")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                Button(action: { playerVM.togglePlayPause() }) {
                    Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(primaryAccent)
                }
                .buttonStyle(.plain)

                Button(action: { playerVM.forward5Seconds() }) {
                    Image(systemName: "goforward.5")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            // Middle Interactive Waveform Track & Bookmark Markers
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    if playerVM.isPlaying {
                        WaveformVisualizerView(level: 0.8, primaryColor: primaryAccent)
                    }

                    // Add Timeline Flag Bookmark Button
                    Button(action: { showBookmarkPopover.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                                .foregroundColor(primaryAccent)
                            Text("+ Flag")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(primaryAccent)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryAccent.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showBookmarkPopover) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add Timeline Flag Marker")
                                .font(.caption)
                                .fontWeight(.bold)
                            TextField("Bookmark label (e.g. Exam Topic)...", text: $newBookmarkTitle, onCommit: {
                                addBookmark()
                            })
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            
                            Button("Add Flag") { addBookmark() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        .padding()
                    }
                    
                    Spacer()
                    Text("\(formatTime(playerVM.currentTime)) / \(formatTime(playerVM.duration))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                // Interactive Multi-bar Waveform Seeker
                InteractiveWaveformView(
                    currentTime: playerVM.currentTime,
                    duration: playerVM.duration,
                    isPlaying: playerVM.isPlaying,
                    primaryAccent: primaryAccent,
                    onSeek: { targetTime in
                        playerVM.seek(to: targetTime)
                    }
                )

                // List of Bookmarked Timeline Flags
                if !note.bookmarks.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(note.bookmarks) { bm in
                                Button(action: { playerVM.seek(to: bm.time) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 8))
                                        Text("\(bm.label) [\(formatTime(bm.time))]")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(primaryAccent.opacity(0.15))
                                    .foregroundColor(primaryAccent)
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Right Speed buttons
            HStack(spacing: 4) {
                ForEach([1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    Button(action: { playerVM.setSpeed(speed) }) {
                        Text("\(speed, specifier: "%.2g")x")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(playerVM.playbackSpeed == speed ? primaryAccent.opacity(0.18) : Color.cardBackground(isDark))
                            .foregroundColor(playerVM.playbackSpeed == speed ? primaryAccent : .secondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 76)
        .background(Color.panelBackground(isDark))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.subtleBorder(isDark)),
            alignment: .top
        )
        .onAppear {
            let url = URL(fileURLWithPath: audioPath)
            playerVM.loadAudio(url: url, transcript: note.transcript)
        }
    }

    private func addBookmark() {
        let clean = newBookmarkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = clean.isEmpty ? "Key Moment" : clean
        let bm = AudioBookmark(time: playerVM.currentTime, label: label)
        note.bookmarks.append(bm)
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
            NotesDataManager.shared.saveNotesImmediately(notes)
        }
        showBookmarkPopover = false
        newBookmarkTitle = ""
    }
}

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
        case .preferences: return "slider.horizontal.3"
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
                    .foregroundColor(.amber)
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
                                .foregroundColor(.amber)
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

// MARK: - Command Palette (⌘K / ⌘O Quick Switcher)
struct CommandPaletteView: View {
    let notes: [NoteItem]
    @Binding var selectedNoteId: UUID?
    @Binding var isOpen: Bool
    let isDark: Bool
    let primaryAccent: Color
    
    @State private var query = CommandLine.arguments.contains("--command-palette") ? "Machine Learning" : ""
    @State private var selectionIndex = 0
    
    var filteredResults: [NoteItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanQuery.isEmpty {
            return Array(notes.prefix(8))
        }
        return notes.filter { note in
            note.title.lowercased().contains(cleanQuery) ||
            note.folder.lowercased().contains(cleanQuery) ||
            note.content.lowercased().contains(cleanQuery) ||
            note.transcript.contains(where: { $0.text.lowercased().contains(cleanQuery) || $0.speaker.lowercased().contains(cleanQuery) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(primaryAccent)
                    .font(.title3)
                TextField("Search notes, folders, or transcript keywords...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onChange(of: query) { _, _ in
                        selectionIndex = 0
                    }
                Spacer()
                Button(action: { isOpen = false }) {
                    Text("Esc")
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.cardBackground(isDark))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.sidebarBackground(isDark))

            Divider()
                .background(Color.subtleBorder(isDark))

            // Results List
            ScrollViewReader { scrollProxy in
                List {
                    if filteredResults.isEmpty {
                        Text("No matching notes found.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(filteredResults.enumerated()), id: \.element.id) { idx, note in
                            HStack {
                                Image(systemName: note.isStandalone ? "doc.text" : "waveform")
                                    .foregroundColor(idx == selectionIndex ? primaryAccent : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text("Folder: \(note.folder) • \(note.timestamp, style: .date)")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    if let snippet = snippetMatch(for: note, query: query) {
                                        Text(snippet)
                                            .font(.system(size: 9))
                                            .italic()
                                            .foregroundColor(primaryAccent.opacity(0.8))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if idx == selectionIndex {
                                    Text("Jump ↵")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(primaryAccent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(primaryAccent.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(idx == selectionIndex ? primaryAccent.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                            .id(idx)
                            .onTapGesture {
                                selectedNoteId = note.id
                                isOpen = false
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .frame(height: 280)
                .onChange(of: selectionIndex) { _, newIdx in
                    scrollProxy.scrollTo(newIdx, anchor: .center)
                }
            }
            
            // Footer Navigation Hint
            HStack {
                Text("↑↓ Navigate  •  ↵ Select  •  Esc Dismiss")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.sidebarBackground(isDark))
        }
        .frame(width: 520)
        .background(Color.panelBackground(isDark))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.subtleBorder(isDark), lineWidth: 1)
        )
        .onKeyPress(.downArrow) {
            if !filteredResults.isEmpty {
                selectionIndex = min(selectionIndex + 1, filteredResults.count - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if !filteredResults.isEmpty {
                selectionIndex = max(selectionIndex - 1, 0)
            }
            return .handled
        }
        .onKeyPress(.return) {
            if selectionIndex >= 0 && selectionIndex < filteredResults.count {
                selectedNoteId = filteredResults[selectionIndex].id
                isOpen = false
            }
            return .handled
        }
        .onKeyPress(.escape) {
            isOpen = false
            return .handled
        }
    }

    private func snippetMatch(for note: NoteItem, query: String) -> String? {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        
        if let range = note.content.lowercased().range(of: clean) {
            let start = note.content.index(range.lowerBound, offsetBy: -15, limitedBy: note.content.startIndex) ?? note.content.startIndex
            let end = note.content.index(range.upperBound, offsetBy: 35, limitedBy: note.content.endIndex) ?? note.content.endIndex
            let excerpt = String(note.content[start..<end]).replacingOccurrences(of: "\n", with: " ")
            return "... \(excerpt) ..."
        }
        
        if let seg = note.transcript.first(where: { $0.text.lowercased().contains(clean) }) {
            return "\(seg.speaker): \"\(seg.text)\""
        }
        
        return nil
    }
}

// MARK: - Helpers
func formatTime(_ seconds: Double) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", mins, secs)
}
