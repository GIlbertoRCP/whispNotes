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

    func testAudioWaveformExtractorFallbackPeaks() {
        let dummyURL = URL(fileURLWithPath: "/non_existent_path.wav")
        let expectation = XCTestExpectation(description: "Waveform extraction fallback peaks")
        
        AudioWaveformExtractor.shared.extractPeaks(from: dummyURL, targetSampleCount: 20) { peaks in
            XCTAssertEqual(peaks.count, 20)
            XCTAssertGreaterThanOrEqual(peaks.first ?? 0, 0.05)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}
