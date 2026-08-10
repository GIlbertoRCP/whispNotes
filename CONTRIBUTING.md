# Contributing to WhispNotes

Thank you for your interest in contributing to **WhispNotes**! WhispNotes is a 100% local, privacy-first macOS Markdown note-taking app with integrated speech transcription and Gemma 3 AI capabilities.

---

## Technical Stack & Requirements

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (macOS 14.0 Sonoma or higher)
- **Package Manager**: Swift Package Manager (SPM)
- **Audio Frameworks**: CoreAudio, AVFoundation, Speech

---

## Development Environment Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/GIlbertoRCP/whispNotes.git
   cd whispNotes
   ```

2. **Build the Debug Binary**:
   ```bash
   swift build
   ```

3. **Run Unit Tests**:
   ```bash
   swift test
   ```

4. **Run the App Locally**:
   ```bash
   swift run
   ```

5. **Package macOS `.app` Bundle & `.dmg` Installer**:
   ```bash
   ./scripts/build_app.sh 1.0.0
   ```

---

## Code Architecture

- `Sources/App/`: Main application lifecycle, window management, and menu commands.
- `Sources/Models/`: Data structures for Notes, Transcripts, Themes, Models, and Graph Canvas nodes.
- `Sources/Services/`: Data persistence (`NotesDataManager`), Audio device discovery, Speech transcription, and Gemma 3 local AI engine.
- `Sources/ViewModels/`: Audio recorder & player view models with reactive Combine publishers.
- `Sources/Views/`: Modular SwiftUI components (Sidebar, Editor, Audio Player Bar, Graph Canvas, Command Palette, AI Study Assistant, Settings).
- `Tests/swift-whispnotesTests/`: Automated unit test suite.

---

## Pull Request Guidelines

1. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Write Unit Tests**: Ensure new models, services, or parser utilities have corresponding unit tests in `Tests/swift-whispnotesTests/`.

3. **Verify Build & Tests**:
   ```bash
   swift test && swift build -c release
   ```

4. **Submit Pull Request**: Open a PR targeting the `main` branch with a clear summary of changes.
