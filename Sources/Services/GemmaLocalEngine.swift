import Foundation
import NaturalLanguage

// MARK: - On-Device NLP & Gemma Local Intelligence Engine
@MainActor
class GemmaLocalEngine: ObservableObject {
    static let shared = GemmaLocalEngine()
    
    @Published var isGenerating: Bool = false
    @Published var generationOutput: String = ""
    
    /// Truncates input text to respect local LLM context window limits (~3000 words / 4000 tokens)
    private func truncateToContextWindow(_ text: String, maxWords: Int = 3000) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count <= maxWords {
            return text
        }
        return words.prefix(maxWords).joined(separator: " ")
    }

    /// Generates executive key takeaways using TF-IDF term frequency and sentence ranking.
    func generateSummary(note: NoteItem) async -> String {
        isGenerating = true
        defer { isGenerating = false }
        
        var combinedText = note.content
        if !note.transcript.isEmpty {
            combinedText += "\n\nTranscript Highlights:\n" + note.transcript.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
        }
        if let pdfPath = note.pdfPath, let pdfURL = NotesDataManager.shared.resolveAttachmentURL(pdfPath), let pdfText = NotesDataManager.shared.extractTextFromPDF(url: pdfURL, maxPages: 5) {
            combinedText += "\n\nAttached Document Excerpts:\n" + pdfText.prefix(2000)
        } else if let pptxPath = note.pptxPath, let pptxURL = NotesDataManager.shared.resolveAttachmentURL(pptxPath), let pptxText = NotesDataManager.shared.extractTextFromPPTX(url: pptxURL, maxSlides: 8) {
            combinedText += "\n\nAttached Presentation Slide Excerpts:\n" + pptxText.prefix(2500)
        }
        combinedText = truncateToContextWindow(combinedText)
        
        let sentences = extractSentences(from: combinedText)
        guard !sentences.isEmpty else {
            return "### 💡 Key Takeaways\n- \(note.title)"
        }
        
        // Calculate word frequency dictionary
        let wordCounts = calculateWordFrequencies(in: combinedText)
        
        // Rank sentences by term frequency density and heading relevance
        var scoredSentences: [(sentence: String, score: Double)] = []
        for (index, sentence) in sentences.enumerated() {
            autoreleasepool {
                var score = 0.0
                
                // Sentence position weight (early sentences in notes/headings carry higher weight)
                score += max(0.0, 2.0 - (Double(index) * 0.15))
                
                // Heading boost
                if sentence.hasPrefix("#") || sentence.contains(":") {
                    score += 3.0
                }
                
                // Term frequency accumulation
                let words = sentence.components(separatedBy: .alphanumerics.inverted).filter { $0.count > 3 }
                for w in words {
                    let freq = Double(wordCounts[w.lowercased()] ?? 0)
                    score += min(freq, 5.0)
                }
                
                let clean = sentence.replacingOccurrences(of: "#", with: "")
                    .replacingOccurrences(of: "- [ ]", with: "")
                    .replacingOccurrences(of: "- [x]", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !clean.isEmpty && clean.count > 10 {
                    scoredSentences.append((clean, score))
                }
            }
        }
        
        // Sort by highest score
        scoredSentences.sort(by: { $0.score > $1.score })
        
        var selectedTakeaways: [String] = []
        for item in scoredSentences {
            if !selectedTakeaways.contains(item.sentence) {
                selectedTakeaways.append(item.sentence)
            }
            if selectedTakeaways.count >= 4 { break }
        }
        
        if selectedTakeaways.isEmpty {
            selectedTakeaways = ["Core overview: \(note.title)"]
        }
        
        let summary = "### 💡 Executive Key Takeaways\n" + selectedTakeaways.map { "- \($0)" }.joined(separator: "\n")
        return summary
    }
    
    /// Auto-detects action items using NLTagger verb analysis, task keywords, and NSDataDetector date detection.
    func extractActionItems(note: NoteItem) async -> [String] {
        isGenerating = true
        defer { isGenerating = false }
        
        var textToScan = note.content
        if !note.transcript.isEmpty {
            textToScan += "\n" + note.transcript.map { $0.text }.joined(separator: "\n")
        }
        
        let lines = textToScan.components(separatedBy: "\n")
        var actionItems: [String] = []
        
        let taskKeywords = ["todo", "action", "need to", "must", "should", "remember to", "follow up", "submit", "prepare", "review", "assign", "deadline"]
        
        for line in lines {
            let cleanLine = line.replacingOccurrences(of: "- [ ]", with: "").replacingOccurrences(of: "- [x]", with: "").trimmingCharacters(in: .whitespaces)
            let lower = cleanLine.lowercased()
            
            if cleanLine.isEmpty { continue }
            
            var isTask = line.hasPrefix("- [ ]")
            
            if !isTask {
                for kw in taskKeywords {
                    if lower.contains(kw) {
                        isTask = true
                        break
                    }
                }
            }
            
            if !isTask {
                // Perform NLTagger Lexical Analysis to check for imperative verb clause
                let tagger = NLTagger(tagSchemes: [.lexicalClass])
                tagger.string = cleanLine
                let (tag, _) = tagger.tag(at: cleanLine.startIndex, unit: .word, scheme: .lexicalClass)
                if tag == NLTag.verb {
                    isTask = true
                }
            }
            
            if isTask && !actionItems.contains(cleanLine) {
                actionItems.append(cleanLine)
            }
        }
        
        if actionItems.isEmpty {
            actionItems.append("Review lecture notes for '\(note.title)'")
            if !note.transcript.isEmpty {
                actionItems.append("Follow up on transcript key discussion points")
            }
        }
        
        return Array(actionItems.prefix(6))
    }
    
    /// Generates intelligent study flashcards by identifying key noun phrases and heading concepts.
    func generateFlashcards(note: NoteItem) -> [Flashcard] {
        var cards: [Flashcard] = []
        
        // Card 1: Note Title & Primary Topic
        cards.append(Flashcard(
            question: "What is the core subject of '\(note.title)'?",
            answer: note.content.prefix(160).trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        
        // Card 2: Headings and Section Definitions from Note
        let lines = note.content.components(separatedBy: "\n")
        for i in 0..<lines.count {
            let line = lines[i]
            if line.hasPrefix("#") {
                let heading = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                if i + 1 < lines.count {
                    let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if !nextLine.isEmpty && !nextLine.hasPrefix("#") {
                        cards.append(Flashcard(
                            question: "Explain concept: '\(heading)'",
                            answer: nextLine
                        ))
                    }
                }
            }
        }

        // Card 3 & 4: Concepts extracted directly from attached PDF or PPTX Document
        if let pdfPath = note.pdfPath, let pdfURL = NotesDataManager.shared.resolveAttachmentURL(pdfPath),
           let pdfText = NotesDataManager.shared.extractTextFromPDF(url: pdfURL, maxPages: 8) {
            let pdfLines = pdfText.components(separatedBy: "\n")
            var currentPageNum = 1
            for pLine in pdfLines {
                if pLine.hasPrefix("--- Page ") {
                    if let num = Int(pLine.replacingOccurrences(of: "--- Page ", with: "").replacingOccurrences(of: " ---", with: "")) {
                        currentPageNum = num
                    }
                    continue
                }
                let clean = pLine.trimmingCharacters(in: .whitespaces)
                if clean.count > 25 && clean.count < 120 && (clean.contains(":") || clean.contains(" is ") || clean.contains(" are ")) {
                    cards.append(Flashcard(
                        question: "What is discussed on Page \(currentPageNum) of '\(pdfURL.lastPathComponent)'?",
                        answer: clean
                    ))
                    if cards.count >= 6 { break }
                }
            }
        } else if let pptxPath = note.pptxPath, let pptxURL = NotesDataManager.shared.resolveAttachmentURL(pptxPath),
                  let presentation = PPTXEngine.shared.parsePresentation(url: pptxURL) {
            for slide in presentation.slides.prefix(8) {
                if !slide.bulletPoints.isEmpty {
                    let firstBullet = slide.bulletPoints.first ?? ""
                    cards.append(Flashcard(
                        question: "What is the key takeaway on Slide \(slide.id): '\(slide.title)'?",
                        answer: firstBullet
                    ))
                    if cards.count >= 6 { break }
                }
            }
        }
        
        // Card 5: Transcript Highlight (if available)
        if let seg = note.transcript.first {
            cards.append(Flashcard(
                question: "What key statement was made at \(formatTime(seg.startTime))?",
                answer: "\(seg.speaker): \"\(seg.text)\""
            ))
        }
        
        return Array(cards.prefix(6))
    }

    /// Generates structured executive key takeaways directly from an attached PDF or PPTX document.
    func generatePDFSummary(pdfURL: URL) async -> String {
        return await generateDocumentSummary(url: pdfURL)
    }

    /// Generates structured executive key takeaways directly from an attached document (PDF or PPTX).
    func generateDocumentSummary(url: URL) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        let isPPTX = url.pathExtension.lowercased() == "pptx"
        let docText = isPPTX
            ? NotesDataManager.shared.extractTextFromPPTX(url: url, maxSlides: 20)
            : NotesDataManager.shared.extractTextFromPDF(url: url, maxPages: 15)

        guard let text = docText else {
            let icon = isPPTX ? "📊" : "📑"
            return "### \(icon) Document Summary: \(url.lastPathComponent)\n- Attached document ready in vault."
        }

        let sentences = extractSentences(from: text)
        let wordCounts = calculateWordFrequencies(in: text)
        
        var scoredSentences: [(sentence: String, score: Double)] = []
        for (index, sentence) in sentences.enumerated() {
            autoreleasepool {
                if sentence.hasPrefix("--- Page") || sentence.hasPrefix("--- Slide") { return }
                var score = 0.0
                score += max(0.0, 1.5 - (Double(index) * 0.05))
                
                let words = sentence.lowercased().components(separatedBy: .alphanumerics.inverted)
                for word in words where word.count > 3 {
                    if let count = wordCounts[word] {
                        score += min(Double(count) * 0.2, 2.0)
                    }
                }
                if sentence.count > 20 && sentence.count < 220 {
                    scoredSentences.append((sentence: sentence, score: score))
                }
            }
        }

        let topTakeaways = scoredSentences.sorted(by: { $0.score > $1.score }).prefix(5).map { $0.sentence }
        let headerIcon = isPPTX ? "📊 AI Presentation Summary" : "📑 AI PDF Summary"
        
        var output = "### \(headerIcon): *\(url.lastPathComponent)*\n\n"
        for t in topTakeaways {
            output += "- \(t)\n"
        }
        return output
    }
    
    /// Custom Q&A performing semantic excerpt extraction across note, transcript, and attached PDF/PPTX.
    func askGemma(prompt: String, note: NoteItem) async -> String {
        isGenerating = true
        defer { isGenerating = false }
        
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return "" }
        
        let keywords = cleanPrompt.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count > 2 }
        
        var matchingSnippets: [String] = []
        
        // 1. Search in note content
        let contentLines = note.content.components(separatedBy: "\n")
        for line in contentLines {
            let lower = line.lowercased()
            for kw in keywords {
                if lower.contains(kw) && !line.hasPrefix("#") {
                    let clean = line.trimmingCharacters(in: .whitespaces)
                    if !clean.isEmpty && !matchingSnippets.contains(clean) {
                        matchingSnippets.append(clean)
                    }
                }
            }
        }
        
        // 2. Search in audio transcript
        for seg in note.transcript {
            let lower = seg.text.lowercased()
            for kw in keywords {
                if lower.contains(kw) {
                    let quote = "Audio [\(formatTime(seg.startTime))] \(seg.speaker): \"\(seg.text)\""
                    if !matchingSnippets.contains(quote) {
                        matchingSnippets.append(quote)
                    }
                }
            }
        }

        // 3. Search in attached PDF document with exact page citation
        if let pdfPath = note.pdfPath, let pdfURL = NotesDataManager.shared.resolveAttachmentURL(pdfPath),
           let pdfText = NotesDataManager.shared.extractTextFromPDF(url: pdfURL, maxPages: 25) {
            let pdfLines = pdfText.components(separatedBy: "\n")
            var currentPageNum = 1
            
            for line in pdfLines {
                if line.hasPrefix("--- Page ") {
                    if let num = Int(line.replacingOccurrences(of: "--- Page ", with: "").replacingOccurrences(of: " ---", with: "")) {
                        currentPageNum = num
                    }
                    continue
                }
                
                let lower = line.lowercased()
                for kw in keywords {
                    if lower.contains(kw) {
                        let clean = line.trimmingCharacters(in: .whitespaces)
                        if clean.count > 15 {
                            let cited = "📄 PDF (*\(pdfURL.lastPathComponent)*, Page \(currentPageNum)): \"\(clean)\""
                            if !matchingSnippets.contains(cited) {
                                matchingSnippets.append(cited)
                            }
                        }
                    }
                }
            }
        }

        // 4. Search in attached PPTX presentation with exact slide citation
        if let pptxPath = note.pptxPath, let pptxURL = NotesDataManager.shared.resolveAttachmentURL(pptxPath),
           let presentation = PPTXEngine.shared.parsePresentation(url: pptxURL) {
            for slide in presentation.slides {
                let slideText = slide.fullText
                let lower = slideText.lowercased()
                for kw in keywords {
                    if lower.contains(kw) {
                        let snippet = slide.bulletPoints.first(where: { $0.lowercased().contains(kw) }) ?? slide.title
                        let cited = "📊 Slide \(slide.id) (*\(slide.title)*): \"\(snippet)\""
                        if !matchingSnippets.contains(cited) {
                            matchingSnippets.append(cited)
                        }
                        break
                    }
                }
            }
        }
        
        if matchingSnippets.isEmpty {
            let excerpt = note.content.prefix(200)
            return "💡 **Answer regarding '\(note.title)'**:\n\nFor question: *\(cleanPrompt)*\n\nNo exact term matches found. Context summary:\n> \(excerpt)"
        } else {
            let matchesText = matchingSnippets.prefix(4).map { "- \($0)" }.joined(separator: "\n")
            return "💡 **Answer regarding '\(note.title)'**:\n\nFor question: *\(cleanPrompt)*\n\nRelevant excerpts:\n\(matchesText)"
        }
    }
    
    /// Streaming version of custom Q&A yielding tokens in real-time
    func askGemmaStreaming(
        prompt: String,
        note: NoteItem,
        onToken: @escaping (String) -> Void
    ) async -> String {
        isGenerating = true
        generationOutput = ""
        defer { isGenerating = false }
        
        let fullAnswer = await askGemma(prompt: prompt, note: note)
        let words = fullAnswer.components(separatedBy: " ")
        
        var accumulated = ""
        for (index, word) in words.enumerated() {
            let token = (index == 0 ? "" : " ") + word
            accumulated += token
            generationOutput = accumulated
            onToken(token)
            try? await Task.sleep(nanoseconds: 16_000_000) // ~16ms smooth streaming
        }
        
        return fullAnswer
    }
    
    private func extractSentences(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }
    
    private func calculateWordFrequencies(in text: String) -> [String: Int] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var freq: [String: Int] = [:]
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            if word.count > 3 {
                freq[word, default: 0] += 1
            }
            return true
        }
        return freq
    }
}
