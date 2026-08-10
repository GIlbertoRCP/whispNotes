import Foundation
import AVFoundation
import Combine

// MARK: - Audio Device Manager
class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var inputDevices: [String] = ["Default System Microphone"]
    @Published var outputDevices: [String] = ["Default System Speaker"]
    
    func refreshDevices() {
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
