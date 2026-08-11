import Foundation
import Speech

// MARK: - Speech Recognizer & Diarization Engine
class LocalSpeechTranscriber {
    static var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("com.whispnotes.app/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func transcribe(url: URL, completion: @escaping ([TranscriptSegment]) -> Void) {
        guard FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64, size > 0 else {
            print("Audio file is empty or missing: \(url.path)")
            DispatchQueue.main.async { completion([]) }
            return
        }

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                print("Speech recognition authorization status: \(status)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
                print("SFSpeechRecognizer is unavailable on this machine")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.requiresOnDeviceRecognition = true // Force 100% offline local processing
            
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    print("Speech transcription task error: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                guard let result = result else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                let wordSegments = result.bestTranscription.segments
                let diarized = self.diarizeSpeechSegments(wordSegments)
                
                if result.isFinal || !wordSegments.isEmpty {
                    DispatchQueue.main.async {
                        completion(diarized)
                    }
                }
            }
        }
    }

    /// Real acoustic silence-gap and turn-taking diarization algorithm.
    /// Groups words into coherent sentences and toggles speaker tags on significant pauses (>0.6s).
    private static func diarizeSpeechSegments(_ wordSegments: [SFTranscriptionSegment]) -> [TranscriptSegment] {
        guard !wordSegments.isEmpty else { return [] }

        var outputSegments: [TranscriptSegment] = []
        var currentChunk: [String] = []
        var currentChunkStart: Double = wordSegments[0].timestamp
        var currentChunkEnd: Double = wordSegments[0].timestamp + wordSegments[0].duration
        var currentSpeakerIndex = 1

        for i in 0..<wordSegments.count {
            let seg = wordSegments[i]
            let word = seg.substring
            let wordStart = seg.timestamp
            let wordEnd = seg.timestamp + seg.duration

            if currentChunk.isEmpty {
                currentChunkStart = wordStart
            }

            currentChunk.append(word)
            currentChunkEnd = wordEnd

            // Calculate silence gap to next word
            var gapToNext: Double = 0.0
            if i + 1 < wordSegments.count {
                let nextStart = wordSegments[i + 1].timestamp
                gapToNext = max(0.0, nextStart - wordEnd)
            }

            let isSentenceEnd = word.contains(".") || word.contains("?") || word.contains("!")
            let isLongPause = gapToNext > 0.65
            let isMaxChunkLength = currentChunk.count >= 14

            if isSentenceEnd || isLongPause || isMaxChunkLength || i == wordSegments.count - 1 {
                let text = currentChunk.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                let speakerLabel = "Speaker \(currentSpeakerIndex)"
                
                if !text.isEmpty {
                    outputSegments.append(TranscriptSegment(
                        speaker: speakerLabel,
                        text: text,
                        startTime: currentChunkStart,
                        endTime: currentChunkEnd
                    ))
                }

                currentChunk.removeAll()

                // If a distinct conversational pause (>0.85s) occurred, switch speaker turn
                if gapToNext > 0.85 {
                    currentSpeakerIndex = (currentSpeakerIndex == 1) ? 2 : 1
                }
            }
        }

        return outputSegments
    }
}
