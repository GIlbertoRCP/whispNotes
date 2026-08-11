import XCTest
@testable import WhispNotesLibrary

final class WikiLinkParserTests: XCTestCase {
    
    func testParseLineTokensWikiLinksAndHashtags() {
        let line = "Referenced from [[Lecture Notes]] with #lecture tag."
        let tokens = parseLineTokens(line)
        
        XCTAssertEqual(tokens.count, 4)
        
        if case .text(let prefix) = tokens[0].type {
            XCTAssertEqual(prefix, "Referenced from ")
        } else {
            XCTFail("Expected text token")
        }
        
        if case .wikiLink(let title) = tokens[1].type {
            XCTAssertEqual(title, "Lecture Notes")
        } else {
            XCTFail("Expected wiki link token")
        }
        
        if case .text(let mid) = tokens[2].type {
            XCTAssertEqual(mid, " with ")
        } else {
            XCTFail("Expected text token")
        }
        
        if case .hashtag(let tag) = tokens[3].type {
            XCTAssertEqual(tag, "lecture")
        } else {
            XCTFail("Expected hashtag token")
        }
    }
    
    func testParsePlayLinkToken() {
        let line = "Jump to timestamp: [01:23](play://83.5)"
        let tokens = parseLineTokens(line)
        
        XCTAssertEqual(tokens.count, 2)
        if case .playLink(let label, let seconds) = tokens[1].type {
            XCTAssertEqual(label, "01:23")
            XCTAssertEqual(seconds, 83.5)
        } else {
            XCTFail("Expected play link token")
        }
    }
}
