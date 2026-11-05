import Foundation
import AVFoundation

// MARK: - Audio Recorder ViewModel
@MainActor
class AudioRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingTime: Double = 0.0
    /// The note this recording belongs to, fixed when it starts, so switching notes mid-meeting can't misfile it.
    @Published private(set) var recordingNoteId: UUID?
    /// Notes whose recording is being transcribed right now.
    @Published private(set) var transcribingNoteIds: Set<UUID> = []

    /// Called when a recording has been saved and transcribed: note id, segments, audio file name in the vault.
    /// Set once by the app so every entry point (toolbar, menu bar, global shortcut) files recordings the same way.
    var onRecordingFinished: ((_ noteId: UUID, _ segments: [TranscriptSegment], _ audioFileName: String) -> Void)?

    var isTranscribing: Bool { !transcribingNoteIds.isEmpty }

    /// Starts recording into `noteId`. Does nothing if a recording is already running.
    func startRecording(for noteId: UUID) {
        guard !isRecording else { return }
        recordingNoteId = noteId
        startRecording()
    }

    /// Stops, then transcribes on device and hands the result to `onRecordingFinished`.
    func finishRecording() {
        guard isRecording else { return }
        let noteId = recordingNoteId
        let url = stopRecording()
        recordingNoteId = nil
        guard let noteId, let url else { return }
        transcribingNoteIds.insert(noteId)
        // The file is already in the vault's Attachments folder; store it by name rather than copying it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            LocalSpeechTranscriber.transcribe(url: url) { segments in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.transcribingNoteIds.remove(noteId)
                    self.onRecordingFinished?(noteId, segments, url.lastPathComponent)
                }
            }
        }
    }

    func toggleRecording(for noteId: UUID) {
        if isRecording { finishRecording() } else { startRecording(for: noteId) }
    }
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    var currentAudioURL: URL?

    func startRecording() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized || !AppBundleDetector.canUseTCCProtectedAPIs {
            self.performStartRecording()
        } else if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.performStartRecording()
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
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            
            guard let recorder = audioRecorder, recorder.prepareToRecord() else {
                print("AVAudioRecorder failed prepareToRecord()")
                recordingNoteId = nil
                return
            }
            
            guard recorder.record() else {
                print("AVAudioRecorder failed record()")
                recordingNoteId = nil
                return
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
            recordingNoteId = nil
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
