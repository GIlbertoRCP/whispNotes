# Changelog

All notable changes to **WhispNotes** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semanticsver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-08-10

### Added
- **Native 3-Pane Interface**: File library sidebar with folder accordions, markdown editor with Edit/Preview tabs, and time-synced transcript panel.
- **On-Device Whisper Transcription**: Offline audio transcription engine with speaker separation badges ("Speaker 1", "Speaker 2").
- **On-Device Gemma 3 AI Assistant**: Study assistant drawer for key takeaways, action item detection, interactive study flashcards, and custom Q&A.
- **Interactive Knowledge Graph Canvas**: Visual node graph of note connections with draggable node physics, blueprint grid, search filtering, and zoom/pan controls.
- **Interactive Audio Waveform Seeker**: Drag or click along multi-bar waveform visualizer to seek playback instantly, with live playhead indicator and transcript auto-scrolling.
- **Spotlight Command Palette (`⌘K` / `⌘O`)**: Quick search sheet with fuzzy matching across note titles, folder names, and transcript contents.
- **Wiki-Links (`[[Note Title]]`)**: Double-bracket note linking with interactive navigation pills and target note auto-creation.
- **Transcript Blockquotes**: Insert timestamped transcript excerpts directly into notes (`> "quote" [01:23](play://83)`).
- **Dynamic Theme Engine**: Theme switcher supporting Default Dark, Cyberpunk Neon, Obsidian Dark, Solarized Dark, and Minimalist Light themes with accent colors.
- **Trash Bin Retention**: Soft-delete system with 30-day retention, restore functionality, and single-click empty trash bin.
- **Automated Packaging**: Release build script (`./scripts/build_app.sh`) generating standalone macOS `.app` bundle and compressed `.dmg` installer.
