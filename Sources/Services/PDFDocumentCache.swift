import Foundation
import PDFKit

// MARK: - In-Memory PDF Document Cache
/// High-performance thread-safe cache to avoid re-parsing large (500+ page) PDFs on UI transitions.
final class PDFDocumentCache {
    static let shared = PDFDocumentCache()
    
    private let cache = NSCache<NSURL, PDFDocument>()
    private let loaderQueue = DispatchQueue(label: "com.whispnotes.pdfcache", qos: .userInitiated)

    private init() {
        cache.countLimit = 15
        cache.totalCostLimit = 1024 * 1024 * 512 // 512MB memory limit
    }

    /// Instant non-blocking retrieval from memory if already parsed.
    func cachedDocument(for url: URL) -> PDFDocument? {
        let key = url as NSURL
        return cache.object(forKey: key)
    }

    /// Retrieves or loads a PDFDocument instance from cache (synchronous fallback).
    func document(for url: URL) -> PDFDocument? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        if let doc = PDFDocument(url: url) {
            cache.setObject(doc, forKey: key)
            return doc
        }
        return nil
    }

    /// Asynchronously loads a PDFDocument in background without blocking the main UI thread.
    func loadDocumentAsync(for url: URL, completion: @escaping (PDFDocument?) -> Void) {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        loaderQueue.async { [weak self] in
            guard let self = self else { return }
            let doc = PDFDocument(url: url)
            if let doc = doc {
                self.cache.setObject(doc, forKey: key)
            }
            DispatchQueue.main.async {
                completion(doc)
            }
        }
    }

    /// Invalidates cache for a specific URL if modified.
    func invalidate(url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    /// Clears all cached documents to free system memory.
    func clearAll() {
        cache.removeAllObjects()
    }
}
