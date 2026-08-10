import Foundation

// MARK: - Whisper Model Info
struct WhisperModelInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let fileName: String
    let sizeMB: Int
    let description: String
    let downloadURL: URL
}

// MARK: - Gemma Model Info
struct GemmaModelInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let fileName: String
    let sizeMB: Int
    let description: String
    let downloadURL: URL
}
