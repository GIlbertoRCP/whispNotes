# Project Specification: Native macOS SwiftUI WhispNotes

This document serves as the design specification and feature checklist for building the pure native macOS SwiftUI version of **WhispNotes** with offline, on-device Whisper transcription.

---

## App Vision & Philosophy
- **Note-Taking First**: A clean, offline markdown editor resembling Obsidian, optimized for students and general note-taking (lectures, classrooms, brainstorm sessions).
- **Offline & Local-Only**: 100% private. Stored entirely on the local drive with zero background HTTP servers, API ports, or online connections.
- **Diarized Audio Capture**: High-quality audio recording synced to transcription timelines for review.

---

## Core Layout & Interface

### 1. Three-Pane Split View
- **Left Panel (File Library Sidebar)**: Collapsible outline structure grouping notes by folder using accordion style dropdowns. Notes with audio display a waveform icon, while standalone notes show a page/pencil icon.
- **Middle Panel (Editor & Render)**: Markdown shorthand editor with tabbed Edit/Preview modes.
- **Right Panel (Transcript Drawer)**: Time-synced transcript panel with speaker separation badges ("Speaker 1", "Speaker 2"). Highlights active segments and scrolls them into view during playback.
- **Draggable Dividers**: Real-time resizable panels where custom widths are persisted to local settings.

### 2. Audio Player Footer
- Scrubber slider tracking current time vs. duration.
- Play, Pause, `-5s` (Rewind), and `+5s` (Forward) jump controls.
- Playback speed selectors (`1.0x`, `1.25x`, `1.5x`, `2.0x`).

---

## Core Features Spec

### 1. Local On-Device Whisper Transcription
- **Engine**: Compile `whisper.cpp` (or import via `swift-whisper` package dependency) to run Whisper locally on macOS.
- **Capabilities**: Local transcription of WAV audio files. Segmented output containing:
  - `speaker` tag (e.g. Speaker 1, Speaker 2)
  - `text` transcription
  - `startTime` and `endTime` offsets (seconds)
- **Model Storage**: Downloads or bundles Whisper models (e.g., `base` or `tiny` `.bin` files) saved locally to the Application Support folder.

### 2. Spotlight Command Palette (`⌘K`)
- Triggered by `⌘K` or `⌘O` displaying a floating search sheet.
- Fuzzy searches note titles, folders, and transcript contents.
- Supports keyboard navigation (Arrow keys to navigate, `Enter` to open, `Esc` to close).

### 3. Wiki-Links (`[[Note Title]]`)
- Double-bracket links parse dynamically into clickable navigation pills in Preview mode.
- Clicking a link navigates to the target note.
- Linking to a non-existent note creates a new note draft in the current folder.

### 4. Transcript Quote Selection
- Clicking **"Quote"** on any transcript segment formats it as an Obsidian blockquote with a timestamp shortcut (`> "quote" [01:23](play://83)`) and inserts it directly at the active cursor position in the editor.

---

## Technical Constraints & Shortcuts
- **Storage Path**: JSON serialized file in `~/Library/Application Support/com.whispnotes.app/notes.json`.
- **Keyboard Shortcuts**:
  - `⌘N`: Create new standalone note.
  - `⌘K` / `⌘O`: Toggle Spotlight Command Palette.
  - `Space`: Toggle play/pause when audio is loaded.
