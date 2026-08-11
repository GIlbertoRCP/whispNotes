import XCTest
@testable import WhispNotesLibrary

final class TranscriptTests: XCTestCase {
    
    func testTranscriptSegmentCreation() {
        let segment = TranscriptSegment(
            speaker: "Speaker 1",
            text: "Welcome to class.",
            startTime: 0.0,
            endTime: 2.4
        )
        
        XCTAssertEqual(segment.speaker, "Speaker 1")
        XCTAssertEqual(segment.text, "Welcome to class.")
        XCTAssertEqual(segment.startTime, 0.0)
        XCTAssertEqual(segment.endTime, 2.4)
    }
    
    func testMarkdownBlockParsing() {
        let markdown = """
        # Header Line
        Normal paragraph
        
        | Col 1 | Col 2 |
        | --- | --- |
        | Val 1 | Val 2 |
        
        ```swift
        print("hello")
        ```
        """
        
        let blocks = parseMarkdownBlocks(markdown)
        XCTAssertGreaterThanOrEqual(blocks.count, 4)
        
        var foundCode = false
        var foundTable = false
        
        for block in blocks {
            switch block {
            case .code(let str):
                XCTAssertTrue(str.contains("print(\"hello\")"))
                foundCode = true
            case .table(let lines):
                XCTAssertEqual(lines.count, 3)
                foundTable = true
            default:
                break
            }
        }
        
        XCTAssertTrue(foundCode)
        XCTAssertTrue(foundTable)
    }
}
