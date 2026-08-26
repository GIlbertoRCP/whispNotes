import XCTest
@testable import WhispNotesLibrary

final class PPTXEngineTests: XCTestCase {
    
    func testPPTXSlideModelFormatting() {
        let slide = PPTXSlide(
            id: 1,
            title: "Introduction to Neural Networks",
            bulletPoints: [
                "Perceptrons and multi-layer networks",
                "Backpropagation algorithm",
                "Activation functions (ReLU, GELU)"
            ],
            speakerNotes: "Remember to emphasize non-linear activations.",
            tables: [["Layer", "Units"], ["Input", "784"], ["Hidden", "128"]]
        )
        
        XCTAssertEqual(slide.id, 1)
        XCTAssertEqual(slide.title, "Introduction to Neural Networks")
        XCTAssertEqual(slide.bulletPoints.count, 3)
        XCTAssertEqual(slide.tables.count, 3)
        XCTAssertNotNil(slide.speakerNotes)
        
        let fullText = slide.fullText
        XCTAssertTrue(fullText.contains("# Introduction to Neural Networks"))
        XCTAssertTrue(fullText.contains("• Perceptrons and multi-layer networks"))
        XCTAssertTrue(fullText.contains("Presenter Notes: Remember to emphasize non-linear activations."))
        XCTAssertTrue(fullText.contains("| Layer | Units |"))
    }
    
    func testPPTXPresentationModelAndCache() {
        let dummyURL = URL(fileURLWithPath: "/tmp/test_deck.pptx")
        let slides = [
            PPTXSlide(id: 1, title: "Slide 1: Overview", bulletPoints: ["Point A", "Point B"], speakerNotes: nil),
            PPTXSlide(id: 2, title: "Slide 2: Architecture", bulletPoints: ["Point C"], speakerNotes: "Key note")
        ]
        let presentation = PPTXPresentation(url: dummyURL, title: "Test Presentation", slides: slides)
        
        XCTAssertEqual(presentation.title, "Test Presentation")
        XCTAssertEqual(presentation.slideCount, 2)
        XCTAssertTrue(presentation.fullText.contains("--- Slide 1: Slide 1: Overview ---"))
        XCTAssertTrue(presentation.fullText.contains("--- Slide 2: Slide 2: Architecture ---"))
        
        // Test Cache storage & retrieval
        PPTXDocumentCache.shared.setPresentation(presentation, for: dummyURL)
        let cached = PPTXDocumentCache.shared.cachedPresentation(for: dummyURL)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.title, "Test Presentation")
        XCTAssertEqual(cached?.slideCount, 2)
        
        // Test Invalidation
        PPTXDocumentCache.shared.invalidate(url: dummyURL)
        XCTAssertNil(PPTXDocumentCache.shared.cachedPresentation(for: dummyURL))
    }
    
    func testNoteItemPPTXHelperProperties() {
        var note = NoteItem(
            title: "Lecture 5 Notes",
            folder: "CS101",
            content: "Lecture on Deep Learning",
            timestamp: Date()
        )
        
        XCTAssertEqual(note.documentType, .none)
        XCTAssertFalse(note.hasAttachedDocument)
        XCTAssertNil(note.attachedDocumentPath)
        
        // Attach PPTX
        note.pptxPath = "cs101_lec5.pptx"
        XCTAssertEqual(note.documentType, .pptx)
        XCTAssertTrue(note.hasAttachedDocument)
        XCTAssertEqual(note.attachedDocumentPath, "cs101_lec5.pptx")
        
        // PDF fallback check
        var pdfNote = NoteItem(
            title: "Reading Assignment",
            folder: "CS101",
            content: "Research Paper",
            timestamp: Date(),
            pdfPath: "paper.pdf"
        )
        XCTAssertEqual(pdfNote.documentType, .pdf)
        XCTAssertTrue(pdfNote.hasAttachedDocument)
        XCTAssertEqual(pdfNote.attachedDocumentPath, "paper.pdf")
    }
}
