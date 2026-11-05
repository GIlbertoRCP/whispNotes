import SwiftUI
import AppKit

public enum QuickRecordPreferenceKey {
    public static let showInMenuBar = "quickRecordShowInMenuBar"
    public static let globalShortcut = "quickRecordGlobalShortcut"
}

// MARK: - Menu bar icon
/// A waveform when idle; a record dot and the elapsed time while recording, so it's visible during a call.
struct QuickRecordMenuBarLabel: View {
    @ObservedObject var recorder: AudioRecorderViewModel

    var body: some View {
        if recorder.isRecording {
            HStack(spacing: 4) {
                Image(systemName: "record.circle.fill")
                Text(formatTime(recorder.recordingTime))
                    .monospacedDigit()
            }
            .accessibilityLabel("WhispNotes recording, \(formatTime(recorder.recordingTime))")
        } else if recorder.isTranscribing {
            Image(systemName: "waveform.badge.ellipsis")
                .accessibilityLabel("WhispNotes transcribing")
        } else {
            Image(systemName: "waveform")
                .accessibilityLabel("WhispNotes")
        }
    }
}

// MARK: - Menu bar menu
struct QuickRecordMenu: View {
    @ObservedObject var recorder: AudioRecorderViewModel
    let currentNote: NoteItem?
    let recordingNoteTitle: String?
    let onRecordIntoCurrent: () -> Void
    let onRecordIntoNew: () -> Void
    let onStop: () -> Void

    @Environment(\.openWindow) private var openWindow

    private var canRecordIntoCurrent: Bool {
        guard let note = currentNote else { return false }
        return note.isStandalone && note.folder != "Trash" && !recorder.transcribingNoteIds.contains(note.id)
    }

    var body: some View {
        if recorder.isRecording {
            Text("Recording \(formatTime(recorder.recordingTime))\(recordingNoteTitle.map { " · \($0)" } ?? "")")
            Button("Stop and Transcribe", action: onStop)
        } else {
            Button("Record Into New Note", action: onRecordIntoNew)
            if canRecordIntoCurrent, let note = currentNote {
                Button("Record Into “\(GraphLayoutModel.displayTitle(note.title))”", action: onRecordIntoCurrent)
            }
        }

        if recorder.isTranscribing {
            Text(recorder.transcribingNoteIds.count == 1 ? "Transcribing 1 recording…" : "Transcribing \(recorder.transcribingNoteIds.count) recordings…")
        }

        if GlobalHotKey.shared.isRegistered {
            Text("Start or stop from anywhere with \(GlobalHotKey.displayString)")
        }

        Divider()

        Button("Open WhispNotes") { showMainWindow() }
        Button("Quit WhispNotes") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
