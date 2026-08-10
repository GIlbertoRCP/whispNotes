import Foundation
import AVFoundation

// MARK: - Real PCM Audio Waveform Peak Extractor
class AudioWaveformExtractor {
    static let shared = AudioWaveformExtractor()
    private var cache: [URL: [CGFloat]] = [:]

    /// Extracts normalized peak values (0.05 to 1.0) across targetSampleCount bins from an audio file.
    func extractPeaks(from url: URL, targetSampleCount: Int = 44, completion: @escaping ([CGFloat]) -> Void) {
        if let cached = cache[url] {
            completion(cached)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let audioFile = try? AVAudioFile(forReading: url) else {
                let defaultPeaks = self.generateFallbackPeaks(count: targetSampleCount)
                DispatchQueue.main.async { completion(defaultPeaks) }
                return
            }

            let format = audioFile.processingFormat
            let frameCount = UInt32(audioFile.length)
            guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                let defaultPeaks = self.generateFallbackPeaks(count: targetSampleCount)
                DispatchQueue.main.async { completion(defaultPeaks) }
                return
            }

            do {
                try audioFile.read(into: buffer)
            } catch {
                let defaultPeaks = self.generateFallbackPeaks(count: targetSampleCount)
                DispatchQueue.main.async { completion(defaultPeaks) }
                return
            }

            guard let floatData = buffer.floatChannelData?[0] else {
                let defaultPeaks = self.generateFallbackPeaks(count: targetSampleCount)
                DispatchQueue.main.async { completion(defaultPeaks) }
                return
            }

            let totalSamples = Int(buffer.frameLength)
            let samplesPerBin = max(1, totalSamples / targetSampleCount)
            var peaks: [CGFloat] = []

            for i in 0..<targetSampleCount {
                let startSample = i * samplesPerBin
                let endSample = min(startSample + samplesPerBin, totalSamples)
                var maxSample: Float = 0.0

                for j in startSample..<endSample {
                    let val = abs(floatData[j])
                    if val > maxSample {
                        maxSample = val
                    }
                }

                // Normalize peak between 0.08 and 1.0 for aesthetic UI waveform bars
                let normalizedPeak = max(0.08, min(1.0, CGFloat(maxSample * 1.8)))
                peaks.append(normalizedPeak)
            }

            DispatchQueue.main.async {
                self.cache[url] = peaks
                completion(peaks)
            }
        }
    }

    private func generateFallbackPeaks(count: Int) -> [CGFloat] {
        (0..<count).map { i in
            let factor = sin(Double(i) * 0.4) * cos(Double(i) * 0.7)
            return CGFloat(max(0.1, min(1.0, 0.3 + 0.6 * abs(factor))))
        }
    }
}
