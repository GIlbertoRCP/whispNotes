import SwiftUI
import PDFKit
import AppKit

// MARK: - Dedicated PDF View Controller (Decoupled from SwiftUI state to avoid AttributeGraph cycles)
final class PDFViewController: ObservableObject {
    weak var pdfView: PDFView?
    var onPageChanged: ((Int, Int) -> Void)?
    var onSearchResultsUpdated: (([PDFSelection]) -> Void)?

    func setPDFView(_ view: PDFView) {
        self.pdfView = view
    }

    func zoomIn() {
        pdfView?.zoomIn(nil)
    }

    func zoomOut() {
        pdfView?.zoomOut(nil)
    }

    func resetZoomToFit() {
        pdfView?.autoScales = true
    }

    func fitToWidth() {
        guard let pdfView = pdfView, let page = pdfView.currentPage else { return }
        let bounds = page.bounds(for: pdfView.displayBox)
        let available = pdfView.bounds.width - 24
        if bounds.width > 0 && available > 0 {
            pdfView.autoScales = false
            pdfView.scaleFactor = max(0.2, min(3.5, available / bounds.width))
        } else {
            pdfView.autoScales = true
        }
    }

    func rotateClockwise() {
        if let current = pdfView?.currentPage {
            current.rotation = (current.rotation + 90) % 360
            pdfView?.layoutDocumentView()
        }
    }

    func goToPreviousPage() {
        pdfView?.goToPreviousPage(nil)
    }

    func goToNextPage() {
        pdfView?.goToNextPage(nil)
    }

    func jumpToPage(_ page: Int) {
        guard let pdfView = pdfView, let document = pdfView.document, page >= 1 && page <= document.pageCount else { return }
        if let target = document.page(at: page - 1) {
            pdfView.go(to: target)
        }
    }

    func setDisplayMode(_ mode: PDFDisplayMode) {
        pdfView?.displayMode = mode
    }

    func selectSearchResult(_ selection: PDFSelection) {
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.scrollSelectionToVisible(selection)
    }
}

// MARK: - PDFKit NSViewRepresentable Wrapper (Zero Cycle)
struct PDFKitRepresentable: NSViewRepresentable {
    let url: URL
    let controller: PDFViewController
    var onDocumentLoaded: ((PDFDocument) -> Void)? = nil

    class Coordinator: NSObject, PDFViewDelegate {
        var controller: PDFViewController
        var currentURL: URL? = nil
        var currentDocument: PDFDocument? = nil
        weak var pdfView: PDFView? = nil
        var searchResults: [PDFSelection] = []
        var lastSearchQuery: String = ""
        private var searchWorkItem: DispatchWorkItem?

        init(_ controller: PDFViewController) {
            self.controller = controller
        }

        func loadDocument(_ targetURL: URL, in pdfView: PDFView) {
            guard currentURL != targetURL else { return }
            currentURL = targetURL

            // 1. Instant O(1) in-memory cache lookup
            if let cached = PDFDocumentCache.shared.cachedDocument(for: targetURL) {
                pdfView.document = cached
                self.currentDocument = cached
                self.controller.onPageChanged?(1, cached.pageCount)
                return
            }

            // 2. Non-blocking background loader
            PDFDocumentCache.shared.loadDocumentAsync(for: targetURL) { [weak self, weak pdfView] doc in
                guard let self = self, let pdfView = pdfView, self.currentURL == targetURL, let doc = doc else { return }
                pdfView.document = doc
                self.currentDocument = doc
                self.controller.onPageChanged?(1, doc.pageCount)
            }
        }

        @objc func pageChanged(notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let index = document.index(for: currentPage)
            controller.onPageChanged?(index + 1, document.pageCount)
        }

        func performSearch(query: String) {
            let clean = query.trimmingCharacters(in: .whitespaces)
            guard clean != lastSearchQuery else { return }
            lastSearchQuery = clean
            searchWorkItem?.cancel()

            guard let document = currentDocument, !clean.isEmpty else {
                searchResults = []
                controller.onSearchResultsUpdated?([])
                return
            }

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                let selections = document.findString(clean, withOptions: .caseInsensitive)
                DispatchQueue.main.async {
                    self.searchResults = selections
                    self.controller.onSearchResultsUpdated?(selections)
                    if let first = selections.first {
                        self.controller.selectSearchResult(first)
                    }
                }
            }
            searchWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.delegate = context.coordinator
        
        context.coordinator.pdfView = pdfView
        controller.setPDFView(pdfView)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(notification:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        context.coordinator.loadDocument(url, in: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if context.coordinator.currentURL != url {
            context.coordinator.loadDocument(url, in: pdfView)
        }
    }
}

// MARK: - Native Refined PDF Document Viewer View
struct PDFDocumentViewerView: View {
    let pdfURL: URL
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    let isDark: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    var onDetachPDF: (() -> Void)? = nil
    var onQuoteSelection: ((String) -> Void)? = nil

    @StateObject private var controller = PDFViewController()
    @State private var currentPage = 1
    @State private var pageCount = 1
    @State private var displayMode: PDFDisplayMode = .singlePageContinuous
    @State private var searchQuery = ""
    @State private var searchResults: [PDFSelection] = []
    @State private var currentSearchIndex = 0
    @State private var isSearching = false
    @State private var showJumpPopover = false
    @State private var jumpTargetPage: Double = 1.0
    @State private var showQuoteNotification = false

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 560
            
            VStack(spacing: 0) {
                // Sleek Top Toolbar
                pdfToolbar(isCompact: isCompact)
                
                Divider()
                    .background(Color.subtleBorder(isDark))

                // Optional In-Document Search Strip
                if isSearching {
                    searchBarStrip
                    Divider()
                        .background(Color.subtleBorder(isDark))
                }

                // PDF Rendering Canvas
                ZStack(alignment: .topTrailing) {
                    PDFKitRepresentable(
                        url: pdfURL,
                        controller: controller
                    )
                    .id(pdfURL) // Clean instance swap when switching between notes
                    .background(Color.black.opacity(isDark ? 0.35 : 0.05))

                    // Floating Citation Toast
                    if showQuoteNotification {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Excerpt Cited in Note")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.panelBackground(isDark))
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                        .padding(16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .onAppear {
            setupControllerCallbacks()
        }
    }

    private func setupControllerCallbacks() {
        controller.onPageChanged = { page, total in
            DispatchQueue.main.async {
                self.currentPage = page
                self.pageCount = total
                self.jumpTargetPage = Double(page)
            }
        }
        controller.onSearchResultsUpdated = { results in
            DispatchQueue.main.async {
                self.searchResults = results
                self.currentSearchIndex = results.isEmpty ? 0 : 1
            }
        }
    }

    // MARK: - Sleek Single PDF Toolbar
    @ViewBuilder
    private func pdfToolbar(isCompact: Bool) -> some View {
        HStack(spacing: 6) {
            // Page Jumper & Counter Pill
            Button(action: {
                jumpTargetPage = Double(currentPage)
                showJumpPopover = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(currentPage) / \(pageCount)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(isDark ? .white : Color(red: 15/255, green: 23/255, blue: 42/255))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.cardBackground(isDark))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.subtleBorder(isDark), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Jump to Page")
            .popover(isPresented: $showJumpPopover) {
                VStack(spacing: 10) {
                    Text("Jump to Page")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("1")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(value: $jumpTargetPage, in: 1...Double(max(1, pageCount)), step: 1)
                            .accentColor(primaryAccent)
                            .frame(width: 140)
                        Text("\(pageCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Button("Go to Page \(Int(jumpTargetPage))") {
                            controller.jumpToPage(Int(jumpTargetPage))
                            showJumpPopover = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(12)
            }

            // Zoom Steppers
            HStack(spacing: 1) {
                Button(action: { controller.zoomOut() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Zoom Out")

                Button(action: { controller.resetZoomToFit() }) {
                    Text("Fit")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(height: 22)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                .help("Fit to Window")

                Button(action: { controller.zoomIn() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Zoom In")
            }
            .padding(.horizontal, 2)
            .background(Color.cardBackground(isDark))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.subtleBorder(isDark), lineWidth: 1)
            )

            // Fit to Width Button
            Button(action: { controller.fitToWidth() }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("Width")
                        .font(.system(size: 10, weight: .semibold))
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
            .help("Scale page width to fit reading container")

            Spacer()

            // Search Toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSearching.toggle()
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: isSearching ? .bold : .regular))
                    .foregroundColor(isSearching ? primaryAccent : .secondary)
                    .frame(width: 26, height: 26)
                    .background(isSearching ? primaryAccent.opacity(0.12) : Color.cardBackground(isDark))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Search in Document (⌘F)")

            // Rotate Button
            Button(action: { controller.rotateClockwise() }) {
                Image(systemName: "rotate.right")
                    .font(.system(size: 11))
                    .frame(width: 26, height: 26)
                    .background(Color.cardBackground(isDark))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Rotate Clockwise 90°")

            // Click to Cite Button
            Button(action: quoteSelectionInNote) {
                HStack(spacing: 4) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 10))
                    Text("Cite")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(primaryAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(primaryAccent.opacity(0.12))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Insert selected PDF text as blockquote citation into Note")

            // Open in Preview.app
            Button(action: { NSWorkspace.shared.open(pdfURL) }) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.cardBackground(isDark))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Open in Apple Preview.app")

            // Detach Button
            if let onDetach = onDetachPDF {
                Button(action: onDetach) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 24, height: 24)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Detach PDF from Note")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(height: 38)
        .background(Color.sidebarBackground(isDark))
    }

    // MARK: - Search Bar Strip
    private var searchBarStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(primaryAccent)
            
            TextField("Search in document...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onChange(of: searchQuery) { _, newQ in
                    controller.pdfView?.document?.findString(newQ, withOptions: .caseInsensitive)
                }
            
            if !searchResults.isEmpty {
                Text("\(currentSearchIndex) of \(searchResults.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(primaryAccent)
                
                Button(action: previousSearchResult) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .padding(4)
                }
                .buttonStyle(.plain)
                
                Button(action: nextSearchResult) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .padding(4)
                }
                .buttonStyle(.plain)
            } else if !searchQuery.isEmpty {
                Text("No matches")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                isSearching = false
                searchQuery = ""
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.panelBackground(isDark))
    }

    private func nextSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex % searchResults.count) + 1
        let sel = searchResults[currentSearchIndex - 1]
        controller.selectSearchResult(sel)
    }

    private func previousSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = currentSearchIndex <= 1 ? searchResults.count : currentSearchIndex - 1
        let sel = searchResults[currentSearchIndex - 1]
        controller.selectSearchResult(sel)
    }

    private func quoteSelectionInNote() {
        guard let pdfView = controller.pdfView, let selection = pdfView.currentSelection, let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return
        }
        let docName = pdfURL.lastPathComponent
        let citation = "\n\n> \"\(text)\"\n> — *\(docName), Page \(currentPage)*\n"
        note.content += citation
        NotesDataManager.shared.saveNotes(notes)
        onQuoteSelection?(citation)
        
        withAnimation {
            showQuoteNotification = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showQuoteNotification = false
            }
        }
    }
}
