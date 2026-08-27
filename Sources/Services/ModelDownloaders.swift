import Foundation

// MARK: - Whisper Model Downloader Manager
@MainActor
class WhisperModelDownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = WhisperModelDownloader()
    
    @Published var downloadingModelId: String? = nil
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedModelIds: Set<String> = []
    @Published var statusMessage: String = "Ready"
    
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
    
    nonisolated static var whisperDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("com.whispnotes.app/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var downloadTask: URLSessionDownloadTask?
    private var activeSession: URLSession?
    
    override init() {
        super.init()
        checkDownloadedModels()
    }
    
    func checkDownloadedModels() {
        let dir = Self.whisperDirectory
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
        statusMessage = "Starting download of \(model.name)..."
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 1800.0
        config.waitsForConnectivity = true
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        self.activeSession = session
        self.downloadTask = session.downloadTask(with: model.downloadURL)
        self.downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        activeSession?.invalidateAndCancel()
        activeSession = nil
        downloadingModelId = nil
        downloadProgress = 0.0
        statusMessage = "Download Cancelled"
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let httpResponse = downloadTask.response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 200
        
        guard statusCode == 200 else {
            Task { @MainActor in
                self.statusMessage = "Download failed: Server returned HTTP \(statusCode)"
                self.downloadingModelId = nil
                self.downloadProgress = 0.0
                self.activeSession = nil
            }
            return
        }
        
        let dir = Self.whisperDirectory
        
        // Match target filename based on download URL or fallback to base model
        let reqURL = downloadTask.originalRequest?.url ?? downloadTask.currentRequest?.url
        let fileName: String
        let modelDisplayName: String
        
        if let url = reqURL {
            let lastComponent = url.lastPathComponent
            if lastComponent.contains("tiny") {
                fileName = "ggml-tiny.bin"
                modelDisplayName = "Tiny"
            } else if lastComponent.contains("small") {
                fileName = "ggml-small.bin"
                modelDisplayName = "Small"
            } else {
                fileName = "ggml-base.bin"
                modelDisplayName = "Base"
            }
        } else {
            fileName = "ggml-base.bin"
            modelDisplayName = "Base"
        }
        
        let destURL = dir.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }
        
        var isSuccess = false
        var errorMsg: String? = nil
        
        do {
            try FileManager.default.moveItem(at: location, to: destURL)
            isSuccess = true
        } catch {
            do {
                try FileManager.default.copyItem(at: location, to: destURL)
                isSuccess = true
            } catch let copyErr {
                errorMsg = copyErr.localizedDescription
            }
        }
        
        let finalSuccess = isSuccess
        let finalName = modelDisplayName
        let finalError = errorMsg
        
        Task { @MainActor in
            if finalSuccess {
                self.checkDownloadedModels()
                self.statusMessage = "\(finalName) downloaded and ready"
            } else {
                self.statusMessage = "Failed to save model: \(finalError ?? "Unknown error")"
            }
            self.downloadingModelId = nil
            self.downloadProgress = 0.0
            self.activeSession = nil
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let mbWritten = Double(totalBytesWritten) / (1024 * 1024)
            let mbTotal = Double(totalBytesExpectedToWrite) / (1024 * 1024)
            Task { @MainActor in
                self.downloadProgress = progress
                self.statusMessage = String(format: "Downloading: %.1f MB / %.1f MB (%.0f%%)", mbWritten, mbTotal, progress * 100)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error {
            let errorText = err.localizedDescription
            let isCancelled = (err as NSError).code == NSURLErrorCancelled
            Task { @MainActor in
                if !isCancelled {
                    self.statusMessage = "Download error: \(errorText)"
                }
                self.downloadingModelId = nil
                self.downloadProgress = 0.0
                self.activeSession = nil
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
    
    nonisolated static var gemmaDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.whispnotes.app/models/gemma")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    var modelFileURL: URL {
        Self.gemmaDirectory.appendingPathComponent(defaultModel.fileName)
    }
    
    private var downloadTask: URLSessionDownloadTask?
    private var activeSession: URLSession?
    
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
        statusMessage = "Starting download of Gemma 2B (1.6 GB)..."
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 7200.0
        config.waitsForConnectivity = true
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        self.activeSession = session
        self.downloadTask = session.downloadTask(with: defaultModel.downloadURL)
        self.downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        activeSession?.invalidateAndCancel()
        activeSession = nil
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
        
        guard statusCode == 200 else {
            Task { @MainActor in
                self.statusMessage = "Download failed: Server returned HTTP \(statusCode)"
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.activeSession = nil
            }
            return
        }
        
        let destURL = Self.gemmaDirectory.appendingPathComponent("gemma-2-2b-it.gguf")
        
        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }
        
        var isSuccess = false
        var errorMsg: String? = nil
        do {
            try FileManager.default.moveItem(at: location, to: destURL)
            isSuccess = true
        } catch {
            do {
                try FileManager.default.copyItem(at: location, to: destURL)
                isSuccess = true
            } catch let copyErr {
                errorMsg = copyErr.localizedDescription
            }
        }
        
        let finalSuccess = isSuccess
        let finalError = errorMsg
        
        Task { @MainActor in
            if finalSuccess {
                self.checkDownloadedStatus()
                self.statusMessage = "Gemma 2B Downloaded & Ready"
            } else {
                self.statusMessage = "Download failed to save: \(finalError ?? "Unknown error")"
            }
            self.isDownloading = false
            self.downloadProgress = 0.0
            self.activeSession = nil
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let mbWritten = Double(totalBytesWritten) / (1024 * 1024)
            let mbTotal = Double(totalBytesExpectedToWrite) / (1024 * 1024)
            Task { @MainActor in
                self.downloadProgress = progress
                self.statusMessage = String(format: "Downloading: %.1f MB / %.1f MB (%.0f%%)", mbWritten, mbTotal, progress * 100)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error {
            let errorText = err.localizedDescription
            let isCancelled = (err as NSError).code == NSURLErrorCancelled
            Task { @MainActor in
                if !isCancelled {
                    self.statusMessage = "Download error: \(errorText)"
                }
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.activeSession = nil
            }
        }
    }
}
