import XCTest
@testable import FPHIVoiceSdkBridgeSupport

final class FPHIVoiceVisualProgressTests: XCTestCase {
    func testSilenceReturnsZeroAndResetsTheSpeechPulse() {
        var progress = FPHIVoiceVisualProgress()

        _ = progress.next(rawAmplitude: 0.01, speechDetected: true)
        let silence = progress.next(rawAmplitude: 0.6, speechDetected: false)
        let nextSpeech = progress.next(rawAmplitude: 0.01, speechDetected: true)

        XCTAssertEqual(silence, 0)
        XCTAssertEqual(nextSpeech, 0.28, accuracy: 0.001)
    }

    func testSpeechGeneratesVisibleProgressWhenRawAmplitudeIsFlat() {
        var progress = FPHIVoiceVisualProgress()

        let values = (0..<4).map { _ in
            progress.next(rawAmplitude: 0.01, speechDetected: true)
        }

        XCTAssertTrue(values.allSatisfy { $0 >= 0.25 })
        XCTAssertGreaterThan(Set(values).count, 1)
    }

    func testSpeechKeepsHigherRawAmplitude() {
        var progress = FPHIVoiceVisualProgress()

        let value = progress.next(rawAmplitude: 0.82, speechDetected: true)

        XCTAssertEqual(value, 0.82, accuracy: 0.001)
    }
}
