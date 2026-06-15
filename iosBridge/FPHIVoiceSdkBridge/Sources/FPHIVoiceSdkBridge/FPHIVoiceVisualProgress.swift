import Foundation

struct FPHIVoiceVisualProgress {
    private static let speechFrames: [Float] = [
        0.28,
        0.46,
        0.68,
        0.92,
        0.68,
        0.46
    ]

    private var nextSpeechFrameIndex = 0

    mutating func next(rawAmplitude: Float, speechDetected: Bool) -> Float {
        guard speechDetected else {
            reset()
            return 0
        }

        let frame = Self.speechFrames[nextSpeechFrameIndex]
        nextSpeechFrameIndex = (nextSpeechFrameIndex + 1) % Self.speechFrames.count
        return min(1, max(rawAmplitude, frame))
    }

    mutating func reset() {
        nextSpeechFrameIndex = 0
    }
}
