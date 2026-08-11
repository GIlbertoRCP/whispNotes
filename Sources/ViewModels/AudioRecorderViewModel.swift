import Foundation
import AVFoundation

// MARK: - Audio Recorder ViewModel
@MainActor
class AudioRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingTime: Double = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    var currentAudioURL: URL?

    func startRecording() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !granted {
                    print("Microphone access was denied by user.")
                    return
                }
                self.performStartRecording()
            }
        }
    }

    private func performStartRecording() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "rec_\(Int(Date().timeIntervalSince1970)).wav"
        let fileURL = docs.appendingPathComponent(filename)
        self.currentAudioURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            recordingTime = 0.0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let recorder = self.audioRecorder else { return }
                    recorder.updateMeters()
                    let power = recorder.averagePower(forChannel: 0)
                    let normalized = max(0, (power + 50) / 50)
                    self.audioLevel = normalized
                    self.recordingTime += 0.1
                }
            }
        } catch {
            print("Failed to start native audio recording: \(error)")
        }
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false
        return currentAudioURL
    }
}
