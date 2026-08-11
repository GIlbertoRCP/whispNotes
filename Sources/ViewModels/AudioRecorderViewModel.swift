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
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized {
            self.performStartRecording()
        } else if status == .notDetermined {
            guard Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil else {
                print("Warning: NSMicrophoneUsageDescription missing from main bundle. Attempting direct recording.")
                self.performStartRecording()
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if granted {
                        self.performStartRecording()
                    } else {
                        print("Microphone access was denied by user.")
                    }
                }
            }
        } else {
            self.performStartRecording()
        }
    }

    private func performStartRecording() {
        let dir = NotesDataManager.shared.attachmentsDir
        let filename = "rec_\(Int(Date().timeIntervalSince1970)).wav"
        let fileURL = dir.appendingPathComponent(filename)
        self.currentAudioURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            let recorded = audioRecorder?.record() ?? false
            if !recorded {
                print("AVAudioRecorder.record() returned false")
            }
            isRecording = true
            recordingTime = 0.0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
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
        if let recorder = audioRecorder {
            if recorder.isRecording {
                recorder.stop()
            }
        }
        audioRecorder = nil
        isRecording = false
        return currentAudioURL
    }
}
