import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Native Document Exporter Service
class NoteExporter {
    static let shared = NoteExporter()

    // MARK: - Attributed Text Generator (Rich PDF Rendering Engine)
    /// Converts a note and configuration into rich NSAttributedString with markdown parsing, custom typography, borders, and indents.
    func generateAttributedDocument(note: NoteItem, config: ExportConfiguration) -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        let bodyNSFont = config.fontFamily.nsFont(size: config.fontSize.bodySize, weight: .regular)
        let boldBodyNSFont = config.fontFamily.nsFont(size: config.fontSize.bodySize, weight: .bold)
        let italicBodyNSFont = NSFontManager.shared.convert(bodyNSFont, toHaveTrait: .italicFontMask)

        // Calibrated print colors for maximum readability on white paper (independent of Mac dark/light mode)
        let textNSColor = NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1.0)
        let headingNSColor = NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.12, alpha: 1.0)
        let metaNSColor = NSColor(calibratedRed: 0.35, green: 0.40, blue: 0.48, alpha: 1.0)
        let separatorNSColor = NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.88, alpha: 1.0)
        let codeBgNSColor = NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.98, alpha: 1.0)
        let quoteBarNSColor = NSColor(calibratedRed: 0.25, green: 0.35, blue: 0.85, alpha: 1.0)
        let speakerNSColor = NSColor(calibratedRed: 0.10, green: 0.38, blue: 0.84, alpha: 1.0)

        // Paragraph Style
        let defaultParaStyle = NSMutableParagraphStyle()
        defaultParaStyle.lineSpacing = 4.0
        if config.indentStyle == .indentedParagraphs {
            defaultParaStyle.firstLineHeadIndent = config.indentStyle.firstLineIndent
            defaultParaStyle.paragraphSpacing = 4.0
        } else {
            defaultParaStyle.firstLineHeadIndent = 0
            defaultParaStyle.paragraphSpacing = 8.0
        }

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyNSFont,
            .foregroundColor: textNSColor,
            .paragraphStyle: defaultParaStyle
        ]

        // 1. Metadata Header Banner
        if config.includeMetadata {
            // Note Title
            let titleFont = config.fontFamily.nsFont(size: config.fontSize.titleSize, weight: .bold)
            let titleParaStyle = NSMutableParagraphStyle()
            titleParaStyle.paragraphSpacing = 6.0
            attributed.append(NSAttributedString(
                string: "\(note.title)\n",
                attributes: [
                    .font: titleFont,
                    .foregroundColor: headingNSColor,
                    .paragraphStyle: titleParaStyle
                ]
            ))

            // Metadata Chips / Subtitle
            let subtitleFont = config.fontFamily.nsFont(size: config.fontSize.subtitleSize, weight: .medium)
            let dateStr = DateFormatter.localizedString(from: note.timestamp, dateStyle: .medium, timeStyle: .short)
            let wordCount = note.content.split(whereSeparator: \.isWhitespace).count
            let metadataText = "Folder: \(note.folder)   |   Date: \(dateStr)   |   \(wordCount) words\n"

            let subtitleParaStyle = NSMutableParagraphStyle()
            subtitleParaStyle.paragraphSpacing = 10.0
            attributed.append(NSAttributedString(
                string: metadataText,
                attributes: [
                    .font: subtitleFont,
                    .foregroundColor: metaNSColor,
                    .paragraphStyle: subtitleParaStyle
                ]
            ))

            // Divider Line / Card Separator
            if config.borderStyle == .borderedCard || config.borderStyle == .headerDivider {
                let ruleParaStyle = NSMutableParagraphStyle()
                ruleParaStyle.paragraphSpacing = 14.0
                let dividerString = String(repeating: "─", count: 54) + "\n\n"
                attributed.append(NSAttributedString(
                    string: dividerString,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .light),
                        .foregroundColor: separatorNSColor,
                        .paragraphStyle: ruleParaStyle
                    ]
                ))
            }
        }

        // 2. Note Body Content (Markdown Parsing)
        let blocks = parseMarkdownBlocks(note.content)
        for block in blocks {
            switch block {
            case .line(let rawLine):
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    attributed.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
                    continue
                }

                // Heading 1
                if trimmed.hasPrefix("# ") {
                    let text = String(trimmed.dropFirst(2))
                    let h1Font = config.fontFamily.nsFont(size: config.fontSize.h1Size, weight: .bold)
                    let h1Para = NSMutableParagraphStyle()
                    h1Para.paragraphSpacingBefore = 14.0
                    h1Para.paragraphSpacing = 6.0
                    attributed.append(NSAttributedString(string: "\(text)\n", attributes: [
                        .font: h1Font,
                        .foregroundColor: headingNSColor,
                        .paragraphStyle: h1Para
                    ]))
                }
                // Heading 2
                else if trimmed.hasPrefix("## ") {
                    let text = String(trimmed.dropFirst(3))
                    let h2Font = config.fontFamily.nsFont(size: config.fontSize.h2Size, weight: .bold)
                    let h2Para = NSMutableParagraphStyle()
                    h2Para.paragraphSpacingBefore = 10.0
                    h2Para.paragraphSpacing = 4.0
                    attributed.append(NSAttributedString(string: "\(text)\n", attributes: [
                        .font: h2Font,
                        .foregroundColor: headingNSColor,
                        .paragraphStyle: h2Para
                    ]))
                }
                // Heading 3
                else if trimmed.hasPrefix("### ") {
                    let text = String(trimmed.dropFirst(4))
                    let h3Font = config.fontFamily.nsFont(size: config.fontSize.bodySize + 1, weight: .semibold)
                    let h3Para = NSMutableParagraphStyle()
                    h3Para.paragraphSpacingBefore = 8.0
                    h3Para.paragraphSpacing = 4.0
                    attributed.append(NSAttributedString(string: "\(text)\n", attributes: [
                        .font: h3Font,
                        .foregroundColor: headingNSColor,
                        .paragraphStyle: h3Para
                    ]))
                }
                // Bullet List
                else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                    let text = String(trimmed.dropFirst(2))
                    let listPara = NSMutableParagraphStyle()
                    listPara.firstLineHeadIndent = 12.0
                    listPara.headIndent = 24.0
                    listPara.paragraphSpacing = 3.0
                    let bulletStr = NSMutableAttributedString(string: "• ", attributes: [
                        .font: boldBodyNSFont,
                        .foregroundColor: speakerNSColor,
                        .paragraphStyle: listPara
                    ])
                    bulletStr.append(NSAttributedString(string: "\(text)\n", attributes: [
                        .font: bodyNSFont,
                        .foregroundColor: textNSColor,
                        .paragraphStyle: listPara
                    ]))
                    attributed.append(bulletStr)
                }
                // Checklist Task
                else if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") {
                    let isChecked = trimmed.hasPrefix("- [x] ")
                    let text = String(trimmed.dropFirst(6))
                    let listPara = NSMutableParagraphStyle()
                    listPara.firstLineHeadIndent = 12.0
                    listPara.headIndent = 24.0
                    listPara.paragraphSpacing = 3.0
                    let boxStr = isChecked ? "☑ " : "☐ "
                    let boxAttr = NSMutableAttributedString(string: boxStr, attributes: [
                        .font: bodyNSFont,
                        .foregroundColor: isChecked ? NSColor(calibratedRed: 0.1, green: 0.6, blue: 0.3, alpha: 1.0) : metaNSColor,
                        .paragraphStyle: listPara
                    ])
                    boxAttr.append(NSAttributedString(string: "\(text)\n", attributes: [
                        .font: bodyNSFont,
                        .foregroundColor: isChecked ? metaNSColor : textNSColor,
                        .paragraphStyle: listPara
                    ]))
                    attributed.append(boxAttr)
                }
                // Numbered List
                else if let match = trimmed.range(of: "^[0-9]+\\.\\s", options: .regularExpression) {
                    let numPrefix = String(trimmed[match])
                    let text = String(trimmed[match.upperBound...])
                    let listPara = NSMutableParagraphStyle()
                    listPara.firstLineHeadIndent = 12.0
                    listPara.headIndent = 28.0
                    listPara.paragraphSpacing = 3.0
                    let numStr = NSMutableAttributedString(string: numPrefix, attributes: [
                        .font: boldBodyNSFont,
                        .foregroundColor: headingNSColor,
                        .paragraphStyle: listPara
                    ])
                    numStr.append(NSAttributedString(string: "\(text)\n", attributes: [
                        .font: bodyNSFont,
                        .foregroundColor: textNSColor,
                        .paragraphStyle: listPara
                    ]))
                    attributed.append(numStr)
                }
                // Blockquote
                else if trimmed.hasPrefix("> ") {
                    let text = String(trimmed.dropFirst(2))
                    let quotePara = NSMutableParagraphStyle()
                    quotePara.firstLineHeadIndent = 20.0
                    quotePara.headIndent = 20.0
                    quotePara.paragraphSpacing = 4.0
                    let quoteStr = NSMutableAttributedString(string: "│  ", attributes: [
                        .font: boldBodyNSFont,
                        .foregroundColor: quoteBarNSColor,
                        .paragraphStyle: quotePara
                    ])
                    quoteStr.append(NSAttributedString(string: "\(text)\n", attributes: [
                        .font: italicBodyNSFont,
                        .foregroundColor: metaNSColor,
                        .paragraphStyle: quotePara
                    ]))
                    attributed.append(quoteStr)
                }
                // Regular Paragraph
                else {
                    let paraStr = formatInlineMarkdown(trimmed, baseFont: bodyNSFont, boldFont: boldBodyNSFont, italicFont: italicBodyNSFont, textColor: textNSColor, codeBgColor: codeBgNSColor, paraStyle: defaultParaStyle)
                    attributed.append(paraStr)
                    attributed.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
                }

            case .code(let codeText):
                let codePara = NSMutableParagraphStyle()
                codePara.firstLineHeadIndent = 16.0
                codePara.headIndent = 16.0
                codePara.paragraphSpacingBefore = 6.0
                codePara.paragraphSpacing = 8.0
                let codeFont = NSFont.monospacedSystemFont(ofSize: config.fontSize.bodySize - 1, weight: .regular)
                let codeAttrs: [NSAttributedString.Key: Any] = [
                    .font: codeFont,
                    .foregroundColor: textNSColor,
                    .backgroundColor: codeBgNSColor,
                    .paragraphStyle: codePara
                ]
                attributed.append(NSAttributedString(string: "\(codeText)\n", attributes: codeAttrs))

            case .callout(let type, let title, let content):
                let calloutPara = NSMutableParagraphStyle()
                calloutPara.firstLineHeadIndent = 18.0
                calloutPara.headIndent = 18.0
                calloutPara.paragraphSpacing = 3.0
                let calloutHeader = NSMutableAttributedString(
                    string: "▎ [\(type.uppercased())] \(title)\n",
                    attributes: [
                        .font: boldBodyNSFont,
                        .foregroundColor: quoteBarNSColor,
                        .paragraphStyle: calloutPara
                    ]
                )
                for line in content {
                    calloutHeader.append(NSAttributedString(
                        string: "  \(line)\n",
                        attributes: [
                            .font: bodyNSFont,
                            .foregroundColor: textNSColor,
                            .paragraphStyle: calloutPara
                        ]
                    ))
                }
                attributed.append(calloutHeader)

            case .table(let rows):
                let tablePara = NSMutableParagraphStyle()
                tablePara.firstLineHeadIndent = 12.0
                tablePara.headIndent = 12.0
                tablePara.paragraphSpacing = 2.0
                let tableFont = NSFont.monospacedSystemFont(ofSize: config.fontSize.bodySize - 1, weight: .regular)
                for row in rows {
                    attributed.append(NSAttributedString(string: "\(row)\n", attributes: [
                        .font: tableFont,
                        .foregroundColor: textNSColor,
                        .paragraphStyle: tablePara
                    ]))
                }

            case .image(let alt, let path):
                let imgCaption = alt.isEmpty ? "[Image: \(path)]" : "[Image: \(alt) (\(path))]"
                let imgPara = NSMutableParagraphStyle()
                imgPara.paragraphSpacing = 6.0
                attributed.append(NSAttributedString(string: "\(imgCaption)\n", attributes: [
                    .font: italicBodyNSFont,
                    .foregroundColor: metaNSColor,
                    .paragraphStyle: imgPara
                ]))

            case .mermaid(let chart):
                let chartPara = NSMutableParagraphStyle()
                chartPara.firstLineHeadIndent = 16.0
                chartPara.headIndent = 16.0
                chartPara.paragraphSpacing = 6.0
                let chartFont = NSFont.monospacedSystemFont(ofSize: config.fontSize.bodySize - 2, weight: .regular)
                attributed.append(NSAttributedString(string: "[Mermaid Diagram]\n\(chart)\n", attributes: [
                    .font: chartFont,
                    .foregroundColor: metaNSColor,
                    .paragraphStyle: chartPara
                ]))

            case .mathBlock(let math):
                let mathPara = NSMutableParagraphStyle()
                mathPara.alignment = .center
                mathPara.paragraphSpacing = 8.0
                let mathFont = config.fontFamily.nsFont(size: config.fontSize.bodySize + 1, weight: .medium)
                attributed.append(NSAttributedString(string: "$$ \(math) $$\n", attributes: [
                    .font: mathFont,
                    .foregroundColor: headingNSColor,
                    .paragraphStyle: mathPara
                ]))
            }
        }

        // 3. Diarized Audio Transcript Section
        if config.includeTranscript && !note.transcript.isEmpty {
            attributed.append(NSAttributedString(string: "\n", attributes: bodyAttrs))

            let sectionHeaderFont = config.fontFamily.nsFont(size: config.fontSize.h2Size, weight: .bold)
            let sectionPara = NSMutableParagraphStyle()
            sectionPara.paragraphSpacingBefore = 14.0
            sectionPara.paragraphSpacing = 8.0

            if config.borderStyle == .borderedCard || config.borderStyle == .headerDivider {
                let ruleStr = String(repeating: "─", count: 54) + "\n"
                attributed.append(NSAttributedString(
                    string: ruleStr,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .light),
                        .foregroundColor: separatorNSColor,
                        .paragraphStyle: sectionPara
                    ]
                ))
            }

            attributed.append(NSAttributedString(
                string: "Diarized Audio Transcript\n\n",
                attributes: [
                    .font: sectionHeaderFont,
                    .foregroundColor: headingNSColor,
                    .paragraphStyle: sectionPara
                ]
            ))

            for seg in note.transcript {
                let timeStr = formatTime(seg.startTime)
                let speakerPara = NSMutableParagraphStyle()
                speakerPara.firstLineHeadIndent = 8.0
                speakerPara.headIndent = 8.0
                speakerPara.paragraphSpacing = 2.0

                let speakerAttr: [NSAttributedString.Key: Any] = [
                    .font: config.fontFamily.nsFont(size: config.fontSize.subtitleSize + 1, weight: .bold),
                    .foregroundColor: speakerNSColor,
                    .paragraphStyle: speakerPara
                ]
                attributed.append(NSAttributedString(string: "\(seg.speaker) [\(timeStr)]:\n", attributes: speakerAttr))

                let textPara = NSMutableParagraphStyle()
                textPara.firstLineHeadIndent = 16.0
                textPara.headIndent = 16.0
                textPara.paragraphSpacing = 8.0

                attributed.append(NSAttributedString(string: "\(seg.text)\n\n", attributes: [
                    .font: bodyNSFont,
                    .foregroundColor: textNSColor,
                    .paragraphStyle: textPara
                ]))
            }
        }

        return attributed
    }

    /// Helper to format inline bold, italic, and code tags
    private func formatInlineMarkdown(_ text: String, baseFont: NSFont, boldFont: NSFont, italicFont: NSFont, textColor: NSColor, codeBgColor: NSColor, paraStyle: NSParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: paraStyle
        ])

        // Parse inline code `code`
        let codePattern = "`([^`]+)`"
        if let regex = try? NSRegularExpression(pattern: codePattern) {
            let matches = regex.matches(in: result.string, range: NSRange(location: 0, length: result.string.utf16.count))
            for match in matches.reversed() {
                if let codeRange = Range(match.range(at: 1), in: result.string) {
                    let raw = String(result.string[codeRange])
                    let codeFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
                    let codeAttr = NSAttributedString(string: raw, attributes: [
                        .font: codeFont,
                        .foregroundColor: textColor,
                        .backgroundColor: codeBgColor,
                        .paragraphStyle: paraStyle
                    ])
                    result.replaceCharacters(in: match.range, with: codeAttr)
                }
            }
        }

        return result
    }

    // MARK: - PDF Export
    /// Exports note as formatted PDF using NSPrintOperation / NSTextView rendering with selected configuration.
    func exportPDF(_ note: NoteItem, config: ExportConfiguration = .default) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as PDF"
        savePanel.nameFieldStringValue = "\(note.title).pdf"
        savePanel.allowedContentTypes = [UTType.pdf]

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            self.renderPDF(note: note, config: config, to: url)
        }
    }

    /// Direct PDF rendering to a file URL with custom margins, fonts, and borders.
    func renderPDF(note: NoteItem, config: ExportConfiguration, to url: URL) {
        let attributedText = generateAttributedDocument(note: note, config: config)

        let margin = config.marginSize.points
        let pageWidth: CGFloat = 595.2 // Standard A4 (595.2 x 841.8 pt)
        let pageHeight: CGFloat = 841.8
        let printableWidth: CGFloat = pageWidth - (margin * 2)

        let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: printableWidth, height: pageHeight - (margin * 2)))
        printView.textContainer?.containerSize = NSSize(width: printableWidth, height: CGFloat.greatestFiniteMagnitude)
        printView.textContainer?.widthTracksTextView = true
        printView.textStorage?.setAttributedString(attributedText)

        // Calculate used height and scale
        if let layoutManager = printView.layoutManager, let textContainer = printView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let finalHeight = max(usedRect.height + (margin * 2), pageHeight)
            printView.frame = NSRect(x: 0, y: 0, width: printableWidth, height: finalHeight)
        }

        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: pageWidth, height: pageHeight)
        printInfo.topMargin = margin
        printInfo.bottomMargin = margin
        printInfo.leftMargin = margin
        printInfo.rightMargin = margin
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        let data = printView.dataWithPDF(inside: printView.bounds)
        try? data.write(to: url)
    }

    // MARK: - Markdown Export
    /// Generates Markdown string representation of note with custom configuration.
    func generateMarkdownString(_ note: NoteItem, config: ExportConfiguration = .default) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var exportText = ""
        if config.includeMetadata {
            exportText += """
            ---
            title: "\(note.title)"
            folder: "\(note.folder)"
            created: "\(formatter.string(from: note.timestamp))"
            standalone: \(note.isStandalone)
            ---

            # \(note.title)

            """
        }

        exportText += "\(note.content)\n\n"

        if config.includeTranscript && !note.transcript.isEmpty {
            exportText += "## Diarized Audio Transcript\n\n"
            for seg in note.transcript {
                exportText += "**\(seg.speaker)** [\(formatTime(seg.startTime))] : \(seg.text)\n\n"
            }
        }
        return exportText
    }

    /// Legacy overload for backward compatibility
    func generateMarkdownString(_ note: NoteItem) -> String {
        generateMarkdownString(note, config: .default)
    }

    // MARK: - HTML Export
    /// Generates modern, responsive HTML string representation of note with custom styling, fonts, borders, and indents.
    func generateHTMLString(_ note: NoteItem, config: ExportConfiguration = .default) -> String {
        let isDarkTheme = config.theme == .dark
        let isSystemTheme = config.theme == .system

        let fontStack = config.fontFamily.cssFontFamily
        let bodyFontSize = Int(config.fontSize.bodySize)
        let titleFontSize = Int(config.fontSize.titleSize)
        let h1FontSize = Int(config.fontSize.h1Size)
        let h2FontSize = Int(config.fontSize.h2Size)

        // Indent CSS
        let indentCSS = config.indentStyle == .indentedParagraphs ? "p { text-indent: 1.5em; margin-bottom: 0.5em; }" : "p { margin-bottom: 1em; }"

        // Border / Card Frame CSS
        let cardCSS: String
        switch config.borderStyle {
        case .borderedCard:
            cardCSS = """
            .container {
                max-width: 820px;
                margin: 40px auto;
                padding: 44px;
                background: var(--bg-card);
                border: 1.5px solid var(--border-color);
                border-radius: 16px;
                box-shadow: 0 4px 24px rgba(0, 0, 0, 0.12);
            }
            """
        case .headerDivider:
            cardCSS = """
            .container {
                max-width: 820px;
                margin: 40px auto;
                padding: 32px;
                background: var(--bg-main);
            }
            .metadata-header {
                border-bottom: 2px solid var(--border-color);
                padding-bottom: 16px;
                margin-bottom: 28px;
            }
            """
        case .none:
            cardCSS = """
            .container {
                max-width: 820px;
                margin: 40px auto;
                padding: 24px;
                background: var(--bg-main);
            }
            """
        }

        // Markdown content conversion
        let bodyHTML = formatMarkdownToHTML(note.content, config: config)

        // Metadata Header HTML
        var metadataHTML = ""
        if config.includeMetadata {
            let dateStr = DateFormatter.localizedString(from: note.timestamp, dateStyle: .medium, timeStyle: .short)
            let wordCount = note.content.split(whereSeparator: \.isWhitespace).count
            metadataHTML = """
            <div class="metadata-header">
                <h1 class="title">\(Self.htmlEscape(note.title))</h1>
                <div class="meta-badges">
                    <span class="badge folder-badge">\(Self.htmlEscape(note.folder))</span>
                    <span class="badge date-badge">\(dateStr)</span>
                    <span class="badge count-badge">\(wordCount) words</span>
                </div>
            </div>
            """
        }

        // Transcript HTML
        var transcriptHTML = ""
        if config.includeTranscript && !note.transcript.isEmpty {
            transcriptHTML += """
            <div class="transcript-section">
                <h2 class="transcript-title">Transcript</h2>
                <div class="transcript-list">
            """
            for seg in note.transcript {
                let timeStr = formatTime(seg.startTime)
                transcriptHTML += """
                    <div class="segment">
                        <div class="segment-header">
                            <span class="speaker-tag">\(Self.htmlEscape(seg.speaker))</span>
                            <span class="time-tag">\(timeStr)</span>
                        </div>
                        <div class="segment-body">\(Self.htmlEscape(seg.text))</div>
                    </div>
                """
            }
            transcriptHTML += "</div></div>"
        }

        return """
        <!DOCTYPE html>
        <html lang="en" class="\(isDarkTheme ? "dark-theme" : (isSystemTheme ? "system-theme" : "light-theme"))">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(Self.htmlEscape(note.title))</title>
            <style>
                :root {
                    --bg-main: #f1f5f9;
                    --bg-card: #ffffff;
                    --text-primary: #0f172a;
                    --text-secondary: #475569;
                    --border-color: #cbd5e1;
                    --accent: #2563eb;
                    --accent-surface: rgba(37, 99, 235, 0.08);
                    --code-bg: #f8fafc;
                    --quote-border: #4f46e5;
                }

                .dark-theme {
                    --bg-main: #090d16;
                    --bg-card: #131b2b;
                    --text-primary: #f8fafc;
                    --text-secondary: #cbd5e1;
                    --border-color: #2b3b54;
                    --accent: #38bdf8;
                    --accent-surface: rgba(56, 189, 248, 0.14);
                    --code-bg: #1e293b;
                    --quote-border: #818cf8;
                }

                @media (prefers-color-scheme: dark) {
                    .system-theme {
                        --bg-main: #090d16;
                        --bg-card: #131b2b;
                        --text-primary: #f8fafc;
                        --text-secondary: #cbd5e1;
                        --border-color: #2b3b54;
                        --accent: #38bdf8;
                        --accent-surface: rgba(56, 189, 248, 0.14);
                        --code-bg: #1e293b;
                        --quote-border: #818cf8;
                    }
                }

                body {
                    font-family: \(fontStack);
                    font-size: \(bodyFontSize)px;
                    line-height: 1.65;
                    background-color: var(--bg-main);
                    color: var(--text-primary);
                    margin: 0;
                    padding: 0;
                    -webkit-font-smoothing: antialiased;
                }

                \(cardCSS)
                \(indentCSS)

                h1.title {
                    font-size: \(titleFontSize)px;
                    font-weight: 800;
                    letter-spacing: -0.02em;
                    margin: 0 0 12px 0;
                    color: var(--text-primary);
                }

                .meta-badges {
                    display: flex;
                    flex-wrap: wrap;
                    gap: 8px;
                    margin-bottom: 20px;
                }

                .badge {
                    font-size: 0.8em;
                    font-weight: 500;
                    padding: 4px 10px;
                    border-radius: 9999px;
                    background: var(--accent-surface);
                    color: var(--accent);
                    border: 1.5px solid var(--border-color);
                }

                h1, h2, h3, h4 {
                    color: var(--text-primary);
                    font-weight: 700;
                    margin-top: 1.6em;
                    margin-bottom: 0.6em;
                    line-height: 1.3;
                }
                h1 { font-size: \(h1FontSize)px; }
                h2 { font-size: \(h2FontSize)px; }
                h3 { font-size: \(bodyFontSize + 2)px; }

                blockquote {
                    margin: 1.2em 0;
                    padding: 10px 18px;
                    border-left: 4px solid var(--quote-border);
                    background: var(--accent-surface);
                    border-radius: 0 8px 8px 0;
                    color: var(--text-secondary);
                    font-style: italic;
                }

                code {
                    font-family: 'SF Mono', Monaco, Menlo, monospace;
                    font-size: 0.9em;
                    background: var(--code-bg);
                    padding: 2px 6px;
                    border-radius: 4px;
                    border: 1px solid var(--border-color);
                }

                pre {
                    background: var(--code-bg);
                    padding: 16px;
                    border-radius: 8px;
                    border: 1.5px solid var(--border-color);
                    overflow-x: auto;
                    font-family: 'SF Mono', Monaco, Menlo, monospace;
                    font-size: 0.9em;
                    line-height: 1.5;
                }
                pre code {
                    background: none;
                    padding: 0;
                    border: none;
                }

                ul, ol {
                    padding-left: 24px;
                    margin-bottom: 1em;
                }
                li { margin-bottom: 0.35em; }
                ul.checklist { list-style: none; padding-left: 4px; }
                li.task input { margin-right: 6px; vertical-align: -1px; }
                li.task.done { color: var(--text-secondary); text-decoration: line-through; }
                .wikilink { font-weight: 600; border-bottom: 1px dotted currentColor; }
                .timestamp { font-family: ui-monospace, Menlo, monospace; font-size: 0.85em; padding: 0 4px; border-radius: 4px; background: rgba(100, 116, 139, 0.15); }

                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 1.4em 0;
                    font-size: 0.95em;
                }
                th, td {
                    border: 1.5px solid var(--border-color);
                    padding: 10px 14px;
                    text-align: left;
                }
                th {
                    background: var(--code-bg);
                    font-weight: 600;
                }

                .callout {
                    padding: 14px 18px;
                    margin: 1.4em 0;
                    border-radius: 8px;
                    border-left: 4px solid var(--accent);
                    background: var(--accent-surface);
                    border: 1.5px solid var(--border-color);
                    border-left-width: 4px;
                }
                .callout-title {
                    font-weight: 700;
                    margin-bottom: 6px;
                    color: var(--accent);
                }

                .transcript-section {
                    margin-top: 40px;
                    padding-top: 24px;
                    border-top: 1.5px solid var(--border-color);
                }
                .transcript-title {
                    font-size: \(h2FontSize)px;
                    margin-bottom: 16px;
                }
                .segment {
                    margin-bottom: 16px;
                    padding-bottom: 12px;
                    border-bottom: 1px dashed var(--border-color);
                }
                .segment-header {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    margin-bottom: 4px;
                }
                .speaker-tag {
                    font-weight: 700;
                    color: var(--accent);
                    font-size: 0.9em;
                }
                .time-tag {
                    font-family: monospace;
                    color: var(--text-secondary);
                    font-size: 0.8em;
                }
                .segment-body {
                    color: var(--text-primary);
                }

                @media print {
                    body { background: #fff !important; color: #000 !important; }
                    .container { border: none !important; box-shadow: none !important; padding: 0 !important; max-width: 100% !important; }
                    .badge { border: 1px solid #ccc !important; color: #333 !important; }
                }
            </style>
        </head>
        <body>
            <div class="container">
                \(metadataHTML)
                <div class="content">
                    \(bodyHTML)
                </div>
                \(transcriptHTML)
            </div>
        </body>
        </html>
        """
    }

    /// Legacy overload for backward compatibility
    func generateHTMLString(_ note: NoteItem) -> String {
        generateHTMLString(note, config: .default)
    }

    /// Helper to convert markdown into basic semantic HTML
    // MARK: - HTML helpers

    /// Escapes text for HTML element content and attribute values.
    static func htmlEscape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(ch)
            }
        }
        return out
    }

    /// Inline markdown → HTML: code spans, bold, italic, links, [[wiki links]] and play:// timestamps.
    /// Escapes first, then substitutes, so note text can never inject markup.
    static func inlineHTML(_ text: String) -> String {
        var codeSpans: [String] = []
        // Pull code spans out first so their contents aren't formatted.
        var working = text.replacingOccurrences(of: "`([^`]+)`", with: "\u{0}$1\u{0}", options: .regularExpression)
        let parts = working.components(separatedBy: "\u{0}")
        working = ""
        for (i, part) in parts.enumerated() {
            if i % 2 == 1 {
                codeSpans.append("<code>\(htmlEscape(part))</code>")
                working += "\u{1}\(codeSpans.count - 1)\u{1}"
            } else {
                working += part
            }
        }

        var html = htmlEscape(working)
        let rules: [(String, String)] = [
            (#"\[\[([^\]|]+)\|([^\]]+)\]\]"#, "<span class=\"wikilink\">$2</span>"),
            (#"\[\[([^\]]+)\]\]"#, "<span class=\"wikilink\">$1</span>"),
            (#"\[([^\]]+)\]\(play://[^)]*\)"#, "<span class=\"timestamp\">$1</span>"),
            (#"\[([^\]]+)\]\((https?://[^)\s]+)\)"#, "<a href=\"$2\">$1</a>"),
            (#"\*\*([^*]+)\*\*"#, "<strong>$1</strong>"),
            (#"__([^_]+)__"#, "<strong>$1</strong>"),
            (#"(?<![*\w])\*([^*\n]+)\*(?![*\w])"#, "<em>$1</em>"),
            (#"(?<![_\w])_([^_\n]+)_(?![_\w])"#, "<em>$1</em>"),
            (#"~~([^~]+)~~"#, "<del>$1</del>"),
        ]
        for (pattern, template) in rules {
            html = html.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        for (i, span) in codeSpans.enumerated() {
            html = html.replacingOccurrences(of: "\u{1}\(i)\u{1}", with: span)
        }
        return html
    }

    private func formatMarkdownToHTML(_ text: String, config: ExportConfiguration) -> String {
        let blocks = parseMarkdownBlocks(text)
        var html = ""
        /// The list currently open ("ul" or "ol"), so consecutive items share one list.
        var openList: String? = nil

        func closeList() {
            if let tag = openList { html += "</\(tag)>\n"; openList = nil }
        }
        func openListIfNeeded(_ tag: String, className: String? = nil) {
            if openList != tag {
                closeList()
                html += className.map { "<\(tag) class=\"\($0)\">\n" } ?? "<\(tag)>\n"
                openList = tag
            }
        }

        for block in blocks {
            switch block {
            case .line(let rawLine):
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { closeList(); continue }

                if let heading = trimmed.range(of: #"^#{1,6} "#, options: .regularExpression) {
                    closeList()
                    let level = trimmed[heading].filter { $0 == "#" }.count
                    html += "<h\(level)>\(Self.inlineHTML(String(trimmed[heading.upperBound...])))</h\(level)>\n"
                } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                    closeList()
                    html += "<hr>\n"
                } else if let box = trimmed.range(of: #"^[-*+] \[( |x|X)\] "#, options: .regularExpression) {
                    openListIfNeeded("ul", className: "checklist")
                    let checked = trimmed[box].lowercased().contains("x")
                    html += "<li class=\"task\(checked ? " done" : "")\"><input type=\"checkbox\" disabled\(checked ? " checked" : "")> \(Self.inlineHTML(String(trimmed[box.upperBound...])))</li>\n"
                } else if let bullet = trimmed.range(of: #"^[-*+] "#, options: .regularExpression) {
                    openListIfNeeded("ul")
                    html += "<li>\(Self.inlineHTML(String(trimmed[bullet.upperBound...])))</li>\n"
                } else if let number = trimmed.range(of: #"^\d+\. "#, options: .regularExpression) {
                    openListIfNeeded("ol")
                    html += "<li>\(Self.inlineHTML(String(trimmed[number.upperBound...])))</li>\n"
                } else if trimmed.hasPrefix(">") {
                    closeList()
                    html += "<blockquote>\(Self.inlineHTML(trimmed.dropFirst().trimmingCharacters(in: .whitespaces)))</blockquote>\n"
                } else {
                    closeList()
                    html += "<p>\(Self.inlineHTML(trimmed))</p>\n"
                }

            case .code(let code):
                closeList()
                html += "<pre><code>\(Self.htmlEscape(code))</code></pre>\n"

            case .callout(let type, let title, let content):
                closeList()
                let body = content.map { Self.inlineHTML($0) }.joined(separator: "<br>")
                let heading = title.isEmpty ? type.capitalized : title
                html += "<div class=\"callout callout-\(Self.htmlEscape(type.lowercased()))\"><div class=\"callout-title\">\(Self.inlineHTML(heading))</div><div>\(body)</div></div>\n"

            case .table(let rows):
                closeList()
                let parsed: [[String]] = rows.compactMap { row in
                    var cells = row.trimmingCharacters(in: .whitespaces)
                    if cells.hasPrefix("|") { cells.removeFirst() }
                    if cells.hasSuffix("|") { cells.removeLast() }
                    let cols = cells.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    return cols.isEmpty ? nil : cols
                }
                // The |---|:---:| row only sets alignment; it isn't data.
                let isSeparator: ([String]) -> Bool = { cols in
                    cols.allSatisfy { $0.range(of: #"^:?-{2,}:?$"#, options: .regularExpression) != nil }
                }
                let dataRows = parsed.filter { !isSeparator($0) }
                guard let header = dataRows.first else { break }
                html += "<table>\n<thead><tr>" + header.map { "<th>\(Self.inlineHTML($0))</th>" }.joined() + "</tr></thead>\n<tbody>\n"
                for row in dataRows.dropFirst() {
                    html += "<tr>" + row.map { "<td>\(Self.inlineHTML($0))</td>" }.joined() + "</tr>\n"
                }
                html += "</tbody>\n</table>\n"

            case .image(let alt, let path):
                closeList()
                html += "<p><img src=\"\(Self.htmlEscape(path))\" alt=\"\(Self.htmlEscape(alt))\" style=\"max-width: 100%; border-radius: 8px;\"></p>\n"

            case .mermaid(let chart):
                closeList()
                html += "<pre class=\"mermaid\">\(Self.htmlEscape(chart))</pre>\n"

            case .mathBlock(let math):
                closeList()
                html += "<div class=\"math-block\">$$ \(Self.htmlEscape(math)) $$</div>\n"
            }
        }
        closeList()
        return html
    }

    // MARK: - Plain Text Export
    /// Generates structured Plain Text string representation of note with custom indentation and formatting.
    func generatePlainTextString(_ note: NoteItem, config: ExportConfiguration = .default) -> String {
        var exportText = ""
        let indent = config.indentStyle == .indentedParagraphs ? "    " : ""

        if config.includeMetadata {
            let dateStr = DateFormatter.localizedString(from: note.timestamp, dateStyle: .medium, timeStyle: .short)
            if config.borderStyle == .borderedCard {
                let divider = String(repeating: "=", count: 50)
                exportText += "\(divider)\n"
                exportText += "TITLE : \(note.title)\n"
                exportText += "FOLDER: \(note.folder)\n"
                exportText += "DATE  : \(dateStr)\n"
                exportText += "\(divider)\n\n"
            } else {
                exportText += "Title : \(note.title)\n"
                exportText += "Folder: \(note.folder)\n"
                exportText += "Date  : \(dateStr)\n\n"
            }
        }

        if !indent.isEmpty {
            let indentedBody = note.content.components(separatedBy: "\n").map { line in
                line.isEmpty ? "" : "\(indent)\(line)"
            }.joined(separator: "\n")
            exportText += "\(indentedBody)\n\n"
        } else {
            exportText += "\(note.content)\n\n"
        }

        if config.includeTranscript && !note.transcript.isEmpty {
            exportText += "--- DIARIZED TRANSCRIPT ---\n"
            for seg in note.transcript {
                exportText += "\(seg.speaker) [\(formatTime(seg.startTime))]: \(seg.text)\n"
            }
        }
        return exportText
    }

    /// Legacy overload for backward compatibility
    func generatePlainTextString(_ note: NoteItem) -> String {
        generatePlainTextString(note, config: .default)
    }

    // MARK: - Save Dialog Actions
    /// Exports note as Markdown (.md)
    func exportMarkdown(_ note: NoteItem, config: ExportConfiguration = .default) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as Markdown"
        savePanel.nameFieldStringValue = "\(note.title).md"
        savePanel.allowedContentTypes = [UTType.plainText]

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            let exportText = self.generateMarkdownString(note, config: config)
            try? exportText.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Exports note as HTML (.html)
    func exportHTML(_ note: NoteItem, config: ExportConfiguration = .default) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as HTML Web Page"
        savePanel.nameFieldStringValue = "\(note.title).html"
        savePanel.allowedContentTypes = [UTType.html]

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            let html = self.generateHTMLString(note, config: config)
            try? html.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Exports note as Plain Text (.txt)
    func exportPlainText(_ note: NoteItem, config: ExportConfiguration = .default) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as Plain Text"
        savePanel.nameFieldStringValue = "\(note.title).txt"
        savePanel.allowedContentTypes = [UTType.plainText]

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            let exportText = self.generatePlainTextString(note, config: config)
            try? exportText.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Universal exporter routing directly based on configuration format
    func exportNote(_ note: NoteItem, config: ExportConfiguration) {
        switch config.format {
        case .pdf:
            exportPDF(note, config: config)
        case .html:
            exportHTML(note, config: config)
        case .markdown:
            exportMarkdown(note, config: config)
        case .plainText:
            exportPlainText(note, config: config)
        case .srt:
            exportSRT(note)
        case .vtt:
            exportVTT(note)
        }
    }

    /// Exports note audio transcript as SubRip (.srt) subtitle file
    func exportSRT(_ note: NoteItem) {
        guard !note.transcript.isEmpty else { return }
        let savePanel = NSSavePanel()
        savePanel.title = "Export Transcript as Subtitles (.srt)"
        savePanel.nameFieldStringValue = "\(note.title)_subtitles.srt"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "srt") ?? .plainText]

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            var srtOutput = ""
            for (idx, seg) in note.transcript.enumerated() {
                let startStr = self.formatSRTTime(seg.startTime)
                let endStr = self.formatSRTTime(seg.endTime)
                srtOutput += "\(idx + 1)\n\(startStr) --> \(endStr)\n\(seg.speaker): \(seg.text)\n\n"
            }
            try? srtOutput.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Exports note audio transcript as WebVTT (.vtt) file
    func exportVTT(_ note: NoteItem) {
        guard !note.transcript.isEmpty else { return }
        let savePanel = NSSavePanel()
        savePanel.title = "Export Transcript as WebVTT (.vtt)"
        savePanel.nameFieldStringValue = "\(note.title)_subtitles.vtt"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "vtt") ?? .plainText]

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            var vttOutput = "WEBVTT\n\n"
            for seg in note.transcript {
                let startStr = self.formatVTTTime(seg.startTime)
                let endStr = self.formatVTTTime(seg.endTime)
                vttOutput += "\(startStr) --> \(endStr)\n<v \(seg.speaker)>\(seg.text)\n\n"
            }
            try? vttOutput.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func formatSRTTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1.0)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }

    private func formatVTTTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1.0)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    }
}
