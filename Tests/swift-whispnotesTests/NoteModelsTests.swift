import XCTest
@testable import swift_whispnotes

final class NoteModelsTests: XCTestCase {
    
    func testNoteItemEncodingDecoding() throws {
        let originalNote = NoteItem(
            title: "Unit Test Note",
            folder: "Test Folder",
            content: "# Test Content\nThis is a test note.",
            timestamp: Date(timeIntervalSince1970: 100000),
            audioPath: "/tmp/test.wav",
            transcript: [
                TranscriptSegment(speaker: "Speaker 1", text: "Hello test", startTime: 0.0, endTime: 2.5)
            ],
            isStandalone: false,
            bookmarks: [
                AudioBookmark(time: 1.2, label: "Flag 1")
            ]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalNote)
        
        let decoder = JSONDecoder()
        let decodedNote = try decoder.decode(NoteItem.self, from: data)
        
        XCTAssertEqual(decodedNote.id, originalNote.id)
        XCTAssertEqual(decodedNote.title, "Unit Test Note")
        XCTAssertEqual(decodedNote.folder, "Test Folder")
        XCTAssertEqual(decodedNote.content, "# Test Content\nThis is a test note.")
        XCTAssertEqual(decodedNote.audioPath, "/tmp/test.wav")
        XCTAssertEqual(decodedNote.isStandalone, false)
        XCTAssertEqual(decodedNote.transcript.count, 1)
        XCTAssertEqual(decodedNote.transcript.first?.speaker, "Speaker 1")
        XCTAssertEqual(decodedNote.bookmarks.count, 1)
        XCTAssertEqual(decodedNote.bookmarks.first?.label, "Flag 1")
    }
    
    func testBackwardCompatibilityDecodingMissingBookmarks() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "title": "Legacy Note",
            "folder": "General",
            "content": "Legacy content",
            "timestamp": 1700000000.0,
            "transcript": [],
            "isStandalone": true
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let note = try decoder.decode(NoteItem.self, from: json)
        
        XCTAssertEqual(note.title, "Legacy Note")
        XCTAssertTrue(note.bookmarks.isEmpty)
        XCTAssertNil(note.audioPath)
    }
}
