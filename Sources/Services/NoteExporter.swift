import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Native Document Exporter Service
class NoteExporter {
    static let shared = NoteExporter()

    /// Exports note as formatted PDF using NSPrintOperation / NSTextView rendering.
    func exportPDF(_ note: NoteItem) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as PDF"
        savePanel.nameFieldStringValue = "\(note.title).pdf"
        savePanel.allowedContentTypes = [UTType.pdf]
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            let attributedText = NSMutableAttributedString()
            
            // Note Title Header
            let titleFont = NSFont.boldSystemFont(ofSize: 22)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: NSColor.labelColor
            ]
            attributedText.append(NSAttributedString(string: "\(note.title)\n\n", attributes: titleAttrs))
            
            // Folder & Timestamp Subtitle
            let subtitleFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let dateStr = DateFormatter.localizedString(from: note.timestamp, dateStyle: .medium, timeStyle: .short)
            attributedText.append(NSAttributedString(string: "Folder: \(note.folder)  •  Date: \(dateStr)\n\n", attributes: subtitleAttrs))
            
            // Note Content
            let bodyFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: NSColor.textColor
            ]
            attributedText.append(NSAttributedString(string: "\(note.content)\n\n", attributes: bodyAttrs))
            
            // Diarized Transcript Section (if present)
            if !note.transcript.isEmpty {
                let transcriptHeaderFont = NSFont.boldSystemFont(ofSize: 16)
                attributedText.append(NSAttributedString(string: "\n--- Diarized Audio Transcript ---\n\n", attributes: [.font: transcriptHeaderFont, .foregroundColor: NSColor.labelColor]))
                
                for seg in note.transcript {
                    let timeStr = formatTime(seg.startTime)
                    let speakerAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: 11),
                        .foregroundColor: NSColor.systemBlue
                    ]
                    attributedText.append(NSAttributedString(string: "\(seg.speaker) [\(timeStr)]:\n", attributes: speakerAttrs))
                    attributedText.append(NSAttributedString(string: "\(seg.text)\n\n", attributes: bodyAttrs))
                }
            }

            // Create off-screen NSTextView and render PDF data
            let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 720))
            printView.textStorage?.setAttributedString(attributedText)
            
            let printInfo = NSPrintInfo.shared
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            printInfo.leftMargin = 36
            printInfo.rightMargin = 36
            printInfo.topMargin = 36
            printInfo.bottomMargin = 36

            let data = printView.dataWithPDF(inside: printView.bounds)
            try? data.write(to: url)
        }
    }

    /// Exports note as Markdown (.md)
    func exportMarkdown(_ note: NoteItem) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as Markdown"
        savePanel.nameFieldStringValue = "\(note.title).md"
        savePanel.allowedContentTypes = [UTType.plainText]
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            var exportText = "# \(note.title)\n\n\(note.content)\n\n"
            if !note.transcript.isEmpty {
                exportText += "## Diarized Audio Transcript\n\n"
                for seg in note.transcript {
                    exportText += "**\(seg.speaker)** [\(formatTime(seg.startTime))] : \(seg.text)\n\n"
                }
            }
            try? exportText.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Exports note as HTML (.html)
    func exportHTML(_ note: NoteItem) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as HTML Web Page"
        savePanel.nameFieldStringValue = "\(note.title).html"
        savePanel.allowedContentTypes = [UTType.html]
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            let bodyHTML = note.content.replacingOccurrences(of: "\n", with: "<br>")
            var transcriptHTML = ""
            if !note.transcript.isEmpty {
                transcriptHTML += "<h2>Diarized Transcript</h2><div class='transcript'>"
                for seg in note.transcript {
                    transcriptHTML += "<div class='segment'><span class='speaker'>\(seg.speaker)</span> <span class='time'>[\(formatTime(seg.startTime))]</span>: \(seg.text)</div>"
                }
                transcriptHTML += "</div>"
            }
            
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset='utf-8'>
                <title>\(note.title)</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background-color: #0f172a; color: #f8fafc; padding: 40px; max-width: 800px; margin: 0 auto; line-height: 1.6; }
                    h1 { color: #38bdf8; border-bottom: 1px solid #334155; padding-bottom: 10px; }
                    .content { background: #1e293b; padding: 24px; border-radius: 12px; border: 1px solid #334155; margin-bottom: 24px; }
                    .transcript { background: #1e293b; padding: 24px; border-radius: 12px; border: 1px solid #334155; }
                    .segment { margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid #334155; }
                    .speaker { font-weight: bold; color: #34d399; }
                    .time { font-family: monospace; color: #94a3b8; font-size: 0.85em; }
                </style>
            </head>
            <body>
                <h1>\(note.title)</h1>
                <div class='content'>\(bodyHTML)</div>
                \(transcriptHTML)
            </body>
            </html>
            """
            try? html.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Exports note as Plain Text (.txt)
    func exportPlainText(_ note: NoteItem) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as Plain Text"
        savePanel.nameFieldStringValue = "\(note.title).txt"
        savePanel.allowedContentTypes = [UTType.plainText]
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            var exportText = "\(note.title)\n\n\(note.content)\n\n"
            if !note.transcript.isEmpty {
                exportText += "TRANSCRIPT:\n"
                for seg in note.transcript {
                    exportText += "\(seg.speaker) [\(formatTime(seg.startTime))]: \(seg.text)\n"
                }
            }
            try? exportText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
