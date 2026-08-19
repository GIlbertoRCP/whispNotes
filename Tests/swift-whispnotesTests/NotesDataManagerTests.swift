import XCTest
@testable import WhispNotesLibrary

final class NotesDataManagerTests: XCTestCase {
    
    func testWordAndCharCountCalculation() {
        let text = "Hello world! This is WhispNotes.\nSecond line with words."
        let (words, chars) = calculateWordAndCharCount(text)
        
        XCTAssertEqual(words, 9)
        XCTAssertGreaterThan(chars, 30)
    }
    
    func testEmptyTextWordCount() {
        let (words, chars) = calculateWordAndCharCount("   \n  ")
        XCTAssertEqual(words, 0)
        XCTAssertEqual(chars, 0)
    }
    
    func testFormatTimeHelper() {
        XCTAssertEqual(formatTime(0.0), "00:00")
        XCTAssertEqual(formatTime(65.0), "01:05")
        XCTAssertEqual(formatTime(3605.0), "60:05")
    }

    func testNoteItemPDFAndAttachmentEncodingDecoding() throws {
        let noteId = UUID()
        let attachment = NoteAttachment(
            fileName: "lecture_slides.pdf",
            relativePath: "\(noteId.uuidString.prefix(8))_lecture_slides.pdf",
            fileType: "pdf",
            fileSize: 102400
        )
        let note = NoteItem(
            id: noteId,
            title: "Calculus Lecture 1",
            folder: "Math",
            content: "# Calculus\n\nIntegrals and Derivatives",
            timestamp: Date(),
            audioPath: "audio_1.m4a",
            transcript: [],
            isStandalone: true,
            bookmarks: [],
            pdfPath: attachment.relativePath,
            attachments: [attachment]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(note)
        
        let decoder = JSONDecoder()
        let decodedNote = try decoder.decode(NoteItem.self, from: data)
        
        XCTAssertEqual(decodedNote.id, noteId)
        XCTAssertEqual(decodedNote.title, "Calculus Lecture 1")
        XCTAssertEqual(decodedNote.pdfPath, attachment.relativePath)
        XCTAssertEqual(decodedNote.attachments.count, 1)
        XCTAssertEqual(decodedNote.attachments.first?.fileName, "lecture_slides.pdf")
    }

    func testNotesDataManagerAttachmentResolution() {
        let manager = NotesDataManager.shared
        let dummyName = "test_non_existent_\(UUID().uuidString).pdf"
        let resolved = manager.resolveAttachmentURL(dummyName)
        XCTAssertNil(resolved)
    }
}
