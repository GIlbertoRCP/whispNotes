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

// MARK: - Note Attachment Model
struct NoteAttachment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var fileName: String
    var relativePath: String
    var fileType: String // e.g. "pdf", "audio", "image", "other"
    var dateAdded: Date = Date()
    var fileSize: Int64 = 0
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
    var pdfPath: String?
    var attachments: [NoteAttachment] = []
    
    enum CodingKeys: String, CodingKey {
        case id, title, folder, content, timestamp, audioPath, transcript, isStandalone, bookmarks, pdfPath, attachments
    }

    init(
        id: UUID = UUID(),
        title: String,
        folder: String,
        content: String,
        timestamp: Date,
        audioPath: String? = nil,
        transcript: [TranscriptSegment] = [],
        isStandalone: Bool = true,
        bookmarks: [AudioBookmark] = [],
        pdfPath: String? = nil,
        attachments: [NoteAttachment] = []
    ) {
        self.id = id
        self.title = title
        self.folder = folder
        self.content = content
        self.timestamp = timestamp
        self.audioPath = audioPath
        self.transcript = transcript
        self.isStandalone = isStandalone
        self.bookmarks = bookmarks
        self.pdfPath = pdfPath
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        folder = try container.decode(String.self, forKey: .folder)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        audioPath = try container.decodeIfPresent(String.self, forKey: .audioPath)
        transcript = try container.decodeIfPresent([TranscriptSegment].self, forKey: .transcript) ?? []
        isStandalone = try container.decodeIfPresent(Bool.self, forKey: .isStandalone) ?? true
        bookmarks = try container.decodeIfPresent([AudioBookmark].self, forKey: .bookmarks) ?? []
        pdfPath = try container.decodeIfPresent(String.self, forKey: .pdfPath)
        attachments = try container.decodeIfPresent([NoteAttachment].self, forKey: .attachments) ?? []
    }
}

// MARK: - Edit Mode Type
enum EditModeType: String, Hashable, CaseIterable {
    case edit = "Edit"
    case split = "Split"
    case preview = "Preview"
    case pdf = "PDF"
}
