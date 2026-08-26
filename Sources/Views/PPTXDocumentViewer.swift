import SwiftUI
import AppKit
import QuickLookUI

// MARK: - Native QuickLook Presentation NSViewRepresentable Wrapper
struct QLPreviewRepresentable: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> QLPreviewView {
        let preview = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        preview.autoresizingMask = [.width, .height]
        preview.previewItem = url as NSURL
        return preview
    }
    
    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if let currentItem = nsView.previewItem as? NSURL, currentItem as URL != url {
            nsView.previewItem = url as NSURL
        } else if nsView.previewItem == nil {
            nsView.previewItem = url as NSURL
        }
    }
}

// MARK: - Native PPTX Presentation Document Viewer View
struct PPTXDocumentViewerView: View {
    let pptxURL: URL
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var onDetachPPTX: (() -> Void)? = nil
    var onQuoteSelection: ((String) -> Void)? = nil

    @State private var presentation: PPTXPresentation? = nil
    @State private var currentSlideIndex: Int = 1
    @State private var totalSlides: Int = 1
    @State private var showJumpPopover: Bool = false
    @State private var jumpTargetSlide: Double = 1.0
    @State private var showOutlineDrawer: Bool = false
    @State private var showQuoteNotification: Bool = false
    @State private var quoteToastText: String = "Slide Cited in Note"
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var matchingSlideIds: Set<Int> = []
    
    var currentSlide: PPTXSlide? {
        guard let pres = presentation, currentSlideIndex >= 1 && currentSlideIndex <= pres.slides.count else { return nil }
        return pres.slides[currentSlideIndex - 1]
    }

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 600
            
            VStack(spacing: 0) {
                // Sleek Presentation Toolbar
                pptxToolbar(isCompact: isCompact)
                
                Divider()
                    .background(Color.subtleBorder(isDark))
                
                // Optional Search Bar Strip
                if isSearching {
                    searchBarStrip
                    Divider()
                        .background(Color.subtleBorder(isDark))
                }
                
                // Main Content Canvas (Side-by-side with Outline Drawer if open)
                HStack(spacing: 0) {
                    // Presentation Visual Rendering Canvas
                    ZStack(alignment: .topTrailing) {
                        QLPreviewRepresentable(url: pptxURL)
                            .id(pptxURL)
                            .background(Color.black.opacity(isDark ? 0.35 : 0.05))
                        
                        // Floating Citation Toast
                        if showQuoteNotification {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(quoteToastText)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.panelBackground(isDark))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                            .padding(16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Collapsible Slide Outline & Speaker Notes Drawer
                    if showOutlineDrawer {
                        Divider()
                            .background(Color.subtleBorder(isDark))
                        
                        slideOutlineDrawer
                            .frame(width: min(320, geo.size.width * 0.4))
                            .transition(.move(edge: .trailing))
                    }
                }
            }
        }
        .task(id: pptxURL) {
            loadPresentation()
        }
    }
    
    private func loadPresentation() {
        if let cached = PPTXDocumentCache.shared.cachedPresentation(for: pptxURL) {
            self.presentation = cached
            self.totalSlides = cached.slideCount
            return
        }
        
        Task {
            if let parsed = await PPTXEngine.shared.parsePresentationAsync(url: pptxURL) {
                await MainActor.run {
                    self.presentation = parsed
                    self.totalSlides = max(1, parsed.slideCount)
                }
            }
        }
    }
    
    // MARK: - Presentation Toolbar
    @ViewBuilder
    private func pptxToolbar(isCompact: Bool) -> some View {
        HStack(spacing: 6) {
            // Presentation File Badge & Slide Counter
            Button(action: {
                jumpTargetSlide = Double(currentSlideIndex)
                showJumpPopover = true
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles.tv")
                        .font(.system(size: 10))
                        .foregroundColor(primaryAccent)
                    
                    Text("\(currentSlideIndex) / \(totalSlides) Slides")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.cardBackground(isDark))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Jump to Slide")
            .popover(isPresented: $showJumpPopover) {
                VStack(spacing: 10) {
                    Text("Jump to Slide")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("1")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(value: $jumpTargetSlide, in: 1...Double(max(1, totalSlides)), step: 1)
                            .accentColor(primaryAccent)
                            .frame(width: 140)
                        Text("\(totalSlides)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Go to Slide \(Int(jumpTargetSlide))") {
                        currentSlideIndex = Int(jumpTargetSlide)
                        showJumpPopover = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(12)
            }
            
            // Previous & Next Slide Controls
            HStack(spacing: 1) {
                Button(action: {
                    if currentSlideIndex > 1 { currentSlideIndex -= 1 }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(currentSlideIndex <= 1)
                .help("Previous Slide")
                
                Button(action: {
                    if currentSlideIndex < totalSlides { currentSlideIndex += 1 }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(currentSlideIndex >= totalSlides)
                .help("Next Slide")
            }
            .background(Color.cardBackground(isDark))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 1)
            )

            // Presentation Title Badge (if available)
            if !isCompact, let pres = presentation, !pres.title.isEmpty {
                Text(pres.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 6)
            }

            Spacer()

            // In-Document Search Toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSearching.toggle()
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(isSearching ? primaryAccent : .secondary)
                    .frame(width: 24, height: 24)
                    .background(isSearching ? primaryAccent.opacity(0.15) : Color.clear)
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Search Slides (⌘F)")

            // Outline & Notes Drawer Toggle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showOutlineDrawer.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showOutlineDrawer ? "sidebar.right" : "list.bullet.rectangle")
                        .font(.system(size: 10))
                    if !isCompact {
                        Text("Slide Notes")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(showOutlineDrawer ? secondaryAccent.opacity(0.18) : Color.cardBackground(isDark))
                .foregroundColor(showOutlineDrawer ? secondaryAccent : .primary)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Toggle Slide Outline & Speaker Notes Drawer")

            // Citation Action: Quote Current Slide
            Button(action: quoteCurrentSlide) {
                HStack(spacing: 4) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 9, weight: .bold))
                    if !isCompact {
                        Text("Quote Slide")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(primaryAccent.opacity(0.12))
                .foregroundColor(primaryAccent)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(primaryAccent.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Quote Active Slide Excerpt into Note Content")

            // Insert Full Presentation Outline
            Button(action: insertFullOutline) {
                HStack(spacing: 4) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 9))
                    if !isCompact {
                        Text("Outline")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.cardBackground(isDark))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Insert Full Slide Outline into Note")

            // Detach Presentation Button
            if let detachAction = onDetachPPTX {
                Button(action: detachAction) {
                    Image(systemName: "eject")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Detach Presentation from Note")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.panelBackground(isDark))
    }
    
    // MARK: - Slide Search Bar Strip
    private var searchBarStrip: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            TextField("Search in slides & speaker notes...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.caption)
                .onChange(of: searchQuery) { _, newValue in
                    performSlideSearch(query: newValue)
                }
            
            if !matchingSlideIds.isEmpty {
                Text("\(matchingSlideIds.count) matching slides")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(primaryAccent)
            }
            
            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    matchingSlideIds.removeAll()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Button("Done") {
                isSearching = false
                searchQuery = ""
                matchingSlideIds.removeAll()
            }
            .font(.caption2)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.cardBackground(isDark))
    }
    
    private func performSlideSearch(query: String) {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty, let pres = presentation else {
            matchingSlideIds.removeAll()
            return
        }
        
        var matches = Set<Int>()
        for slide in pres.slides {
            if slide.fullText.lowercased().contains(clean) {
                matches.insert(slide.id)
            }
        }
        matchingSlideIds = matches
    }
    
    // MARK: - Slide Outline & Notes Drawer
    private var slideOutlineDrawer: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.caption2)
                        .foregroundColor(secondaryAccent)
                    Text("SLIDE OUTLINE & NOTES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(presentation?.slides.count ?? 0) Slides")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.sidebarBackground(isDark))
            
            Divider()
                .background(Color.subtleBorder(isDark))
            
            if let slides = presentation?.slides, !slides.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(slides) { slide in
                            let isSelected = slide.id == currentSlideIndex
                            let isMatching = matchingSlideIds.contains(slide.id)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("Slide \(slide.id)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(isSelected ? primaryAccent : Color.secondary.opacity(0.15))
                                        .foregroundColor(isSelected ? .white : .secondary)
                                        .cornerRadius(4)
                                    
                                    Text(slide.title)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(isSelected ? primaryAccent : (isDark ? .white : .black))
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Button(action: { quoteSlide(slide) }) {
                                        Image(systemName: "quote.opening")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Quote this slide")
                                }
                                
                                // Bullet summary
                                if !slide.bulletPoints.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(slide.bulletPoints.prefix(3), id: \.self) { bullet in
                                            Text("• \(bullet)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                                
                                // Speaker notes (if present)
                                if let notes = slide.speakerNotes, !notes.isEmpty {
                                    HStack(alignment: .top, spacing: 4) {
                                        Image(systemName: "bubble.left.fill")
                                            .font(.system(size: 8))
                                            .foregroundColor(secondaryAccent)
                                            .padding(.top, 2)
                                        Text(notes)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(secondaryAccent)
                                            .lineLimit(3)
                                    }
                                    .padding(4)
                                    .background(secondaryAccent.opacity(0.08))
                                    .cornerRadius(4)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? primaryAccent.opacity(0.08) : (isMatching ? Color.yellow.opacity(0.12) : Color.cardBackground(isDark)))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ? primaryAccent.opacity(0.4) : Color.subtleBorder(isDark), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                currentSlideIndex = slide.id
                            }
                        }
                    }
                    .padding(8)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Parsing slide outline...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.panelBackground(isDark))
    }
    
    // MARK: - Citation Actions
    private func quoteCurrentSlide() {
        guard let slide = currentSlide else { return }
        quoteSlide(slide)
    }
    
    private func quoteSlide(_ slide: PPTXSlide) {
        var citation = "\n> 📊 **Slide \(slide.id): \(slide.title)**\n"
        for bullet in slide.bulletPoints {
            citation += "> • \(bullet)\n"
        }
        if let notes = slide.speakerNotes, !notes.isEmpty {
            citation += "> \n> *Notes: \(notes)*\n"
        }
        citation += "\n"
        
        note.content += citation
        NotesDataManager.shared.saveNotes(notes)
        onQuoteSelection?(citation)
        
        withAnimation {
            quoteToastText = "Slide \(slide.id) Cited in Note"
            showQuoteNotification = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showQuoteNotification = false
            }
        }
    }
    
    private func insertFullOutline() {
        guard let pres = presentation, !pres.slides.isEmpty else { return }
        
        var outline = "\n## 📊 Presentation Outline: \(pres.title)\n\n"
        for slide in pres.slides {
            outline += "### Slide \(slide.id): \(slide.title)\n"
            for bullet in slide.bulletPoints {
                outline += "- \(bullet)\n"
            }
            if let notes = slide.speakerNotes, !notes.isEmpty {
                outline += "> 🎙️ *Presenter Notes: \(notes)*\n"
            }
            outline += "\n"
        }
        
        note.content += outline
        NotesDataManager.shared.saveNotes(notes)
        onQuoteSelection?(outline)
        
        withAnimation {
            quoteToastText = "Full Presentation Outline Inserted"
            showQuoteNotification = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showQuoteNotification = false
            }
        }
    }
}
