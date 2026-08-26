import SwiftUI

// MARK: - Live Waveform Metering Visualizer
struct WaveformVisualizerView: View {
    let level: Float
    let primaryColor: Color
    let barCount: Int = 8
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                let factor = sin(Double(i) * 0.8 + Date().timeIntervalSince1970 * 6)
                let height = max(4.0, CGFloat(level * 24.0) * (0.3 + 0.7 * abs(CGFloat(factor))))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(primaryColor)
                    .frame(width: 3, height: height)
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Interactive Real PCM Audio Waveform Seeker View
struct InteractiveWaveformView: View {
    let currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let primaryAccent: Color
    let audioURL: URL?
    var onSeek: (Double) -> Void
    
    let barCount: Int = 44
    @State private var samplePeaks: [CGFloat] = []

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let progress = duration > 0 ? min(1.0, max(0.0, currentTime / duration)) : 0.0
            let peaksToDisplay = samplePeaks.isEmpty ? generateDefaultPeaks(count: barCount) : samplePeaks

            ZStack(alignment: .leading) {
                // Waveform Bars
                HStack(spacing: 2) {
                    ForEach(0..<min(barCount, peaksToDisplay.count), id: \.self) { i in
                        let barProgress = Double(i) / Double(barCount)
                        let isPlayed = barProgress <= progress
                        let peakValue = peaksToDisplay[i]
                        let barHeight = max(4.0, height * peakValue)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isPlayed ? primaryAccent : primaryAccent.opacity(0.25))
                            .frame(height: barHeight)
                    }
                }
                .frame(width: width, height: height, alignment: .center)
                
                // Playhead Indicator
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 1.5, height: height)
                    .offset(x: width * CGFloat(progress))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = min(1.0, max(0.0, value.location.x / width))
                        let targetTime = duration * Double(ratio)
                        onSeek(targetTime)
                    }
            )
        }
        .frame(height: 26)
        .onAppear {
            loadPeaks()
        }
        .onChange(of: audioURL) { _, _ in
            loadPeaks()
        }
    }

    private func loadPeaks() {
        guard let url = audioURL else { return }
        AudioWaveformExtractor.shared.extractPeaks(from: url, targetSampleCount: barCount) { peaks in
            self.samplePeaks = peaks
        }
    }

    private func generateDefaultPeaks(count: Int) -> [CGFloat] {
        (0..<count).map { i in
            let factor = sin(Double(i) * 0.4) * cos(Double(i) * 0.7)
            return CGFloat(max(0.15, min(1.0, 0.35 + 0.65 * abs(factor))))
        }
    }
}

// MARK: - Audio Player Bottom Bar View
struct AudioPlayerBarView: View {
    @Binding var note: NoteItem
    @Binding var notes: [NoteItem]
    @ObservedObject var playerVM: AudioPlayerViewModel
    let audioPath: String
    let isDark: Bool
    let primaryAccent: Color

    @State private var newBookmarkTitle = ""
    @State private var showBookmarkPopover = false

    var resolvedAudioURL: URL? {
        NotesDataManager.shared.resolveAttachmentURL(audioPath)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left Controls
            HStack(spacing: 10) {
                Button(action: { playerVM.rewind5Seconds() }) {
                    Image(systemName: "gobackward.5")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rewind 5 Seconds")
                .accessibilityHint("Jumps playback back by 5 seconds")
                
                Button(action: { playerVM.togglePlayPause() }) {
                    Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(primaryAccent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playerVM.isPlaying ? "Pause Audio" : "Play Audio")
                .accessibilityHint("Toggles audio playback")

                Button(action: { playerVM.forward5Seconds() }) {
                    Image(systemName: "goforward.5")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fast Forward 5 Seconds")
                .accessibilityHint("Jumps playback forward by 5 seconds")
            }
            
            // Middle Interactive Waveform Track & Bookmark Markers
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    if playerVM.isPlaying {
                        WaveformVisualizerView(level: 0.8, primaryColor: primaryAccent)
                    }

                    // Add Timeline Flag Bookmark Button
                    Button(action: { showBookmarkPopover.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                                .foregroundColor(primaryAccent)
                            Text("+ Flag")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(primaryAccent)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryAccent.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showBookmarkPopover) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add Timeline Flag Marker")
                                .font(.caption)
                                .fontWeight(.bold)
                            TextField("Bookmark label (e.g. Exam Topic)...", text: $newBookmarkTitle, onCommit: {
                                addBookmark()
                            })
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            
                            Button("Add Flag") { addBookmark() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    Text("\(formatTime(playerVM.currentTime)) / \(formatTime(playerVM.duration))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                // Interactive Waveform Track & Bookmark Markers Overlay
                ZStack(alignment: .leading) {
                    InteractiveWaveformView(
                        currentTime: playerVM.currentTime,
                        duration: playerVM.duration,
                        isPlaying: playerVM.isPlaying,
                        primaryAccent: primaryAccent,
                        audioURL: resolvedAudioURL,
                        onSeek: { target in
                            playerVM.seek(to: target)
                        }
                    )

                    // Flags
                    GeometryReader { geo in
                        ForEach(note.bookmarks) { bm in
                            let ratio = playerVM.duration > 0 ? bm.time / playerVM.duration : 0.0
                            let xPos = geo.size.width * CGFloat(min(1.0, max(0.0, ratio)))
                            
                            Button(action: { playerVM.seek(to: bm.time) }) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(primaryAccent)
                            }
                            .buttonStyle(.plain)
                            .position(x: xPos, y: geo.size.height / 2)
                            .help("\(bm.label) (\(formatTime(bm.time)))")
                        }
                    }
                }
                .frame(height: 26)
            }
            .frame(maxWidth: .infinity)
            
            // Right Speed buttons
            HStack(spacing: 4) {
                ForEach([1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    Button(action: { playerVM.setSpeed(speed) }) {
                        Text("\(speed, specifier: "%.2g")x")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(playerVM.playbackSpeed == speed ? primaryAccent.opacity(0.18) : Color.cardBackground(isDark))
                            .foregroundColor(playerVM.playbackSpeed == speed ? primaryAccent : .secondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 76)
        .background(Color.panelBackground(isDark))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.subtleBorder(isDark)),
            alignment: .top
        )
        .onAppear {
            if let url = resolvedAudioURL {
                playerVM.loadAudio(url: url, transcript: note.transcript)
            }
        }
        .onChange(of: audioPath) { _, newPath in
            if let url = NotesDataManager.shared.resolveAttachmentURL(newPath) {
                playerVM.loadAudio(url: url, transcript: note.transcript)
            }
        }
    }

    private func addBookmark() {
        let clean = newBookmarkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = clean.isEmpty ? "Key Moment" : clean
        let bm = AudioBookmark(time: playerVM.currentTime, label: label)
        note.bookmarks.append(bm)
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
            NotesDataManager.shared.saveNotesImmediately(notes)
        }
        showBookmarkPopover = false
        newBookmarkTitle = ""
    }
}
