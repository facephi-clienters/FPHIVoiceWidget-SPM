import AVFoundation
import Foundation
import VoiceSdk

@objc(FPHIVoiceCaptureBridgeListener)
public protocol FPHIVoiceCaptureBridgeListener: NSObjectProtocol {
    @objc(onAmplitude:)
    func onAmplitude(_ amplitude: Float)

    @objc(onResult:)
    func onResult(_ result: FPHIVoiceCaptureBridgeResult)
}

@objc(FPHIVoiceCaptureBridgeConfig)
@objcMembers public final class FPHIVoiceCaptureBridgeConfig: NSObject {
    public var enableQualityCheck: Bool
    public var minSpeechLengthMs: Float

    public override convenience init() {
        self.init(enableQualityCheck: true, minSpeechLengthMs: 700)
    }

    @objc(initWithEnableQualityCheck:minSpeechLengthMs:)
    public init(enableQualityCheck: Bool, minSpeechLengthMs: Float) {
        self.enableQualityCheck = enableQualityCheck
        self.minSpeechLengthMs = minSpeechLengthMs
        super.init()
    }
}

@objc(FPHIVoiceCaptureBridgeResult)
@objcMembers public final class FPHIVoiceCaptureBridgeResult: NSObject {
    public let statusCode: Int32
    public let message: String
    public let audioData: Data?
    public let recoverable: Bool

    @objc(initWithStatusCode:message:audioData:recoverable:)
    public init(statusCode: Int32, message: String, audioData: Data?, recoverable: Bool) {
        self.statusCode = statusCode
        self.message = message
        self.audioData = audioData
        self.recoverable = recoverable
        super.init()
    }
}

@objc(FPHIVoiceCaptureBridge)
@objcMembers public final class FPHIVoiceCaptureBridge: NSObject {
    private enum StatusCode {
        static let success: Int32 = 0
        static let qualityFailure: Int32 = 1
        static let fatalError: Int32 = 2
    }

    private let queue = DispatchQueue(label: "com.facephi.voice.capture.bridge")
    private let recorder = FPHIVoiceAudioRecorder()
    private let engineStore = FPHIVoiceEngineStore()

    private weak var listener: FPHIVoiceCaptureBridgeListener?
    private var speechSummaryStream: SpeechSummaryStream?
    private var currentConfig = FPHIVoiceCaptureBridgeConfig()
    private var recordedPcm = Data()
    private var lastSpeechInfo: SpeechInfo?
    private var visualProgress = FPHIVoiceVisualProgress()
    private var isRecording = false
    private var debugBufferCount = 0
    private var debugLastSpeechDetected: Bool?

    private let maxSilenceLengthMs: Float = 300
    private let silenceDurationForResetMs: Float = 1_000
    private let minimumSpeechRelativeLength: Float = 0.55

    @objc(setLicenseAndCheckWithVoiceLicense:)
    public func setLicenseAndCheck(voiceLicense: String) -> Bool {
        debugLog("bridge.setLicenseAndCheck input isEmpty=\(voiceLicense.isEmpty)")
        guard !voiceLicense.isEmpty else { return false }

        do {
            try MobileLicense.setLicense(voiceLicense)
        } catch {
            debugLog("bridge.setLicenseAndCheck failed error=\(error.localizedDescription)")
            return false
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let expirationDate = formatter.date(from: BuildInfo().licenseExpirationDate) else {
            return false
        }

        let isValid = Date().compare(expirationDate) == .orderedAscending
        debugLog("bridge.setLicenseAndCheck expiration=\(BuildInfo().licenseExpirationDate) isValid=\(isValid)")
        return isValid
    }

    @objc(recordOnceWithConfig:listener:)
    public func recordOnce(config: FPHIVoiceCaptureBridgeConfig, listener: FPHIVoiceCaptureBridgeListener) {
        queue.async { [weak self] in
            guard let self else { return }

            self.stopLocked(clearEngines: false)
            self.listener = listener
            self.currentConfig = config
            self.recordedPcm = Data()
            self.lastSpeechInfo = nil
            self.visualProgress.reset()
            self.debugBufferCount = 0
            self.debugLastSpeechDetected = nil
            debugLog(
                "bridge.recordOnce start enableQualityCheck=\(config.enableQualityCheck) " +
                    "minSpeechLengthMs=\(config.minSpeechLengthMs)"
            )

            do {
                let sampleRate = try self.recorder.prepare()
                debugLog("bridge.recordOnce prepared sampleRate=\(sampleRate)")
                self.speechSummaryStream = try self.engineStore.makeSpeechSummaryStream(sampleRate: sampleRate)
                try self.speechSummaryStream?.reset()
                self.isRecording = true
                try self.recorder.start(
                    onData: { [weak self] data in
                        self?.queue.async {
                            self?.processBuffer(data)
                        }
                    },
                    onError: { [weak self] message in
                        self?.queue.async {
                            self?.finishFatal(message: message)
                        }
                    }
                )
            } catch {
                debugLog("bridge.recordOnce fatal error=\(error.localizedDescription)")
                self.finishFatal(message: error.localizedDescription)
            }
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.stopLocked(clearEngines: true)
        }
    }

    private func processBuffer(_ buffer: Data) {
        guard isRecording, let speechSummaryStream else { return }

        debugBufferCount += 1
        let firstBuffer = recordedPcm.isEmpty
        recordedPcm.append(buffer)

        do {
            if !firstBuffer {
                try speechSummaryStream.addSamples(buffer)
            }

            lastSpeechInfo = try speechSummaryStream.getTotalSpeechInfo()
            let speechLengthMs = lastSpeechInfo?.speechLengthMs ?? 0
            let backgroundLengthMs = try speechSummaryStream.getCurrentBackgroundLength().floatValue
            let speechDetected = speechLengthMs > 0

            if backgroundLengthMs > silenceDurationForResetMs {
                debugLog(
                    "bridge.processBuffer silenceReset buffer=\(debugBufferCount) " +
                        "bytes=\(buffer.count) speechMs=\(speechLengthMs) backgroundMs=\(backgroundLengthMs)"
                )
                try speechSummaryStream.reset()
                lastSpeechInfo = nil
                recordedPcm = Data()
                visualProgress.reset()
                emitAmplitude(from: buffer, speechDetected: false)
                return
            }

            if debugBufferCount == 1 ||
                debugBufferCount % 10 == 0 ||
                debugLastSpeechDetected != speechDetected {
                debugLog(
                    "bridge.processBuffer buffer=\(debugBufferCount) first=\(firstBuffer) " +
                        "bytes=\(buffer.count) recordedBytes=\(recordedPcm.count) " +
                        "speechMs=\(speechLengthMs) backgroundMs=\(backgroundLengthMs) " +
                        "speechDetected=\(speechDetected)"
                )
            }
            debugLastSpeechDetected = speechDetected

            emitAmplitude(from: buffer, speechDetected: speechDetected)

            if speechLengthMs > currentConfig.minSpeechLengthMs,
               backgroundLengthMs > maxSilenceLengthMs {
                finishCandidate()
            }
        } catch {
            finishFatal(message: error.localizedDescription)
        }
    }

    private func finishCandidate() {
        guard isRecording else { return }

        let pcm = recordedPcm
        let sampleRate = recorder.sampleRate
        recorder.stop()
        isRecording = false

        let wavData = FPHIVoiceWAVFormat.wavFromPCM(data: pcm, sampleRate: Int(sampleRate))
        let quality = checkQuality(audioData: wavData, sampleRate: Int(sampleRate))
        debugLog(
            "bridge.finishCandidate pcmBytes=\(pcm.count) wavBytes=\(wavData.count) " +
                "sampleRate=\(sampleRate) quality=\(quality.rawValue)"
        )

        if isAccepted(quality: quality) {
            finish(
                FPHIVoiceCaptureBridgeResult(
                    statusCode: StatusCode.success,
                    message: "OK",
                    audioData: wavData,
                    recoverable: false
                )
            )
        } else {
            finish(
                FPHIVoiceCaptureBridgeResult(
                    statusCode: StatusCode.qualityFailure,
                    message: quality.rawValue,
                    audioData: nil,
                    recoverable: true
                )
            )
        }
    }

    private func finishFatal(message: String) {
        guard isRecording || listener != nil else { return }

        debugLog("bridge.finishFatal message=\(message)")
        stopLocked(clearEngines: true)
        finish(
            FPHIVoiceCaptureBridgeResult(
                statusCode: StatusCode.fatalError,
                message: message,
                audioData: nil,
                recoverable: false
            )
        )
    }

    private func finish(_ result: FPHIVoiceCaptureBridgeResult) {
        let currentListener = listener
        listener = nil
        debugLog(
            "bridge.finish status=\(result.statusCode) message=\(result.message) " +
                "hasAudio=\(result.audioData != nil) recoverable=\(result.recoverable)"
        )
        DispatchQueue.main.async {
            currentListener?.onResult(result)
        }
    }

    private func stopLocked(clearEngines: Bool) {
        isRecording = false
        recorder.stop()
        recordedPcm = Data()
        lastSpeechInfo = nil
        visualProgress.reset()
        debugBufferCount = 0
        debugLastSpeechDetected = nil
        try? speechSummaryStream?.reset()
        speechSummaryStream = nil
        listener = nil
        if clearEngines {
            engineStore.deinitializeAll()
        }
    }

    private func emitAmplitude(from buffer: Data, speechDetected: Bool) {
        let rawAmplitude = FPHIVoiceAmplitudeNormalizer.normalizedAmplitude(from: buffer)
        let amplitude = visualProgress.next(
            rawAmplitude: rawAmplitude,
            speechDetected: speechDetected
        )
        let currentListener = listener
        if debugBufferCount == 1 ||
            debugBufferCount % 10 == 0 ||
            speechDetected ||
            amplitude > 0 {
            debugLog(
                "bridge.emitAmplitude buffer=\(debugBufferCount) raw=\(rawAmplitude) " +
                    "visual=\(amplitude) speechDetected=\(speechDetected) listener=\(currentListener != nil)"
            )
        }
        DispatchQueue.main.async {
            currentListener?.onAmplitude(amplitude)
        }
    }

    private func checkQuality(audioData: Data, sampleRate: Int) -> FPHIVoiceCaptureQuality {
        do {
            let qualityEngine = try engineStore.getQualityCheckEngine()
            let thresholds = try qualityEngine.getRecommendedThresholds(.QUALITY_CHECK_SCENARIO_VERIFY_TD_ENROLLMENT)
            thresholds.minimumSpeechRelativeLength = minimumSpeechRelativeLength

            let result = try qualityEngine.checkQuality(
                audioData,
                sampleRate: sampleRate,
                thresholds: thresholds
            )

            switch result.qualityCheckShortDescription {
            case .QUALITY_SHORT_DESCRIPTION_OK:
                return .ok
            case .QUALITY_SHORT_DESCRIPTION_TOO_NOISY:
                return .tooNoisy
            case .QUALITY_SHORT_DESCRIPTION_TOO_SMALL_SPEECH_TOTAL_LENGTH:
                return .tooSmallSpeechTotalLength
            case .QUALITY_SHORT_DESCRIPTION_TOO_SMALL_SPEECH_RELATIVE_LENGTH:
                return .tooSmallSpeechRelativeLength
            case .QUALITY_SHORT_DESCRIPTION_MULTIPLE_SPEAKERS_DETECTED:
                return .multipleSpeakers
            default:
                return .qualityCheckInternalError
            }
        } catch {
            return .qualityCheckInternalError
        }
    }

    private func isAccepted(quality: FPHIVoiceCaptureQuality) -> Bool {
        if quality == .ok {
            return true
        }

        if !currentConfig.enableQualityCheck {
            return quality == .tooNoisy || quality == .multipleSpeakers
        }

        return false
    }
}

private enum FPHIVoiceCaptureQuality: String {
    case ok
    case tooNoisy
    case tooSmallSpeechTotalLength
    case tooSmallSpeechRelativeLength
    case multipleSpeakers
    case qualityCheckInternalError
}

private final class FPHIVoiceEngineStore {
    private var speechSummaryEngine: SpeechSummaryEngine?
    private var qualityCheckEngine: QualityCheckEngine?

    func makeSpeechSummaryStream(sampleRate: Double) throws -> SpeechSummaryStream {
        return try getSpeechSummaryEngine().createStream(Int32(sampleRate))
    }

    func getQualityCheckEngine() throws -> QualityCheckEngine {
        if let qualityCheckEngine {
            return qualityCheckEngine
        }

        let path = try Self.voiceSDKResourcesPath().appending("/media/quality_check_with_msd/")
        let engine = try QualityCheckEngine(path: path)
        qualityCheckEngine = engine
        return engine
    }

    func deinitializeAll() {
        speechSummaryEngine = nil
        qualityCheckEngine = nil
    }

    private func getSpeechSummaryEngine() throws -> SpeechSummaryEngine {
        if let speechSummaryEngine {
            return speechSummaryEngine
        }

        let path = try Self.voiceSDKResourcesPath().appending("/media/speech_summary/")
        let engine = try SpeechSummaryEngine(path: path)
        speechSummaryEngine = engine
        return engine
    }

    private static func voiceSDKResourcesPath() throws -> String {
        let fileManager = FileManager.default
        let candidateBundles = resourceCandidateBundles()

        for bundle in candidateBundles {
            guard let resourcePath = bundle.resourcePath else { continue }

            let candidate = resourcePath.appending("/VoiceSDKResources")
            if fileManager.fileExists(atPath: candidate.appending("/media/speech_summary")) {
                return candidate
            }

            let nestedBundlePath = resourcePath.appending("/FPHIVoiceSdkBridgeResources.bundle")
            if let nestedBundle = Bundle(path: nestedBundlePath),
               let nestedResourcePath = nestedBundle.resourcePath {
                let nestedCandidate = nestedResourcePath.appending("/VoiceSDKResources")
                if fileManager.fileExists(atPath: nestedCandidate.appending("/media/speech_summary")) {
                    return nestedCandidate
                }
            }
        }

        throw NSError(
            domain: "FPHIVoiceSdkBridge",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "VoiceSDKResources not found"]
        )
    }

    private static func resourceCandidateBundles() -> [Bundle] {
        var bundles: [Bundle] = []

        #if SWIFT_PACKAGE
        bundles.append(Bundle.module)
        #endif

        bundles.append(Bundle(for: FPHIVoiceCaptureBridge.self))
        bundles.append(Bundle.main)
        bundles.append(contentsOf: Bundle.allBundles)
        return Array(NSOrderedSet(array: bundles)) as? [Bundle] ?? bundles
    }
}

private final class FPHIVoiceAudioRecorder {
    private var audioSession: AVAudioSession?
    private let audioEngine = AVAudioEngine()
    private let dispatcher = DispatchQueue(label: "com.facephi.voice.capture.recorder")

    private var onData: ((Data) -> Void)?
    private var onError: ((String) -> Void)?
    private var debugTapCount = 0

    private(set) var sampleRate: Double = 0

    func prepare() throws -> Double {
        audioSession = AVAudioSession.sharedInstance()
        try audioSession?.setCategory(.playAndRecord, mode: .default)
        try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)

        audioEngine.reset()
        sampleRate = audioEngine.inputNode.inputFormat(forBus: 0).sampleRate
        let inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        debugLog(
            "recorder.prepare sampleRate=\(sampleRate) inputChannels=\(inputFormat.channelCount) " +
                "inputFormat=\(inputFormat)"
        )
        return sampleRate
    }

    func start(onData: @escaping (Data) -> Void, onError: @escaping (String) -> Void) throws {
        self.onData = onData
        self.onError = onError
        debugTapCount = 0

        let currentInputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        debugLog(
            "recorder.start currentSampleRate=\(currentInputFormat.sampleRate) " +
                "channels=\(currentInputFormat.channelCount)"
        )
        guard currentInputFormat.channelCount > 0 else {
            throw NSError(
                domain: "FPHIVoiceSdkBridge",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Microphone input is not available"]
            )
        }

        guard sampleRate == currentInputFormat.sampleRate else {
            throw NSError(
                domain: "FPHIVoiceSdkBridge",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Sample rate changed before recording"]
            )
        }

        let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )

        guard let inputFormat else {
            throw NSError(
                domain: "FPHIVoiceSdkBridge",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create PCM16 audio format"]
            )
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4_096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard let channel = buffer.int16ChannelData?[0] else {
                self.dispatcher.async {
                    self.onError?("PCM16 channel data is not available")
                }
                return
            }

            let bytesPerFrame = Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
            let byteCount = Int(buffer.frameLength) * bytesPerFrame
            let data = Data(bytes: channel, count: byteCount)
            self.debugTapCount += 1
            if self.debugTapCount == 1 || self.debugTapCount % 10 == 0 {
                debugLog(
                    "recorder.tap count=\(self.debugTapCount) frameLength=\(buffer.frameLength) " +
                        "frameCapacity=\(buffer.frameCapacity) bytesPerFrame=\(bytesPerFrame) " +
                        "byteCount=\(byteCount)"
                )
            }
            self.dispatcher.async {
                self.onData?(data)
            }
        }

        do {
            try audioEngine.start()
            debugLog("recorder.start audioEngineStarted=\(audioEngine.isRunning)")
        } catch {
            throw NSError(
                domain: "FPHIVoiceSdkBridge",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
    }

    func stop() {
        debugLog("recorder.stop isRunning=\(audioEngine.isRunning)")
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        onData = nil
        onError = nil
    }

    deinit {
        stop()
    }
}

private func debugLog(_ message: String) {
    let text = "[FPHIVoiceDebug] \(message)"
    NSLog("%@", text)
    print(text)
}

private enum FPHIVoiceAmplitudeNormalizer {
    private static let noiseFloor: Float = 0.006
    private static let speechReference: Float = 0.08

    static func normalizedAmplitude(from data: Data) -> Float {
        guard data.count >= MemoryLayout<Int16>.size else { return 0 }

        let sampleCount = data.count / MemoryLayout<Int16>.size
        var squaredSum: Double = 0

        data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for sample in samples {
                let value = Double(sample)
                squaredSum += value * value
            }
        }

        guard sampleCount > 0 else { return 0 }

        let rms = sqrt(squaredSum / Double(sampleCount))
        let normalized = Float(rms / Double(Int16.max))

        if normalized <= noiseFloor {
            return 0
        }

        let scaled = (normalized - noiseFloor) / (speechReference - noiseFloor)
        return min(1, max(0, sqrt(scaled)))
    }
}

private enum FPHIVoiceWAVFormat {
    static func wavFromPCM(data: Data, sampleRate: Int) -> Data {
        var result = createWaveHeader(data: data, sampleRate: sampleRate)
        result.append(data)
        return result
    }

    private static func createWaveHeader(data: Data, sampleRate: Int) -> Data {
        let chunkSize = Int32(36 + data.count)
        let subChunkSize: Int32 = 16
        let format: Int16 = 1
        let channels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = Int32(sampleRate) * Int32(channels * bitsPerSample / 8)
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = Int32(data.count)

        var header = Data()
        header.append(contentsOf: [UInt8]("RIFF".utf8))
        header.append(contentsOf: intToByteArray(chunkSize))
        header.append(contentsOf: [UInt8]("WAVE".utf8))
        header.append(contentsOf: [UInt8]("fmt ".utf8))
        header.append(contentsOf: intToByteArray(subChunkSize))
        header.append(contentsOf: shortToByteArray(format))
        header.append(contentsOf: shortToByteArray(channels))
        header.append(contentsOf: intToByteArray(Int32(sampleRate)))
        header.append(contentsOf: intToByteArray(byteRate))
        header.append(contentsOf: shortToByteArray(blockAlign))
        header.append(contentsOf: shortToByteArray(bitsPerSample))
        header.append(contentsOf: [UInt8]("data".utf8))
        header.append(contentsOf: intToByteArray(dataSize))
        return header
    }

    private static func intToByteArray(_ value: Int32) -> [UInt8] {
        return [
            UInt8(truncatingIfNeeded: value & 0xff),
            UInt8(truncatingIfNeeded: (value >> 8) & 0xff),
            UInt8(truncatingIfNeeded: (value >> 16) & 0xff),
            UInt8(truncatingIfNeeded: (value >> 24) & 0xff),
        ]
    }

    private static func shortToByteArray(_ value: Int16) -> [UInt8] {
        return [
            UInt8(truncatingIfNeeded: value & 0xff),
            UInt8(truncatingIfNeeded: (value >> 8) & 0xff),
        ]
    }
}
