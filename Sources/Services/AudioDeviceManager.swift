import Foundation
import AVFoundation
import Combine

// MARK: - Audio Device Manager
class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var inputDevices: [String] = ["Default System Microphone"]
    @Published var outputDevices: [String] = ["Default System Speaker"]
    
    private var cancellables = Set<AnyCancellable>()
    private var hasRefreshed = false

    init() {
        // NOTE: Do NOT call refreshDevices() here.
        // AVCaptureDevice.DiscoverySession triggers macOS TCC at init time,
        // which causes SIGABRT when running via `swift run` outside an app bundle.
        setupDeviceChangeListener()
    }
    
    private func setupDeviceChangeListener() {
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange)
            .sink { [weak self] _ in
                self?.refreshDevices()
            }
            .store(in: &cancellables)
    }

    func refreshDevices() {
        // macOS TCC will SIGABRT bare CLI executables that call AVCaptureDevice APIs
        guard AppBundleDetector.canUseTCCProtectedAPIs else {
            return
        }
        
        // Guard: only query AVCaptureDevice if microphone access is already authorized
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .authorized else {
            return
        }
        
        hasRefreshed = true
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        let inputs = discoverySession.devices.map { $0.localizedName }
        DispatchQueue.main.async {
            self.inputDevices = ["Default System Microphone"] + inputs
            self.outputDevices = [
                "Default System Speaker",
                "Built-in Speakers (Display)",
                "External Headphones"
            ]
        }
    }
}
