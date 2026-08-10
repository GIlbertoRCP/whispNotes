import Foundation

// MARK: - Audio Bookmark Model
struct AudioBookmark: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var time: Double
    var label: String
}

// MARK: - Transcript Segment Model
struct TranscriptSegment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var speaker: String
    var text: String
    var startTime: Double
    var endTime: Double
}

// MARK: - Note Item Model
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

// MARK: - Edit Mode Type
enum EditModeType: String, Hashable, CaseIterable {
    case edit = "Edit"
    case split = "Split"
    case preview = "Preview"
}
