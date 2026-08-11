# Changelog

All notable changes to **WhispNotes** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semanticsver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-08-11

### Added
- **Data Safety & Rolling Snapshots**: Automatic versioned backup engine saving up to 10 rolling JSON snapshots (`Backups/notes_backup_YYYYMMDD_HHmmss.json`) on every save.
- **Crash & Corruption Recovery**: Automatic recovery logic that restores notes from the latest valid backup snapshot if `notes.json` fails to decode.
- **Real-Time Save State Indicator**: Status indicator pill (`Saved ✓` / `Saving...`) in top bar displaying live vault persistence status.
- **Full Vault Exporter**: Export entire vault to a folder of structured `.md` files organized by directory (`File -> Export Full Vault to Folder...`).
- **Unlinked Mentions & 1-Click Linking**: Obsidian-style unlinked mentions panel with a single-click `+ Link` button to convert plain text mentions into `[[Wiki Links]]`.
- **Daily Notes Shortcut (`⌘D`)**: Jump to or create today's daily journal (`Daily Notes/YYYY-MM-DD.md`) pre-populated with morning study intentions and notes header.
- **Graph Canvas Freeze Physics**: `Freeze` / `Resume` toggle button on the Knowledge Graph Canvas to stop force-directed physics iterations and save CPU usage.

### Improved
- **Knowledge Graph Node Dragging**: Fixed node drag position math in canvas space, added physics engine bypass for dragged nodes, and resolved gesture layer conflicts between canvas panning and node selection.
- **Typography & Line Length**: Constrained Markdown Preview line width to 720pt (~68 characters) for optimal reading ergonomics.
- **Transcript Panel Aesthetics**: Replaced heavy segment cards with clean desaturated speaker badges and a left accent bar for active playback segments.
- **Flat Audio Waveform Seeker**: Cleaned up audio seeker track with flat 2-tone PCM sampling and removed playhead glow shadow.
- **Raycast-Style Command Palette**: Styled search palette footer hints with crisp keyboard shortcut chips (`[↑↓]`, `[↵]`, `[esc]`).

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
