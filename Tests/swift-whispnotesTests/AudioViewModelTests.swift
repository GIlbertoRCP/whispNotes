import XCTest
import AVFoundation
@testable import WhispNotesLibrary

final class AudioViewModelTests: XCTestCase {
    
    @MainActor
    func testAudioPlayerViewModelInitialState() {
        let playerVM = AudioPlayerViewModel()
        XCTAssertFalse(playerVM.isPlaying)
        XCTAssertEqual(playerVM.playbackSpeed, 1.0)
        XCTAssertEqual(playerVM.currentTime, 0.0)
        XCTAssertEqual(playerVM.duration, 0.0)
        XCTAssertEqual(playerVM.activeSegmentIndex, -1)
    }

    @MainActor
    func testAudioPlayerViewModelPlaybackSpeed() {
        let playerVM = AudioPlayerViewModel()
        playerVM.setSpeed(1.5)
        XCTAssertEqual(playerVM.playbackSpeed, 1.5)
        
        playerVM.setSpeed(2.0)
        XCTAssertEqual(playerVM.playbackSpeed, 2.0)
    }
    
    @MainActor
    func testAudioPlayerViewModelActiveSegmentIndex() {
        let playerVM = AudioPlayerViewModel()
        let segments = [
            TranscriptSegment(speaker: "Speaker 1", text: "First segment", startTime: 0.0, endTime: 5.0),
            TranscriptSegment(speaker: "Speaker 2", text: "Second segment", startTime: 5.0, endTime: 10.0),
            TranscriptSegment(speaker: "Speaker 1", text: "Third segment", startTime: 10.0, endTime: 15.0)
        ]
        
        playerVM.loadAudio(url: URL(fileURLWithPath: "/tmp/dummy.mp3"), transcript: segments)
        
        playerVM.updateActiveSegment(2.5)
        XCTAssertEqual(playerVM.activeSegmentIndex, 0)
        
        playerVM.updateActiveSegment(7.0)
        XCTAssertEqual(playerVM.activeSegmentIndex, 1)
        
        playerVM.updateActiveSegment(12.0)
        XCTAssertEqual(playerVM.activeSegmentIndex, 2)
        
        playerVM.updateActiveSegment(20.0)
        XCTAssertEqual(playerVM.activeSegmentIndex, -1)
    }

    @MainActor
    func testAudioRecorderViewModelInitialState() {
        let recorderVM = AudioRecorderViewModel()
        XCTAssertFalse(recorderVM.isRecording)
        XCTAssertEqual(recorderVM.recordingTime, 0.0)
        XCTAssertNil(recorderVM.currentAudioURL)
    }
}
