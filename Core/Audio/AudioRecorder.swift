//
//  AudioRecorder.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 2.2: Implement Audio Recording with AVFoundation
//

import Foundation
import AVFoundation
import os

/// AudioRecorder manages high-quality audio recording using AVAudioEngine
///
/// This class captures audio from the system microphone using AVAudioEngine
/// (instead of AVAudioRecorder) to enable real-time buffer access needed for
/// amplitude detection in Story 2.3. Audio is recorded at 16kHz or higher
/// sample rate in PCM format, stored in memory, and converted to Data suitable
/// for Whisper API upload.
///
/// Key features:
/// - Memory-based recording (no file I/O)
/// - Thread-safe buffer accumulation
/// - Microphone permission handling
/// - Comprehensive error handling
/// - AVAudioSession management
@MainActor
class AudioRecorder {
    // MARK: - Properties

    /// The audio engine used for recording
    ///
    /// Replaced for every recording. A failed start leaves an engine that never
    /// recovers - verified on a Bluetooth microphone, where reset() and further
    /// start attempts on the same instance keep failing while a fresh instance
    /// succeeds - and a new engine also re-reads the current input device format
    /// instead of reusing a stale one.
    private var audioEngine = AVAudioEngine()

    /// Accumulated audio buffers during recording (nonisolated for audio callback thread access)
    private nonisolated(unsafe) var audioBuffers: [AVAudioPCMBuffer] = []

    /// Serial queue for thread-safe buffer accumulation
    private let bufferQueue = DispatchQueue(label: "com.speech-to-clip.audiorecorder.buffer")

    /// Recording format: 16kHz mono PCM (suitable for Whisper API)
    private var recordingFormat: AVAudioFormat?

    /// Audio converter for resampling from hardware format to recording format
    private nonisolated(unsafe) var audioConverter: AVAudioConverter?

    /// Format the current converter was built for (audio thread access)
    private nonisolated(unsafe) var converterSourceFormat: AVAudioFormat?

    /// Start attempts allowed while the input device is switching rate
    private static let engineStartAttempts = 4

    /// Pause between start attempts
    private static let engineStartRetryDelay: TimeInterval = 0.12

    /// kAudioUnitErr_FormatNotSupported, reported while the device is switching
    private static let formatNotSupported = -10868

    /// Capture restarts allowed within one recording
    private static let maximumCaptureRestarts = 3

    /// Restarts used by the current recording
    private var captureRestarts = 0

    /// Observer of the running engine's configuration changes
    private var configurationObserver: NSObjectProtocol?

    /// Whether recording is currently active
    private(set) var isRecording = false

    /// Audio analyzer for real-time amplitude detection
    private let audioAnalyzer = AudioAnalyzer()

    /// Optional reference to AppState for publishing amplitude
    /// Weak reference to avoid retain cycles
    private weak var appState: AppState?

    // MARK: - Initialization

    init(appState: AppState? = nil) {
        self.appState = appState
        print("🎙️ AudioRecorder initialized")
        setupAudioFormat()
    }

    deinit {
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if isRecording {
            // Stop recording without returning data (deinit can't be async)
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        print("🔌 AudioRecorder deinitialized")
    }

    // MARK: - Audio Format Setup

    /// Configure the recording format (16kHz mono PCM)
    private func setupAudioFormat() {
        // Use 16kHz sample rate for optimal speech transcription quality/size balance
        // Mono channel is sufficient for speech
        // PCM format is uncompressed and compatible with Whisper API
        let sampleRate: Double = 16000.0
        let channels: AVAudioChannelCount = 1

        recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )

        if recordingFormat != nil {
            print("✅ Recording format configured: \(sampleRate)Hz, \(channels) channel(s)")
        } else {
            print("⚠️ Failed to create recording format")
        }
    }

    // MARK: - Permission Handling

    /// Check microphone permission (macOS handles this via system preferences)
    /// - Returns: True if permission is likely granted (we can't check directly on macOS)
    /// - Note: On macOS, microphone permission is checked when first accessing the microphone.
    ///         The system will prompt the user automatically. If denied, AVAudioEngine will fail to start.
    func checkMicrophonePermission() async -> Bool {
        print("ℹ️ On macOS, microphone permission is handled by the system")
        print("ℹ️ User will be prompted when recording starts (if not already authorized)")
        // On macOS, we can't check permission status ahead of time
        // The system will prompt automatically when we try to access the microphone
        // Return true to proceed with recording attempt
        return true
    }

    // MARK: - Recording Control

    /// Start recording audio from the microphone
    /// - Throws: AudioRecorderError if recording cannot be started
    func startRecording() throws {
        guard !isRecording else {
            print("⚠️ Recording already in progress")
            return
        }

        guard recordingFormat != nil else {
            throw AudioRecorderError.invalidFormat
        }

        // Clear previous buffers
        bufferQueue.sync {
            audioBuffers.removeAll()
        }

        // Note: On macOS, we don't need to configure audio session like on iOS
        // The system handles microphone access and will prompt for permission if needed

        captureRestarts = 0

        try startCapture()

        isRecording = true
        print("🎤 Recording started")
        AppLog.dictation.info("Recording started")
    }

    /// Open the input device and install the tap
    ///
    /// Separate from `startRecording` so that a device switch mid-recording can
    /// reopen the device without discarding what has been captured so far.
    private func startCapture() throws {
        guard let recordingFormat = recordingFormat else {
            throw AudioRecorderError.invalidFormat
        }

        // Install the tap WITHOUT a format.
        //
        // Passing a format makes AVAudioEngine set the node's output format,
        // and on a Bluetooth microphone neither candidate is accepted: the
        // hardware runs at 24 kHz while the node claims 48 kHz, so both raise
        // the Objective-C exception "Input HW format and tap format not
        // matching", which Swift cannot catch - recording then died silently
        // and only AppKit logged it. With nil the tap delivers the node's own
        // format and the callback converts buffer.format to 16 kHz mono.
        //
        // Buffer size 1024 balances latency and efficiency.
        let tapBlock: AVAudioNodeTapBlock = { [weak self] buffer, time in
            guard let self = self else { return }

            // Convert buffer from hardware format to recording format if needed
            let processedBuffer: AVAudioPCMBuffer
            if let converter = self.converter(from: buffer.format, to: recordingFormat) {
                // Calculate the output frame capacity
                // Conversion ratio: outputFrames = inputFrames * (outputRate / inputRate)
                let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * recordingFormat.sampleRate / buffer.format.sampleRate)

                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: outputCapacity) else {
                    print("⚠️ Failed to create converted buffer")
                    return
                }

                // Perform the conversion
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                if let error = error {
                    print("⚠️ Audio conversion error: \(error.localizedDescription)")
                    return
                }

                processedBuffer = convertedBuffer
            } else {
                // No conversion needed, use buffer directly
                processedBuffer = buffer
            }

            // Calculate amplitude for real-time visual feedback
            // This happens on audio thread for performance
            let amplitude = self.audioAnalyzer.calculateAmplitude(from: processedBuffer)

            // Publish amplitude to AppState on main actor
            if let appState = self.appState {
                Task { @MainActor in
                    appState.currentAmplitude = amplitude
                }
            }

            // Copy buffer to preserve data (tap reuses buffer objects)
            guard let bufferCopy = self.copyBuffer(processedBuffer) else {
                print("⚠️ Failed to copy audio buffer")
                return
            }

            // Store buffer on serial queue for thread safety
            // audioBuffers is marked nonisolated(unsafe) to allow access from audio callback thread
            self.bufferQueue.async { [weak self] in
                self?.audioBuffers.append(bufferCopy)
            }
        }

        // Release the engine of a previous recording before opening the device
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Start on a fresh engine, retrying while the input device settles.
        //
        // AirPods switch the microphone link from 48 kHz to 24 kHz when the
        // input is opened. During that window the node's own formats
        // contradict each other (hardware 24 kHz, node 48 kHz) and the engine
        // refuses to start with error -10868. The second attempt succeeds, so
        // a few tries turn a dead dictation into a delay of a few hundred
        // milliseconds. Each attempt needs its own engine: a failed one stays
        // broken.
        var startError: Error?
        for attempt in 1...Self.engineStartAttempts {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let hardwareFormat = inputNode.inputFormat(forBus: 0)
            let nodeFormat = inputNode.outputFormat(forBus: 0)

            audioConverter = nil
            converterSourceFormat = nil
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil, block: tapBlock)

            do {
                try engine.start()
                audioEngine = engine
                observeConfigurationChanges(of: engine)
                startError = nil
                print("ℹ️ Input hardware \(hardwareFormat.sampleRate)Hz, node \(nodeFormat.sampleRate)Hz, \(nodeFormat.channelCount) channel(s)")
                AppLog.dictation.info("Attempt \(attempt, privacy: .public) started, hardware \(hardwareFormat.sampleRate, privacy: .public) Hz, node \(nodeFormat.sampleRate, privacy: .public) Hz \(nodeFormat.channelCount, privacy: .public) ch")
                break
            } catch {
                startError = error
                inputNode.removeTap(onBus: 0)
                engine.stop()
                let code = (error as NSError).code
                print("⚠️ Audio engine start attempt \(attempt) failed (\(code)), hardware \(hardwareFormat.sampleRate)Hz, node \(nodeFormat.sampleRate)Hz")
                AppLog.dictation.error("Attempt \(attempt, privacy: .public) failed with \(code, privacy: .public), hardware \(hardwareFormat.sampleRate, privacy: .public) Hz, node \(nodeFormat.sampleRate, privacy: .public) Hz")
                if attempt < Self.engineStartAttempts {
                    Thread.sleep(forTimeInterval: Self.engineStartRetryDelay)
                }
            }
        }

        if let startError {
            print("❌ Failed to start audio engine: \(startError.localizedDescription)")
            AppLog.dictation.error("Audio engine failed to start: \(startError.localizedDescription, privacy: .public)")
            // A device that never accepts its own format is unusable for
            // recording; say that instead of showing a Core Audio code
            if (startError as NSError).code == Self.formatNotSupported {
                throw AudioRecorderError.inputDeviceUnavailable
            }
            throw AudioRecorderError.engineStartFailed(startError)
        }

    }

    /// Watch for input device changes under the running engine
    private func observeConfigurationChanges(of engine: AVAudioEngine) {
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleConfigurationChange()
            }
        }
    }

    /// Reopen the device when its configuration changes while recording
    ///
    /// AirPods switch their microphone link as the input is opened. The engine
    /// then starts but delivers no buffers at all, which looked like a
    /// successful recording that happened to contain no speech. The
    /// notification arrives exactly at that switch, and a fresh engine captures
    /// normally, so the recording continues with only a short gap.
    private func handleConfigurationChange() {
        guard isRecording else { return }
        guard captureRestarts < Self.maximumCaptureRestarts else {
            AppLog.dictation.error("Input configuration changed again; not restarting")
            return
        }

        captureRestarts += 1
        print("🔄 Input device configuration changed - restarting capture (\(captureRestarts))")
        AppLog.dictation.info("Input configuration changed, restarting capture \(self.captureRestarts, privacy: .public)")

        do {
            try startCapture()
        } catch {
            print("❌ Capture restart failed: \(error.localizedDescription)")
            AppLog.dictation.error("Capture restart failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Converter from the tap's format to the 16 kHz mono recording format
    ///
    /// The tap chooses its own format, so the converter cannot be built before
    /// the first buffer arrives. It is cached and rebuilt only if the format
    /// changes while recording. Returns nil when the buffers already match the
    /// recording format and no conversion is needed.
    ///
    /// Called from the audio thread, which delivers buffers serially.
    private nonisolated func converter(from source: AVAudioFormat, to target: AVAudioFormat) -> AVAudioConverter? {
        guard source.sampleRate != target.sampleRate || source.channelCount != target.channelCount else {
            return nil
        }

        if let existing = audioConverter, let known = converterSourceFormat,
           known.sampleRate == source.sampleRate, known.channelCount == source.channelCount {
            return existing
        }

        guard let converter = AVAudioConverter(from: source, to: target) else {
            print("⚠️ Failed to create audio converter from \(source.sampleRate)Hz")
            AppLog.dictation.error("Failed to create audio converter from \(source.sampleRate, privacy: .public) Hz")
            return nil
        }
        // Mix multi-channel input down instead of keeping only the first channel
        converter.downmix = true
        audioConverter = converter
        converterSourceFormat = source
        print("ℹ️ Audio converter: \(source.sampleRate)Hz \(source.channelCount)ch → \(target.sampleRate)Hz \(target.channelCount)ch")
        AppLog.dictation.info("Audio converter \(source.sampleRate, privacy: .public) Hz \(source.channelCount, privacy: .public) ch to \(target.sampleRate, privacy: .public) Hz")
        return converter
    }

    /// Stop recording and return the recorded audio as Data
    /// - Returns: Audio data in WAV format suitable for Whisper API
    /// - Throws: AudioRecorderError if recording cannot be stopped or data conversion fails
    func stopRecording() throws -> Data {
        guard isRecording else {
            print("⚠️ No recording in progress")
            throw AudioRecorderError.notRecording
        }

        // Stop the audio engine
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationObserver = nil
        }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Clean up audio converter
        audioConverter = nil

        isRecording = false
        print("⏹️ Recording stopped")

        // Convert accumulated buffers to Data
        let audioData: Data = try bufferQueue.sync {
            let buffers = audioBuffers
            audioBuffers.removeAll() // Clear for next recording

            guard !buffers.isEmpty else {
                print("⚠️ No audio buffers captured")
                throw AudioRecorderError.noAudioData
            }

            print("📊 Converting \(buffers.count) audio buffers to Data...")
            return try convertBuffersToWAVData(buffers, format: recordingFormat!)
        }

        print("✅ Audio data ready: \(audioData.count) bytes")
        return audioData
    }

    // MARK: - Buffer Handling

    /// Create a copy of an audio buffer
    /// - Parameter buffer: The buffer to copy
    /// - Returns: A new buffer with copied data, or nil if copy fails
    private func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let format = buffer.format as AVAudioFormat?,
              let bufferCopy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameCapacity) else {
            return nil
        }

        bufferCopy.frameLength = buffer.frameLength

        // Copy audio data
        let channelCount = Int(format.channelCount)
        for channel in 0..<channelCount {
            if let src = buffer.floatChannelData?[channel],
               let dst = bufferCopy.floatChannelData?[channel] {
                dst.initialize(from: src, count: Int(buffer.frameLength))
            }
        }

        return bufferCopy
    }

    /// Convert array of PCM buffers to WAV format Data
    /// - Parameters:
    ///   - buffers: Array of audio buffers to convert
    ///   - format: Audio format of the buffers
    /// - Returns: WAV-formatted audio data
    /// - Throws: AudioRecorderError if conversion fails
    private func convertBuffersToWAVData(_ buffers: [AVAudioPCMBuffer], format: AVAudioFormat) throws -> Data {
        // Calculate total number of frames
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }

        guard totalFrames > 0 else {
            throw AudioRecorderError.noAudioData
        }

        // Create a combined buffer
        guard let combinedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else {
            throw AudioRecorderError.bufferAllocationFailed
        }

        // Copy all buffers into combined buffer
        var frameOffset = 0
        for buffer in buffers {
            let frameLength = Int(buffer.frameLength)
            let channelCount = Int(format.channelCount)

            for channel in 0..<channelCount {
                if let src = buffer.floatChannelData?[channel],
                   let dst = combinedBuffer.floatChannelData?[channel] {
                    let dstPtr = dst.advanced(by: frameOffset)
                    dstPtr.initialize(from: src, count: frameLength)
                }
            }

            frameOffset += frameLength
        }

        combinedBuffer.frameLength = AVAudioFrameCount(totalFrames)

        // Convert to WAV format Data
        return try convertPCMBufferToWAV(combinedBuffer, format: format)
    }

    /// Convert a single PCM buffer to WAV format
    /// - Parameters:
    ///   - buffer: The PCM buffer to convert
    ///   - format: Audio format
    /// - Returns: WAV-formatted audio data
    /// - Throws: AudioRecorderError if conversion fails
    private func convertPCMBufferToWAV(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) throws -> Data {
        // WAV file format structure:
        // - RIFF header (12 bytes)
        // - fmt chunk (24 bytes for PCM)
        // - data chunk header (8 bytes)
        // - audio data

        let channels = format.channelCount
        let sampleRate = UInt32(format.sampleRate)
        let bitsPerSample: UInt16 = 16 // Convert to 16-bit PCM for smaller file size
        let bytesPerSample = UInt32(bitsPerSample / 8)
        let bytesPerFrame = channels * bytesPerSample
        let frameCount = buffer.frameLength
        let audioDataSize = UInt32(frameCount * UInt32(bytesPerFrame))

        var wavData = Data()

        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!) // ChunkID
        wavData.append(Data(from: UInt32(36 + audioDataSize))) // ChunkSize
        wavData.append("WAVE".data(using: .ascii)!) // Format

        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!) // Subchunk1ID
        wavData.append(Data(from: UInt32(16))) // Subchunk1Size (16 for PCM)
        wavData.append(Data(from: UInt16(1))) // AudioFormat (1 = PCM)
        wavData.append(Data(from: UInt16(channels))) // NumChannels
        wavData.append(Data(from: sampleRate)) // SampleRate
        wavData.append(Data(from: sampleRate * UInt32(bytesPerFrame))) // ByteRate
        wavData.append(Data(from: UInt16(bytesPerFrame))) // BlockAlign
        wavData.append(Data(from: bitsPerSample)) // BitsPerSample

        // data chunk
        wavData.append("data".data(using: .ascii)!) // Subchunk2ID
        wavData.append(Data(from: audioDataSize)) // Subchunk2Size

        // Convert float32 samples to int16 and append
        guard let floatData = buffer.floatChannelData else {
            throw AudioRecorderError.dataConversionFailed
        }

        for frame in 0..<Int(frameCount) {
            for channel in 0..<Int(channels) {
                let sample = floatData[Int(channel)][frame]
                // Clamp to [-1.0, 1.0] and convert to Int16
                let clampedSample = max(-1.0, min(1.0, sample))
                let int16Sample = Int16(clampedSample * Float(Int16.max))
                wavData.append(Data(from: int16Sample))
            }
        }

        return wavData
    }
}

// MARK: - Errors

/// Errors that can occur during audio recording
enum AudioRecorderError: LocalizedError {
    case invalidFormat
    case inputDeviceUnavailable
    case engineStartFailed(Error)
    case notRecording
    case noAudioData
    case bufferAllocationFailed
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Audio recording format is invalid"
        case .inputDeviceUnavailable:
            return "The microphone did not accept recording. If you use Bluetooth headphones, try again in a moment or pick another input in System Settings → Sound."
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .notRecording:
            return "No recording in progress"
        case .noAudioData:
            return "No audio data was captured"
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer"
        case .dataConversionFailed:
            return "Failed to convert audio data to WAV format"
        }
    }
}

// MARK: - Data Extension

/// Helper extension to create Data from primitive types
private extension Data {
    init<T>(from value: T) {
        var value = value
        self = Swift.withUnsafeBytes(of: &value) { Data($0) }
    }
}
