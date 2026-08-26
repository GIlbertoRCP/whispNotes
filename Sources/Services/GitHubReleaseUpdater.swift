import Foundation
import SwiftUI
import AppKit

// MARK: - Release Metadata Model
public struct GitHubReleaseInfo: Codable, Identifiable, Equatable {
    public var id: String { tagName }
    public let tagName: String
    public let name: String
    public let body: String
    public let publishedAt: String
    public let htmlUrl: String
    public let dmgDownloadUrl: String?
    public let dmgSize: Int64
    
    public var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: publishedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return publishedAt
    }
}

// MARK: - Update Lifecycle States
public enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(release: GitHubReleaseInfo)
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case readyToInstall(fileURL: URL, release: GitHubReleaseInfo)
    case installing
    case error(String)
}

// MARK: - Native GitHub Release Auto-Updater
public class GitHubReleaseUpdater: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = GitHubReleaseUpdater()
    
    @Published public var status: UpdateStatus = .idle
    @Published public var showUpdateModal = false
    @Published public var latestRelease: GitHubReleaseInfo? = nil
    @Published public var lastCheckDate: Date? = nil
    
    @AppStorage("autoCheckForUpdates") public var autoCheckForUpdates = true
    
    private let repoOwner = "GIlbertoRCP"
    private let repoName = "whispNotes"
    
    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    
    public var currentVersion: String {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !ver.isEmpty {
            return ver
        }
        return "1.5.0"
    }

    override private init() {
        super.init()
    }
    
    // MARK: - Version Comparison
    public static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "v", with: "")
        let cleanLocal = local.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "v", with: "")
        
        let remoteComponents = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let localComponents = cleanLocal.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(remoteComponents.count, localComponents.count)
        for i in 0..<maxCount {
            let r = i < remoteComponents.count ? remoteComponents[i] : 0
            let l = i < localComponents.count ? localComponents[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
    
    // MARK: - Check for Updates
    public func checkForUpdates(silent: Bool = false) {
        if case .checking = status { return }
        if case .downloading = status { return }
        if case .installing = status { return }
        
        if !silent {
            status = .checking
        }
        
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            if !silent { status = .error("Invalid update URL") }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("WhispNotes-AutoUpdater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.lastCheckDate = Date()
                
                if let error = error {
                    if !silent { self.status = .error(error.localizedDescription) }
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    if !silent { self.status = .error("Failed to parse update information.") }
                    return
                }
                
                let tagName = json["tag_name"] as? String ?? ""
                let name = json["name"] as? String ?? tagName
                let body = json["body"] as? String ?? "No release notes provided."
                let publishedAt = json["published_at"] as? String ?? ""
                let htmlUrl = json["html_url"] as? String ?? "https://github.com/\(self.repoOwner)/\(self.repoName)/releases"
                
                var dmgUrl: String? = nil
                var dmgSize: Int64 = 0
                
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let assetName = asset["name"] as? String,
                           let downloadUrl = asset["browser_download_url"] as? String {
                            if assetName.lowercased().hasSuffix(".dmg") || assetName.lowercased().hasSuffix(".zip") {
                                dmgUrl = downloadUrl
                                dmgSize = (asset["size"] as? NSNumber)?.int64Value ?? 0
                                break
                            }
                        }
                    }
                }
                
                let release = GitHubReleaseInfo(
                    tagName: tagName,
                    name: name,
                    body: body,
                    publishedAt: publishedAt,
                    htmlUrl: htmlUrl,
                    dmgDownloadUrl: dmgUrl,
                    dmgSize: dmgSize
                )
                
                self.latestRelease = release
                
                if Self.isVersion(tagName, newerThan: self.currentVersion) {
                    self.status = .updateAvailable(release: release)
                    self.showUpdateModal = true
                } else {
                    self.status = .upToDate(version: self.currentVersion)
                    if !silent {
                        self.showUpdateModal = true
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Download & Install
    public func startDownload(release: GitHubReleaseInfo) {
        guard let urlString = release.dmgDownloadUrl, let url = URL(string: urlString) else {
            // Fallback: open release page in browser
            openReleaseInBrowser(release)
            return
        }
        
        status = .downloading(progress: 0.0, bytesWritten: 0, totalBytes: release.dmgSize)
        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        if let rel = latestRelease {
            status = .updateAvailable(release: rel)
        } else {
            status = .idle
        }
    }
    
    public func openReleaseInBrowser(_ release: GitHubReleaseInfo? = nil) {
        let target = release ?? latestRelease
        if let urlStr = target?.htmlUrl, let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
            NSWorkspace.shared.open(fallback)
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : (latestRelease?.dmgSize ?? 1)
        let progress = min(1.0, max(0.0, Double(totalBytesWritten) / Double(expected)))
        
        DispatchQueue.main.async {
            self.status = .downloading(progress: progress, bytesWritten: totalBytesWritten, totalBytes: expected)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let release = latestRelease else { return }
        
        // Move downloaded file to persistent temporary directory
        let ext = (release.dmgDownloadUrl?.lowercased().hasSuffix(".zip") == true) ? "zip" : "dmg"
        let tempDir = FileManager.default.temporaryDirectory
        let destination = tempDir.appendingPathComponent("WhispNotes_\(release.tagName).\(ext)")
        
        try? FileManager.default.removeItem(at: destination)
        
        do {
            try FileManager.default.copyItem(at: location, to: destination)
            DispatchQueue.main.async {
                self.status = .readyToInstall(fileURL: destination, release: release)
            }
        } catch {
            DispatchQueue.main.async {
                self.status = .error("Failed to save downloaded update: \(error.localizedDescription)")
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            DispatchQueue.main.async {
                self.status = .error("Download failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 1-Click Install & Relaunch
    public func installAndRelaunch(fileURL: URL) {
        status = .installing
        
        DispatchQueue.global(qos: .userInitiated).async {
            let path = fileURL.path
            
            // If it's a DMG, mount it and open it or guide the user
            if path.hasSuffix(".dmg") {
                // Open DMG in Finder so user gets the standard Drag-to-Applications or automated installer
                NSWorkspace.shared.open(fileURL)
                
                DispatchQueue.main.async {
                    self.status = .idle
                    self.showUpdateModal = false
                }
            } else if path.hasSuffix(".zip") {
                // Unzip and open
                NSWorkspace.shared.open(fileURL)
                DispatchQueue.main.async {
                    self.status = .idle
                    self.showUpdateModal = false
                }
            }
        }
    }
}
