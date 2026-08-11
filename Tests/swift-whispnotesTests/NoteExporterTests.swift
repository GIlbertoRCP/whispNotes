import XCTest
@testable import WhispNotesLibrary

final class NoteExporterTests: XCTestCase {

    func testMarkdownExportContentFormatting() {
        let note = NoteItem(
            title: "Export Test Note",
            folder: "Lectures",
            content: "# Lecture 1\n\nReferenced from [[Introduction]] #lecture.\n\n- Bullet item",
            timestamp: Date(timeIntervalSince1970: 100000),
            audioPath: nil,
            transcript: [
                TranscriptSegment(speaker: "Speaker 1", text: "Welcome to class", startTime: 0.0, endTime: 3.0)
            ],
            isStandalone: true,
            bookmarks: []
        )
        
        let markdownOutput = NoteExporter.shared.generateMarkdownString(note)
        XCTAssertTrue(markdownOutput.contains("title: \"Export Test Note\""))
        XCTAssertTrue(markdownOutput.contains("folder: \"Lectures\""))
        XCTAssertTrue(markdownOutput.contains("# Lecture 1"))
        XCTAssertTrue(markdownOutput.contains("## Diarized Audio Transcript"))
        XCTAssertTrue(markdownOutput.contains("**Speaker 1** [00:00] : Welcome to class"))
    }
    
    func testHTMLExportConversion() {
        let note = NoteItem(
            title: "HTML Test",
            folder: "General",
            content: "Hello World",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        
        let htmlOutput = NoteExporter.shared.generateHTMLString(note)
        XCTAssertTrue(htmlOutput.contains("<title>HTML Test</title>"))
        XCTAssertTrue(htmlOutput.contains("Hello World"))
        XCTAssertTrue(htmlOutput.contains("<!DOCTYPE html>"))
    }

    func testPlainTextExportConversion() {
        let note = NoteItem(
            title: "Plain Text Test",
            folder: "Ideas",
            content: "# Heading\n\nSome body text",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )
        
        let plainText = NoteExporter.shared.generatePlainTextString(note)
        XCTAssertTrue(plainText.contains("Title: Plain Text Test"))
        XCTAssertTrue(plainText.contains("Folder: Ideas"))
        XCTAssertTrue(plainText.contains("Some body text"))
    }
}
