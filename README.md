# WhispNotes

WhispNotes is a native macOS application for markdown note-taking with integrated on-device audio transcription and local Gemma 3 AI assistant capabilities. Designed for privacy and offline usage, all note data, speech processing, and AI generation remain 100% local to your machine.

---

## Quick Download & Direct Installation (No Terminal Required)

1. Download **`WhispNotes-1.0.0.dmg`** from the latest GitHub Release.
2. Double-click **`WhispNotes-1.0.0.dmg`** to open the installer.
3. Drag **`WhispNotes.app`** into your **`Applications`** folder.
4. Launch **WhispNotes** directly from Applications or Spotlight (`⌘Space`)!

> **Zero terminal setup required.** Models for offline transcription and Gemma 3 AI assistant features can be downloaded on-demand directly inside the app's **Settings** modal with a single click.

---

## Interface Preview

### Main 3-Pane Interface
![WhispNotes Main Interface](assets/main_interface.png)

### Spotlight Command Palette (⌘K)
![WhispNotes Command Palette](assets/command_palette.png)

---

## Key Features

- **Three-Pane Split View**: Navigate notes via the file sidebar, write in the markdown editor with live preview, and view time-synced transcripts in the right panel.
- **Interactive Knowledge Graph Canvas**: Visual node graph of note connections with draggable node physics, zoom/pan controls, blueprint grid background, and search filtering.
- **On-Device Whisper Transcription**: Process audio recordings locally using Whisper without sending data to external servers.
- **On-Device Gemma 3 AI Assistant**: Extract executive key takeaways, auto-detect action items, generate study flashcards, and prompt custom Q&A on your note context.
- **Interactive Audio Waveform Seeker**: Click or drag along the multi-bar audio waveform to seek playback instantly, with live playhead indicator and transcript auto-scrolling during playback.
- **Speaker Separation and Time Sync**: View transcripts organized by speaker segments, with active segment highlighting during audio playback.
- **Transcript Blockquotes**: Insert timestamped transcript excerpts directly into notes with a single click.
- **Wiki-Links**: Connect notes using `[[Note Title]]` syntax, enabling fast navigation and automatic note creation.
- **Command Palette**: Search notes, folders, and transcript content using the `⌘K` or `⌘O` shortcut.

---

## System Requirements

- macOS 14.0 (Sonoma) or higher
- Apple Silicon or Intel Mac

---

## Building from Source (For Developers)

To build and run the executable locally using Swift Package Manager:

```bash
swift run
```

### Packaging `.app` Bundle & DMG Installer

To compile, code-sign, and package the application into a standalone macOS `.app` bundle and compressed `.dmg` disk image:

```bash
./scripts/build_app.sh
```

This script generates:
- `build/WhispNotes.app` (signed macOS application bundle with custom app icon)
- `build/WhispNotes-1.0.0.dmg` (installer image with Applications drag-and-drop link)

---

## Local Storage Location

Application settings, models, and notes are stored locally as JSON in:

`~/Library/Application Support/com.whispnotes.app/`

---

## Project Architecture

- `Package.swift`: Swift Package Manager manifest specifying macOS target and compilation settings.
- `Sources/main.swift`: Main application entry point, SwiftUI views, audio processing logic, Gemma 3 engine, graph canvas, and state management.
- `scripts/build_app.sh`: Automated build script to package `.app` bundle and compressed `.dmg` installer.
- `Info.plist`: Application metadata, icons, and microphone/speech entitlements.
- `Assets.xcassets/`: Native macOS app icons in all standard resolutions.
- `assets/`: Interface screenshots and high-resolution icon assets.
