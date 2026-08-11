# Contributing to WhispNotes

Thank you for your interest in contributing to **WhispNotes**! We welcome bug reports, feature requests, documentation improvements, and code contributions from the community.

---

## 🛠️ Development Setup & Architecture Guidelines

1. **Requirements**:
   - macOS 14.0 (Sonoma) or higher
   - Swift 5.9+ / Xcode 15.4+

2. **Building the Project**:
   ```bash
   swift build
   ```

3. **Running the Unit Test Suite**:
   ```bash
   swift test
   ```

4. **Building the Release Bundle & DMG**:
   ```bash
   ./scripts/build_app.sh 1.1.0
   ```

---

## 📐 Code Style & Conventions

- **100% Local & Privacy-First**: WhispNotes runs offline with zero external web API servers or HTTP background ports. All AI inference and audio processing must remain local on-device.
- **SwiftUI & Native macOS**: Follow Apple Human Interface Guidelines for macOS. Use system colors (`Color.primary`, `NSColor.labelColor`) and standard macOS control behaviors.
- **Clean Architecture**:
  - `Sources/Models/`: Data structures (`NoteItem`, `TranscriptSegment`, `ThemeColors`).
  - `Sources/Services/`: Data persistence (`NotesDataManager`), Audio (`LocalSpeechTranscriber`), AI (`GemmaLocalEngine`), Exporter (`NoteExporter`).
  - `Sources/Views/`: Native SwiftUI view components (`SidebarView`, `EditorPanelView`, `TranscriptPanelView`, `GraphViewModal`).

---

## 🧪 Submitting Pull Requests

1. Fork the repository and create a feature branch (`git checkout -b feature/amazing-feature`).
2. Ensure `swift build` and `swift test` pass cleanly with zero warnings or errors.
3. Push your branch and open a Pull Request targeting `main`.
