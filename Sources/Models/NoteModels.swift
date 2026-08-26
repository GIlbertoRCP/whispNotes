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

// MARK: - Document Attachment Type
enum DocumentAttachmentType: String, Codable, Hashable {
    case none
    case pdf
    case pptx
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
    var pptxPath: String?
    var attachments: [NoteAttachment] = []
    var isPinned: Bool = false
    var originalFolder: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, title, folder, content, timestamp, audioPath, transcript, isStandalone, bookmarks, pdfPath, pptxPath, attachments, isPinned, originalFolder
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
        pptxPath: String? = nil,
        attachments: [NoteAttachment] = [],
        isPinned: Bool = false,
        originalFolder: String? = nil
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
        self.pptxPath = pptxPath
        self.attachments = attachments
        self.isPinned = isPinned
        self.originalFolder = originalFolder
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
        pptxPath = try container.decodeIfPresent(String.self, forKey: .pptxPath)
        attachments = try container.decodeIfPresent([NoteAttachment].self, forKey: .attachments) ?? []
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        originalFolder = try container.decodeIfPresent(String.self, forKey: .originalFolder)
    }

    /// Returns the active attached document type (.pdf, .pptx, or .none)
    var documentType: DocumentAttachmentType {
        if pptxPath != nil {
            return .pptx
        } else if pdfPath != nil {
            return .pdf
        }
        return .none
    }

    /// Returns true if either a PDF or PPTX is attached
    var hasAttachedDocument: Bool {
        return pdfPath != nil || pptxPath != nil
    }

    /// Returns the relative path to the attached document (PDF or PPTX)
    var attachedDocumentPath: String? {
        return pptxPath ?? pdfPath
    }
}

// MARK: - Edit Mode Type
enum EditModeType: String, Hashable, CaseIterable {
    case edit = "Edit"
    case split = "Split"
    case preview = "Preview"
    case pdf = "PDF"
    case pptx = "Slides"
}
