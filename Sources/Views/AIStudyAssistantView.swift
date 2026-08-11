import SwiftUI

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
        gemmaEngine.generateFlashcards(note: note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
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
