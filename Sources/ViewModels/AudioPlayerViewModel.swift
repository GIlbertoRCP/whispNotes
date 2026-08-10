import Foundation
import AVFoundation

// MARK: - Audio Player ViewModel
@MainActor
class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var playbackSpeed: Double = 1.0
    @Published var activeSegmentIndex: Int = -1
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var transcriptSegments: [TranscriptSegment] = []

    func loadAudio(url: URL, transcript: [TranscriptSegment]) {
        self.transcriptSegments = transcript
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0.0
            currentTime = 0.0
            isPlaying = false
            playbackSpeed = 1.0
            activeSegmentIndex = -1
        } catch {
            print("Failed to load audio file: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
            timer = nil
        } else {
            player.enableRate = true
            player.rate = Float(playbackSpeed)
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(to time: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = time
        currentTime = time
        updateActiveSegment(time)
    }

    func setSpeed(_ speed: Double) {
        playbackSpeed = speed
        guard let player = audioPlayer else { return }
        player.rate = Float(speed)
    }

    func rewind5Seconds() {
        guard let player = audioPlayer else { return }
        let target = max(0, player.currentTime - 5.0)
        seek(to: target)
    }

    func forward5Seconds() {
        guard let player = audioPlayer else { return }
        let target = min(duration, player.currentTime + 5.0)
        seek(to: target)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                self.updateActiveSegment(player.currentTime)
                if !player.isPlaying {
                    self.isPlaying = false
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }

    private func updateActiveSegment(_ time: Double) {
        let index = transcriptSegments.firstIndex { time >= $0.startTime && time <= $0.endTime } ?? -1
        if index != activeSegmentIndex {
            activeSegmentIndex = index
        }
    }
}
