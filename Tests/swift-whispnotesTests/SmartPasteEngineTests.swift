import XCTest
@testable import WhispNotesLibrary

final class SmartPasteEngineTests: XCTestCase {
    
    func testConvertHTMLTableToMarkdown() {
        let html = """
        <h3>Suggested Learning Plan & Resources</h3>
        <p>When theoretical CS textbooks feel dense, the best approach is to supplement the proofs with visual and intuitive explanations:</p>
        <table>
            <thead>
                <tr><th>Resource</th><th>Why It Helps</th></tr>
            </thead>
            <tbody>
                <tr>
                    <td>Michael Sipser — Introduction to the Theory of Computation (Chapters 3 & 4)</td>
                    <td>Considered the clearest modern undergraduate text on Turing machines, undecidability, and diagonalization.</td>
                </tr>
                <tr>
                    <td>Easy Theory (YouTube channel)</td>
                    <td>Walkthrough videos specifically on reduction strategies ($A \\le B$) and Turing machine mechanics.</td>
                </tr>
                <tr>
                    <td>JFLAP (jflap.org)</td>
                    <td>An interactive GUI tool where you can actually build, test, and step through Turing machines cell-by-cell.</td>
                </tr>
            </tbody>
        </table>
        """
        
        let markdown = SmartPasteEngine.shared.convertHTMLToMarkdown(html)
        
        XCTAssertTrue(markdown.contains("### Suggested Learning Plan & Resources"))
        XCTAssertTrue(markdown.contains("| Resource | Why It Helps |"))
        XCTAssertTrue(markdown.contains("| --- | --- |"))
        XCTAssertTrue(markdown.contains("Michael Sipser"))
        XCTAssertTrue(markdown.contains("Easy Theory"))
        XCTAssertTrue(markdown.contains("JFLAP"))
    }
    
    func testConvertHTMLWithKaTeXToMarkdown() {
        let html = """
        <p>A set <span class="katex"><annotation encoding="application/x-tex">A</annotation></span> is recursive if and only if both <span class="katex"><annotation encoding="application/x-tex">A</annotation></span> and its complement <span class="katex"><annotation encoding="application/x-tex">\\overline{A}</annotation></span> are recursively enumerable.</p>
        """
        
        let markdown = SmartPasteEngine.shared.convertHTMLToMarkdown(html)
        XCTAssertTrue(markdown.contains("$A$"))
        XCTAssertTrue(markdown.contains("$\\overline{A}$"))
    }
    
    func testCleanClutteredPlainTextSnippet() {
        let cluttered = """
        The chapter closes by grouping problems into three tiers of difficulty:  Recursive (Decidable): There is an algorithm that always halts and answers correctly (Yes/No).  Recursively Enumerable (Semi-decidable / Acceptable): If the answer is "Yes", a Turing machine will eventually halt and tell you. If the answer is "No", it might run forever in an infinite loop (e.g., set $K$).  Non-r.e. (Completely Uncomputable): Even recognizing a "Yes" cannot be done by a machine (e.g., the complement $\\overline{K}$, machines that never halt).  Fundamental Theorem: A set $A$ is recursive if and only if both $A$ and its complement $\\overline{A}$ are recursively enumerable.  Suggested Learning Plan & ResourcesWhen theoretical CS textbooks feel dense, the best approach is to supplement the proofs with visual and intuitive explanations:ResourceWhy It HelpsMichael Sipser — Introduction to the Theory of Computation (Chapters 3 & 4)Considered the clearest modern undergraduate text on Turing machines, undecidability, and diagonalization.Easy Theory (YouTube channel)Walkthrough videos specifically on reduction strategies ($A \\le B$) and Turing machine mechanics.JFLAP (jflap.org)An interactive GUI tool where you can actually build, test, and step through Turing machines cell-by-cell instead of reading static state tables.
        """
        
        let cleaned = SmartPasteEngine.shared.cleanClutteredPlainText(cluttered)
        
        // Definitions should be bulleted
        XCTAssertTrue(cleaned.contains("- **Recursive (Decidable):**"))
        XCTAssertTrue(cleaned.contains("- **Recursively Enumerable (Semi-decidable / Acceptable):**"))
        XCTAssertTrue(cleaned.contains("- **Non-r.e. (Completely Uncomputable):**"))
        XCTAssertTrue(cleaned.contains("**Fundamental Theorem:**"))
        
        // Glued header should be promoted and separated
        XCTAssertTrue(cleaned.contains("### Suggested Learning Plan & Resources"))
        XCTAssertTrue(cleaned.contains("When theoretical CS textbooks feel dense"))
        
        // Table should be formatted with markdown pipes
        XCTAssertTrue(cleaned.contains("| Resource | Why It Helps |"))
        XCTAssertTrue(cleaned.contains("| --- | --- |"))
    }
}
