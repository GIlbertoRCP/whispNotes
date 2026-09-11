import SwiftUI
import AppKit

// MARK: - Interactive Document Export Studio Modal
struct NoteExportModalView: View {
    @Binding var isOpen: Bool
    let note: NoteItem
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color

    @State private var config: ExportConfiguration = .default
    @State private var copiedToClipboard: Bool = false

    init(
        isOpen: Binding<Bool>,
        note: NoteItem,
        isDark: Bool,
        primaryAccent: Color,
        secondaryAccent: Color
    ) {
        self._isOpen = isOpen
        self.note = note
        self.isDark = isDark
        self.primaryAccent = primaryAccent
        self.secondaryAccent = secondaryAccent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()
                .background(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))

            // Two-Column Split: Customization Panel & Live Canvas
            HStack(spacing: 0) {
                // Left Column: Configuration Controls
                controlsColumn
                    .frame(minWidth: 320, idealWidth: 340, maxWidth: 360)

                Divider()
                    .background(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))

                // Right Column: Live Document Preview
                previewColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
                .background(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))

            // Footer Action Bar
            footerBar
        }
        .frame(minWidth: 840, idealWidth: 980, maxWidth: 1280, minHeight: 560, idealHeight: 680, maxHeight: .infinity)
        .background(isDark ? Color(red: 0.08, green: 0.10, blue: 0.14) : Color(red: 0.96, green: 0.97, blue: 0.99))
        .onAppear {
            if note.transcript.isEmpty {
                config.includeTranscript = false
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(primaryAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("DOCUMENT EXPORT STUDIO")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(isDark ? .white : Color(red: 0.08, green: 0.10, blue: 0.15))

                Text("Configure custom fonts, borders, indentation, and page formatting with live preview")
                    .font(.caption)
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.85) : Color(red: 0.35, green: 0.40, blue: 0.50))
            }

            Spacer()

            Button(action: { isOpen = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Close Studio (Esc)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(isDark ? Color(red: 0.08, green: 0.10, blue: 0.14) : Color(red: 0.96, green: 0.97, blue: 0.99))
    }

    // MARK: - Controls Column
    private var controlsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Export Format Selector
                formatSelectorSection

                // 2. Typography & Fonts Section
                typographySection

                // 3. Page Layout, Borders & Indentation
                layoutAndBordersSection

                // 4. Content Inclusions & Metadata
                contentInclusionSection
            }
            .padding(18)
        }
        .background(isDark ? Color(red: 0.09, green: 0.11, blue: 0.16) : Color(red: 0.95, green: 0.96, blue: 0.98))
    }

    // MARK: - Format Selector Section
    private var formatSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("EXPORT FORMAT")

            let availableFormats: [ExportFormat] = note.transcript.isEmpty
                ? [.pdf, .html, .markdown, .plainText]
                : ExportFormat.allCases

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(availableFormats) { format in
                    Button(action: { config.format = format }) {
                        HStack(spacing: 8) {
                            Image(systemName: format.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(config.format == format ? primaryAccent : (isDark ? Color(red: 0.65, green: 0.72, blue: 0.85) : Color(red: 0.40, green: 0.45, blue: 0.55)))

                            Text(format.shortTitle)
                                .font(.system(size: 11, weight: config.format == format ? .bold : .medium))
                                .foregroundColor(config.format == format ? (isDark ? .white : Color(red: 0.08, green: 0.10, blue: 0.15)) : (isDark ? Color(red: 0.85, green: 0.88, blue: 0.95) : Color(red: 0.20, green: 0.25, blue: 0.35)))
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Text(".\(format.fileExtension)")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(config.format == format ? primaryAccent : (isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.4)))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .fill(config.format == format ? primaryAccent.opacity(isDark ? 0.20 : 0.12) : (isDark ? Color(red: 0.13, green: 0.16, blue: 0.23) : Color.white))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(config.format == format ? primaryAccent : (isDark ? Color(red: 0.20, green: 0.25, blue: 0.35) : Color(red: 0.85, green: 0.88, blue: 0.92)), lineWidth: config.format == format ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Typography Section
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("TYPOGRAPHY & FONT FAMILY")

            VStack(spacing: 6) {
                ForEach(ExportFontFamily.allCases) { family in
                    Button(action: { config.fontFamily = family }) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(config.fontFamily == family ? primaryAccent : Color.clear)
                                .frame(width: 7, height: 7)
                                .overlay(
                                    Circle()
                                        .stroke(config.fontFamily == family ? primaryAccent : (isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.25)), lineWidth: 1.5)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(family.displayName)
                                    .font(.system(size: 11, weight: config.fontFamily == family ? .bold : .medium, design: family.fontDesign))
                                    .foregroundColor(config.fontFamily == family ? (isDark ? .white : Color(red: 0.08, green: 0.10, blue: 0.15)) : (isDark ? Color(red: 0.85, green: 0.88, blue: 0.95) : Color(red: 0.20, green: 0.25, blue: 0.35)))

                                Text(family.samplePreview)
                                    .font(.system(size: 10, design: family.fontDesign))
                                    .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.80) : Color(red: 0.40, green: 0.45, blue: 0.55))
                            }

                            Spacer()

                            if config.fontFamily == family {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(primaryAccent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .fill(config.fontFamily == family ? primaryAccent.opacity(isDark ? 0.20 : 0.12) : (isDark ? Color(red: 0.13, green: 0.16, blue: 0.23) : Color.white))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(config.fontFamily == family ? primaryAccent : (isDark ? Color(red: 0.20, green: 0.25, blue: 0.35) : Color(red: 0.85, green: 0.88, blue: 0.92)), lineWidth: config.fontFamily == family ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Font Size Pill Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Font Scale:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.85) : Color(red: 0.35, green: 0.40, blue: 0.50))

                customSegmentedPicker(
                    options: ExportFontSize.allCases,
                    selection: $config.fontSize,
                    label: { $0.shortTitle }
                )
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Page Layout & Borders Section
    private var layoutAndBordersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("BORDERS & INDENTATION")

            // Border Style
            VStack(alignment: .leading, spacing: 4) {
                Text("Document Framing:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.85) : Color(red: 0.35, green: 0.40, blue: 0.50))

                customSegmentedPicker(
                    options: ExportBorderStyle.allCases,
                    selection: $config.borderStyle,
                    label: { $0.shortTitle }
                )
            }

            // Indentation Style
            VStack(alignment: .leading, spacing: 4) {
                Text("Paragraph Indent:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.85) : Color(red: 0.35, green: 0.40, blue: 0.50))

                customSegmentedPicker(
                    options: ExportIndentStyle.allCases,
                    selection: $config.indentStyle,
                    label: { $0.shortTitle }
                )
            }

            // Margin Size
            VStack(alignment: .leading, spacing: 4) {
                Text("Page Margins:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.85) : Color(red: 0.35, green: 0.40, blue: 0.50))

                customSegmentedPicker(
                    options: ExportMarginSize.allCases,
                    selection: $config.marginSize,
                    label: { $0.shortTitle }
                )
            }
        }
    }

    // MARK: - Content Inclusions Section
    private var contentInclusionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("CONTENT INCLUSIONS")

            Toggle(isOn: $config.includeMetadata) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Metadata Banner")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDark ? .white : Color(red: 0.10, green: 0.12, blue: 0.18))
                    Text("Include title, folder, date, and stats")
                        .font(.system(size: 10))
                        .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.80) : Color(red: 0.40, green: 0.45, blue: 0.55))
                }
            }
            .toggleStyle(.checkbox)

            if !note.transcript.isEmpty {
                Toggle(isOn: $config.includeTranscript) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Diarized Audio Transcript")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isDark ? .white : Color(red: 0.10, green: 0.12, blue: 0.18))
                        Text("Include speaker dialogue and timestamps")
                            .font(.system(size: 10))
                            .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.80) : Color(red: 0.40, green: 0.45, blue: 0.55))
                    }
                }
                .toggleStyle(.checkbox)
            }

            // Theme for HTML export & preview
            HStack {
                Text("Theme:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.85) : Color(red: 0.35, green: 0.40, blue: 0.50))

                Picker("", selection: $config.theme) {
                    ForEach(ExportTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Section Header Helper
    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(primaryAccent)
                .frame(width: 4, height: 4)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isDark ? Color(red: 0.80, green: 0.86, blue: 0.98) : Color(red: 0.15, green: 0.22, blue: 0.35))
        }
    }

    // MARK: - Custom High-Contrast Segmented Picker Helper
    private func customSegmentedPicker<T: Hashable>(
        options: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { item in
                let isSelected = selection.wrappedValue == item
                Button(action: { selection.wrappedValue = item }) {
                    Text(label(item))
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? (isDark ? .white : Color(red: 0.05, green: 0.08, blue: 0.15)) : (isDark ? Color(red: 0.70, green: 0.75, blue: 0.85) : Color(red: 0.35, green: 0.40, blue: 0.50)))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected ? (isDark ? Color(red: 0.20, green: 0.25, blue: 0.36) : Color.white) : Color.clear)
                                .shadow(color: isSelected ? Color.black.opacity(isDark ? 0.3 : 0.08) : Color.clear, radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isDark ? Color(red: 0.12, green: 0.14, blue: 0.20) : Color(red: 0.88, green: 0.90, blue: 0.93))
        )
    }

    // MARK: - Preview Column
    private var previewColumn: some View {
        let isLightPreview = config.theme == .light || (config.theme == .system && !isDark)
        let deskBackground = isLightPreview ? Color(red: 0.88, green: 0.90, blue: 0.94) : Color(red: 0.04, green: 0.06, blue: 0.09)

        return VStack(spacing: 0) {
            // Preview Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                        .foregroundColor(primaryAccent)
                    Text("LIVE DOCUMENT PREVIEW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isDark ? Color.white.opacity(0.85) : Color(red: 0.20, green: 0.25, blue: 0.35))
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("\(config.fontFamily.rawValue) • \(config.fontSize.shortTitle)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))

                    Text(config.format.shortTitle)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(primaryAccent.opacity(0.18))
                        .foregroundColor(primaryAccent)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isDark ? Color(red: 0.08, green: 0.10, blue: 0.14) : Color(red: 0.94, green: 0.95, blue: 0.98))

            Divider()
                .background(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))

            // Document Canvas Scroll
            ScrollView {
                VStack(spacing: 0) {
                    documentCanvas
                        .padding(.vertical, 28)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
            }
            .background(deskBackground)
        }
    }

    // MARK: - Document Canvas (WYSIWYG Simulation)
    private var documentCanvas: some View {
        let isLightPreview = config.theme == .light || (config.theme == .system && !isDark)
        let paperBg = isLightPreview ? Color.white : Color(red: 0.08, green: 0.11, blue: 0.17)
        let textColor = isLightPreview ? Color(red: 0.08, green: 0.10, blue: 0.14) : Color(red: 0.95, green: 0.97, blue: 1.0)
        let headingColor = isLightPreview ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color.white
        let metaColor = isLightPreview ? Color(red: 0.30, green: 0.36, blue: 0.46) : Color(red: 0.75, green: 0.82, blue: 0.92)
        let borderColor = isLightPreview ? Color(red: 0.78, green: 0.82, blue: 0.88) : Color(red: 0.22, green: 0.28, blue: 0.40)
        let codeBg = isLightPreview ? Color(red: 0.95, green: 0.96, blue: 0.98) : Color(red: 0.12, green: 0.16, blue: 0.24)

        return VStack(alignment: .leading, spacing: 14) {
            // Document Frame Card
            VStack(alignment: .leading, spacing: 14) {
                // 1. Metadata Header Banner
                if config.includeMetadata {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.title)
                            .font(.system(size: config.fontSize.titleSize, weight: .bold, design: config.fontFamily.fontDesign))
                            .foregroundColor(headingColor)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Text("📁 \(note.folder)")
                            Text("•")
                            Text("🕒 \(DateFormatter.localizedString(from: note.timestamp, dateStyle: .medium, timeStyle: .short))")
                            Text("•")
                            Text("📝 \(note.content.split(whereSeparator: \.isWhitespace).count) words")
                        }
                        .font(.system(size: config.fontSize.subtitleSize, weight: .semibold, design: config.fontFamily.fontDesign))
                        .foregroundColor(metaColor)

                        if config.borderStyle == .borderedCard || config.borderStyle == .headerDivider {
                            Rectangle()
                                .fill(borderColor)
                                .frame(height: 1.5)
                                .padding(.top, 4)
                        }
                    }
                }

                // 2. Body Content with Selected Font & Indent
                VStack(alignment: .leading, spacing: config.indentStyle == .indentedParagraphs ? 6 : 10) {
                    let lines = note.content.components(separatedBy: "\n")
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("# ") {
                            Text(String(trimmed.dropFirst(2)))
                                .font(.system(size: config.fontSize.h1Size, weight: .bold, design: config.fontFamily.fontDesign))
                                .foregroundColor(headingColor)
                                .padding(.top, 4)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if trimmed.hasPrefix("## ") {
                            Text(String(trimmed.dropFirst(3)))
                                .font(.system(size: config.fontSize.h2Size, weight: .bold, design: config.fontFamily.fontDesign))
                                .foregroundColor(headingColor)
                                .padding(.top, 2)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if trimmed.hasPrefix("### ") {
                            Text(String(trimmed.dropFirst(4)))
                                .font(.system(size: config.fontSize.bodySize + 1, weight: .semibold, design: config.fontFamily.fontDesign))
                                .foregroundColor(headingColor)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if trimmed.hasPrefix("> ") {
                            HStack(alignment: .top, spacing: 8) {
                                Rectangle()
                                    .fill(primaryAccent)
                                    .frame(width: 3.5)
                                Text(String(trimmed.dropFirst(2)))
                                    .font(.system(size: config.fontSize.bodySize, weight: .regular, design: config.fontFamily.fontDesign))
                                    .italic()
                                    .foregroundColor(metaColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 8)
                        } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .font(.system(size: config.fontSize.bodySize, weight: .bold))
                                    .foregroundColor(primaryAccent)
                                Text(String(trimmed.dropFirst(2)))
                                    .font(.system(size: config.fontSize.bodySize, weight: .regular, design: config.fontFamily.fontDesign))
                                    .foregroundColor(textColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 12)
                        } else if trimmed.hasPrefix("```") {
                            Text(trimmed)
                                .font(.system(size: config.fontSize.bodySize - 1, design: .monospaced))
                                .foregroundColor(metaColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(codeBg)
                                .cornerRadius(4)
                        } else if !trimmed.isEmpty {
                            Text(trimmed)
                                .font(.system(size: config.fontSize.bodySize, weight: .regular, design: config.fontFamily.fontDesign))
                                .foregroundColor(textColor)
                                .padding(.leading, config.indentStyle == .indentedParagraphs ? config.indentStyle.firstLineIndent : 0)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // 3. Diarized Audio Transcript Section
                if config.includeTranscript && !note.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle()
                            .fill(borderColor)
                            .frame(height: 1.5)
                            .padding(.vertical, 6)

                        Text("Diarized Audio Transcript")
                            .font(.system(size: config.fontSize.h2Size, weight: .bold, design: config.fontFamily.fontDesign))
                            .foregroundColor(headingColor)

                        ForEach(note.transcript) { seg in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(seg.speaker)
                                        .font(.system(size: config.fontSize.subtitleSize + 1, weight: .bold))
                                        .foregroundColor(primaryAccent)
                                    Text("[\(formatTime(seg.startTime))]")
                                        .font(.system(size: config.fontSize.subtitleSize, weight: .medium, design: .monospaced))
                                        .foregroundColor(metaColor)
                                }
                                Text(seg.text)
                                    .font(.system(size: config.fontSize.bodySize, weight: .regular, design: config.fontFamily.fontDesign))
                                    .foregroundColor(textColor)
                                    .padding(.leading, 8)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .padding(config.marginSize.points)
            .background(paperBg)
            .cornerRadius(config.borderStyle == .borderedCard ? 12 : 4)
            .overlay(
                Group {
                    if config.borderStyle == .borderedCard {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 1.5)
                    } else if config.borderStyle == .headerDivider {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(borderColor.opacity(0.4), lineWidth: 1)
                    }
                }
            )
            .shadow(color: Color.black.opacity(isLightPreview ? 0.12 : 0.45), radius: 12, x: 0, y: 6)
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack(spacing: 12) {
            // Quick Copy to Clipboard Button
            Button(action: copyToClipboard) {
                HStack(spacing: 6) {
                    Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text(copiedToClipboard ? "Copied!" : "Copy Formatted Text")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(isDark ? .white : Color(red: 0.10, green: 0.12, blue: 0.18))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(isDark ? Color(red: 0.15, green: 0.18, blue: 0.25) : Color(red: 0.88, green: 0.91, blue: 0.95))
                )
            }
            .buttonStyle(.plain)
            .help("Copy content in selected format to system clipboard")

            Spacer()

            Button("Cancel") {
                isOpen = false
            }
            .buttonStyle(.plain)
            .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.85) : Color(red: 0.35, green: 0.40, blue: 0.50))
            .keyboardShortcut(.cancelAction)

            Button(action: executeExport) {
                HStack(spacing: 6) {
                    Image(systemName: config.format.icon)
                        .font(.system(size: 12, weight: .bold))
                    Text("Export as \(config.format.shortTitle)...")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(primaryAccent)
                .cornerRadius(AppRadius.sm)
                .shadow(color: primaryAccent.opacity(0.35), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isDark ? Color(red: 0.08, green: 0.10, blue: 0.14) : Color(red: 0.96, green: 0.97, blue: 0.99))
    }

    // MARK: - Actions
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch config.format {
        case .markdown:
            let text = NoteExporter.shared.generateMarkdownString(note, config: config)
            pasteboard.setString(text, forType: .string)
        case .html:
            let html = NoteExporter.shared.generateHTMLString(note, config: config)
            pasteboard.setString(html, forType: .html)
            pasteboard.setString(html, forType: .string)
        case .plainText:
            let text = NoteExporter.shared.generatePlainTextString(note, config: config)
            pasteboard.setString(text, forType: .string)
        case .pdf:
            let text = NoteExporter.shared.generatePlainTextString(note, config: config)
            pasteboard.setString(text, forType: .string)
        case .srt, .vtt:
            let text = NoteExporter.shared.generatePlainTextString(note, config: config)
            pasteboard.setString(text, forType: .string)
        }

        withAnimation { copiedToClipboard = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { copiedToClipboard = false }
        }
    }

    private func executeExport() {
        isOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NoteExporter.shared.exportNote(note, config: config)
        }
    }
}
