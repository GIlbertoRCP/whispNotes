import Foundation

// MARK: - PPTX Slide Model
struct PPTXSlide: Identifiable, Hashable {
    var id: Int // Slide number (1-based)
    var title: String
    var bulletPoints: [String]
    var speakerNotes: String?
    var tables: [[String]] = []
    
    var fullText: String {
        var components: [String] = []
        if !title.isEmpty {
            components.append("# " + title)
        }
        for bullet in bulletPoints {
            components.append("• " + bullet)
        }
        for row in tables {
            components.append("| " + row.joined(separator: " | ") + " |")
        }
        if let notes = speakerNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append("Presenter Notes: " + notes)
        }
        return components.joined(separator: "\n")
    }
}

// MARK: - PPTX Presentation Model
final class PPTXPresentation: NSObject {
    let url: URL
    let title: String
    let slides: [PPTXSlide]
    
    var slideCount: Int {
        slides.count
    }
    
    init(url: URL, title: String, slides: [PPTXSlide]) {
        self.url = url
        self.title = title
        self.slides = slides
        super.init()
    }
    
    var fullText: String {
        slides.enumerated().map { index, slide in
            "--- Slide \(index + 1): \(slide.title.isEmpty ? "Untitled Slide" : slide.title) ---\n" + slide.fullText
        }.joined(separator: "\n\n")
    }
}

// MARK: - In-Memory PPTX Document Cache
final class PPTXDocumentCache {
    static let shared = PPTXDocumentCache()
    
    private let cache = NSCache<NSURL, PPTXPresentation>()
    private let loaderQueue = DispatchQueue(label: "com.whispnotes.pptxcache", qos: .userInitiated)
    
    private init() {
        cache.countLimit = 20
        cache.totalCostLimit = 1024 * 1024 * 256 // 256MB memory limit
    }
    
    func cachedPresentation(for url: URL) -> PPTXPresentation? {
        cache.object(forKey: url as NSURL)
    }
    
    func setPresentation(_ presentation: PPTXPresentation, for url: URL) {
        cache.setObject(presentation, forKey: url as NSURL)
    }
    
    func invalidate(url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
    
    func clearAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Native Swift OpenXML PPTX Parsing Engine
final class PPTXEngine {
    static let shared = PPTXEngine()
    
    private let parseQueue = DispatchQueue(label: "com.whispnotes.pptxengine", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Public API
    
    /// Parses a PowerPoint (.pptx) file into a structured PPTXPresentation model.
    func parsePresentation(url: URL) -> PPTXPresentation? {
        if let cached = PPTXDocumentCache.shared.cachedPresentation(for: url) {
            return cached
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("whisp_pptx_\(UUID().uuidString)")
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 1. Unzip PPTX archive safely
        guard unzipFile(at: url, to: tempDir) else {
            return nil
        }
        
        // 2. Parse Presentation metadata & slide ordering
        let presentationTitle = extractPresentationTitle(from: tempDir, fallbackFileName: url.deletingPathExtension().lastPathComponent)
        let slideFiles = discoverSlideFiles(in: tempDir)
        
        var slides: [PPTXSlide] = []
        
        for (index, slideURL) in slideFiles.enumerated() {
            let slideNumber = index + 1
            let (slideTitle, bullets, tables) = parseSlideXML(url: slideURL)
            let notes = parseSlideNotes(in: tempDir, slideNumber: slideNumber)
            
            let slide = PPTXSlide(
                id: slideNumber,
                title: slideTitle.isEmpty ? "Slide \(slideNumber)" : slideTitle,
                bulletPoints: bullets,
                speakerNotes: notes,
                tables: tables
            )
            slides.append(slide)
        }
        
        let presentation = PPTXPresentation(url: url, title: presentationTitle, slides: slides)
        PPTXDocumentCache.shared.setPresentation(presentation, for: url)
        return presentation
    }
    
    /// Asynchronously parses a PowerPoint (.pptx) file.
    func parsePresentationAsync(url: URL) async -> PPTXPresentation? {
        if let cached = PPTXDocumentCache.shared.cachedPresentation(for: url) {
            return cached
        }
        
        return await withCheckedContinuation { continuation in
            parseQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                let presentation = self.parsePresentation(url: url)
                continuation.resume(returning: presentation)
            }
        }
    }
    
    /// Extracts plain text from a PPTX document with a max slide limit.
    func extractText(url: URL, maxSlides: Int = 15) -> String? {
        guard let presentation = parsePresentation(url: url) else { return nil }
        let total = presentation.slides.count
        let limit = min(total, maxSlides)
        
        var textComponents: [String] = []
        for i in 0..<limit {
            let slide = presentation.slides[i]
            textComponents.append("--- Slide \(slide.id): \(slide.title) ---\n" + slide.fullText)
        }
        
        if total > limit {
            textComponents.append("\n[... Presentation continues for \(total - limit) more slides ...]\n")
        }
        
        let clean = textComponents.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
    
    /// Asynchronously extracts text from a PPTX presentation for AI assistants and background indexing.
    func extractFullTextAsync(url: URL, maxSlides: Int = 50) async -> String? {
        guard let presentation = await parsePresentationAsync(url: url) else { return nil }
        let total = presentation.slides.count
        let limit = min(total, maxSlides)
        
        var textComponents: [String] = []
        for i in 0..<limit {
            let slide = presentation.slides[i]
            textComponents.append("--- Slide \(slide.id): \(slide.title) ---\n" + slide.fullText)
        }
        
        if total > limit {
            textComponents.append("\n[... Presentation continues for \(total - limit) more slides ...]\n")
        }
        
        let clean = textComponents.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
    
    // MARK: - Internal OpenXML Unpacking & XML Parsing
    
    private func unzipFile(at sourceURL: URL, to destinationURL: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", sourceURL.path, "-d", destinationURL.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func extractPresentationTitle(from rootDir: URL, fallbackFileName: String) -> String {
        let corePropsURL = rootDir.appendingPathComponent("docProps/core.xml")
        if let data = try? Data(contentsOf: corePropsURL),
           let content = String(data: data, encoding: .utf8) {
            if let titleMatch = extractXMLTagContent(tag: "dc:title", in: content), !titleMatch.isEmpty {
                return titleMatch
            }
        }
        return fallbackFileName
    }
    
    private func discoverSlideFiles(in rootDir: URL) -> [URL] {
        let slidesDir = rootDir.appendingPathComponent("ppt/slides")
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: slidesDir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        // Filter slide*.xml and sort numerically (slide1.xml, slide2.xml, ..., slide10.xml)
        let slideFiles = files.filter {
            $0.lastPathComponent.hasPrefix("slide") && $0.pathExtension == "xml"
        }.sorted { url1, url2 in
            let num1 = extractNumber(from: url1.lastPathComponent)
            let num2 = extractNumber(from: url2.lastPathComponent)
            return num1 < num2
        }
        
        return slideFiles
    }
    
    private func extractNumber(from fileName: String) -> Int {
        let digits = fileName.filter { $0.isNumber }
        return Int(digits) ?? 0
    }
    
    private func parseSlideXML(url: URL) -> (title: String, bullets: [String], tables: [[String]]) {
        guard let data = try? Data(contentsOf: url),
              let xmlString = String(data: data, encoding: .utf8) else {
            return ("", [], [])
        }
        
        var title = ""
        var bullets: [String] = []
        var tables: [[String]] = []
        
        // Extract slide title
        // In PowerPoint XML, titles are often marked in <p:ph type="title"> or <p:ph type="ctrTitle">
        title = extractSlideTitle(from: xmlString)
        
        // Extract paragraph texts from shapes
        let paragraphs = extractParagraphs(from: xmlString)
        for p in paragraphs {
            let clean = p.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && clean != title {
                bullets.append(clean)
            }
        }
        
        // Extract tables if present
        tables = extractTables(from: xmlString)
        
        return (title, bullets, tables)
    }
    
    private func extractSlideTitle(from xml: String) -> String {
        // Pattern 1: Find shape with type="title" or type="ctrTitle"
        let titleShapePattern = "(?s)<p:sp>.*?<p:ph[^>]*?type=\"(title|ctrTitle)\"[^>]*?>.*?</p:sp>"
        if let regex = try? NSRegularExpression(pattern: titleShapePattern, options: []) {
            let nsRange = NSRange(xml.startIndex..., in: xml)
            if let match = regex.firstMatch(in: xml, range: nsRange),
               let matchRange = Range(match.range, in: xml) {
                let shapeXML = String(xml[matchRange])
                let text = extractTextRuns(from: shapeXML)
                if !text.isEmpty {
                    return text
                }
            }
        }
        
        // Pattern 2: First paragraph in slide
        let paragraphs = extractParagraphs(from: xml)
        if let first = paragraphs.first, !first.isEmpty {
            return first
        }
        
        return ""
    }
    
    private func extractParagraphs(from xml: String) -> [String] {
        var results: [String] = []
        // Match each <a:p> ... </a:p>
        let pPattern = "(?s)<a:p>.*?</a:p>"
        guard let regex = try? NSRegularExpression(pattern: pPattern, options: []) else { return [] }
        
        let nsRange = NSRange(xml.startIndex..., in: xml)
        let matches = regex.matches(in: xml, range: nsRange)
        
        for match in matches {
            if let range = Range(match.range, in: xml) {
                let pXML = String(xml[range])
                let text = extractTextRuns(from: pXML)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    results.append(trimmed)
                }
            }
        }
        
        return results
    }
    
    private func extractTextRuns(from pXML: String) -> String {
        var full = ""
        // Match <a:t>...</a:t>
        let tPattern = "(?s)<a:t>(.*?)</a:t>"
        guard let regex = try? NSRegularExpression(pattern: tPattern, options: []) else { return "" }
        
        let nsRange = NSRange(pXML.startIndex..., in: pXML)
        let matches = regex.matches(in: pXML, range: nsRange)
        
        for match in matches {
            if match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: pXML) {
                let text = String(pXML[range])
                full += decodeXMLEntities(text)
            }
        }
        return full
    }
    
    private func extractTables(from xml: String) -> [[String]] {
        var tableRows: [[String]] = []
        let trPattern = "(?s)<a:tr[^>]*?>.*?</a:tr>"
        guard let trRegex = try? NSRegularExpression(pattern: trPattern, options: []) else { return [] }
        
        let nsRange = NSRange(xml.startIndex..., in: xml)
        let rowMatches = trRegex.matches(in: xml, range: nsRange)
        
        for rowMatch in rowMatches {
            if let rowRange = Range(rowMatch.range, in: xml) {
                let rowXML = String(xml[rowRange])
                let cells = extractCells(from: rowXML)
                if !cells.isEmpty {
                    tableRows.append(cells)
                }
            }
        }
        return tableRows
    }
    
    private func extractCells(from rowXML: String) -> [String] {
        var cells: [String] = []
        let tcPattern = "(?s)<a:tc[^>]*?>.*?</a:tc>"
        guard let tcRegex = try? NSRegularExpression(pattern: tcPattern, options: []) else { return [] }
        
        let nsRange = NSRange(rowXML.startIndex..., in: rowXML)
        let cellMatches = tcRegex.matches(in: rowXML, range: nsRange)
        
        for cellMatch in cellMatches {
            if let cellRange = Range(cellMatch.range, in: rowXML) {
                let cellXML = String(rowXML[cellRange])
                let text = extractTextRuns(from: cellXML).trimmingCharacters(in: .whitespacesAndNewlines)
                cells.append(text)
            }
        }
        return cells
    }
    
    private func parseSlideNotes(in rootDir: URL, slideNumber: Int) -> String? {
        let notesDir = rootDir.appendingPathComponent("ppt/notesSlides")
        let notesURL = notesDir.appendingPathComponent("notesSlide\(slideNumber).xml")
        guard let data = try? Data(contentsOf: notesURL),
              let xml = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let paragraphs = extractParagraphs(from: xml)
        // Filter out default template headers/page numbers
        let clean = paragraphs.filter { p in
            let lower = p.lowercased()
            return !lower.contains("slide") && p != "\(slideNumber)"
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        return clean.isEmpty ? nil : clean
    }
    
    private func extractXMLTagContent(tag: String, in xml: String) -> String? {
        let pattern = "<\(tag)[^>]*?>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let nsRange = NSRange(xml.startIndex..., in: xml)
        if let match = regex.firstMatch(in: xml, range: nsRange),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: xml) {
            return decodeXMLEntities(String(xml[range]))
        }
        return nil
    }
    
    private func decodeXMLEntities(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}
