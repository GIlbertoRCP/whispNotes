import XCTest
import AppKit
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
        XCTAssertTrue(plainText.contains("Title : Plain Text Test") || plainText.contains("TITLE : Plain Text Test"))
        XCTAssertTrue(plainText.contains("Folder: Ideas") || plainText.contains("FOLDER: Ideas"))
        XCTAssertTrue(plainText.contains("Some body text"))
    }

    func testExportConfigurationDefaults() {
        let config = ExportConfiguration.default
        XCTAssertEqual(config.format, .pdf)
        XCTAssertEqual(config.fontFamily, .sansSerif)
        XCTAssertEqual(config.fontSize, .medium)
        XCTAssertEqual(config.borderStyle, .borderedCard)
        XCTAssertEqual(config.indentStyle, .blockParagraphs)
        XCTAssertEqual(config.marginSize, .standard)
        XCTAssertTrue(config.includeMetadata)
        XCTAssertTrue(config.includeTranscript)
    }

    func testAttributedDocumentGenerationWithCustomFonts() {
        let note = NoteItem(
            title: "Serif Research Paper",
            folder: "Academic",
            content: "# Abstract\n\nThis paper examines the influence of typography on comprehension.\n\n> Important quote on design.\n\n* Key finding 1\n* Key finding 2",
            timestamp: Date(),
            audioPath: nil,
            transcript: [
                TranscriptSegment(speaker: "Prof. Smith", text: "Welcome everyone.", startTime: 12.0, endTime: 15.0)
            ],
            isStandalone: false,
            bookmarks: []
        )

        var serifConfig = ExportConfiguration.default
        serifConfig.fontFamily = .serif
        serifConfig.fontSize = .large
        serifConfig.indentStyle = .indentedParagraphs
        serifConfig.borderStyle = .borderedCard

        let attrDoc = NoteExporter.shared.generateAttributedDocument(note: note, config: serifConfig)
        XCTAssertGreaterThan(attrDoc.length, 0)
        XCTAssertTrue(attrDoc.string.contains("Serif Research Paper"))
        XCTAssertTrue(attrDoc.string.contains("Folder: Academic"))
        XCTAssertTrue(attrDoc.string.contains("Abstract"))
        XCTAssertTrue(attrDoc.string.contains("This paper examines"))
        XCTAssertTrue(attrDoc.string.contains("Prof. Smith"))

        // Monospace font test
        var monoConfig = ExportConfiguration.default
        monoConfig.fontFamily = .monospace
        let monoDoc = NoteExporter.shared.generateAttributedDocument(note: note, config: monoConfig)
        XCTAssertGreaterThan(monoDoc.length, 0)
    }

    func testHTMLExportWithEditorialSerifAndFramedCard() {
        let note = NoteItem(
            title: "Literature Review",
            folder: "Books",
            content: "First paragraph of notes.\n\nSecond paragraph with details.",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )

        var config = ExportConfiguration.default
        config.fontFamily = .serif
        config.borderStyle = .borderedCard
        config.indentStyle = .indentedParagraphs

        let html = NoteExporter.shared.generateHTMLString(note, config: config)
        XCTAssertTrue(html.contains("'New York', 'Georgia'"))
        XCTAssertTrue(html.contains(".container {"))
        XCTAssertTrue(html.contains("border: 1px solid var(--border-color);"))
        XCTAssertTrue(html.contains("text-indent: 1.5em;"))
    }

    func testPlainTextExportWithIndentedStyleAndBorders() {
        let note = NoteItem(
            title: "Architecture Spec",
            folder: "Engineering",
            content: "Line 1\nLine 2",
            timestamp: Date(),
            audioPath: nil,
            transcript: [],
            isStandalone: true,
            bookmarks: []
        )

        var config = ExportConfiguration.default
        config.borderStyle = .borderedCard
        config.indentStyle = .indentedParagraphs

        let plainText = NoteExporter.shared.generatePlainTextString(note, config: config)
        XCTAssertTrue(plainText.contains("====="))
        XCTAssertTrue(plainText.contains("TITLE : Architecture Spec"))
        XCTAssertTrue(plainText.contains("    Line 1"))
    }
}
