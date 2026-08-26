import Foundation

// MARK: - Whisper Model Downloader Manager
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
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 600.0
        config.waitsForConnectivity = true
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
        let httpResponse = downloadTask.response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 200
        
        Task { @MainActor in
            guard statusCode == 200 else {
                print("Whisper download failed: Server returned HTTP \(statusCode)")
                self.downloadingModelId = nil
                self.downloadProgress = 0.0
                return
            }
            
            guard let modelId = self.downloadingModelId,
                  let model = self.availableModels.first(where: { $0.id == modelId }) else { return }
            
            let dir = LocalSpeechTranscriber.modelDirectory
            _ = try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let destURL = dir.appendingPathComponent(model.fileName)
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

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error {
            Task { @MainActor in
                print("Download error: \(err.localizedDescription)")
                self.downloadingModelId = nil
                self.downloadProgress = 0.0
            }
        }
    }
}

// MARK: - Gemma 3 AI Model Downloader Manager
@MainActor
class GemmaModelDownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = GemmaModelDownloader()
    
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloaded: Bool = false
    @Published var statusMessage: String = "Ready"
    
    let defaultModel = GemmaModelInfo(
        id: "gemma-2-2b-it.gguf",
        name: "Gemma 2 2B (Instruct Q4_K_M)",
        fileName: "gemma-2-2b-it.gguf",
        sizeMB: 1640,
        description: "Google's lightweight 2B parameter on-device AI assistant for summarization, task extraction, and Q&A.",
        downloadURL: URL(string: "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf")!
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
        statusMessage = "Downloading Gemma 2B (1.6 GB)..."
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 3600.0
        config.waitsForConnectivity = true
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
        let httpResponse = downloadTask.response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 200
        
        Task { @MainActor in
            guard statusCode == 200 else {
                self.statusMessage = "Download failed: Server returned HTTP \(statusCode)"
                self.isDownloading = false
                self.downloadProgress = 0.0
                return
            }
            
            let destURL = self.modelFileURL
            _ = try? FileManager.default.createDirectory(at: Self.modelDirectory, withIntermediateDirectories: true)
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

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error {
            Task { @MainActor in
                if (err as NSError).code != NSURLErrorCancelled {
                    self.statusMessage = "Download error: \(err.localizedDescription)"
                }
                self.isDownloading = false
                self.downloadProgress = 0.0
            }
        }
    }
}
