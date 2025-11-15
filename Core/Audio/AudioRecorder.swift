//
//  AudioRecorder.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 2.2: Implement Audio Recording with AVFoundation
//

import Foundation
import AVFoundation

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
    private let audioEngine = AVAudioEngine()

    /// Accumulated audio buffers during recording (nonisolated for audio callback thread access)
    private nonisolated(unsafe) var audioBuffers: [AVAudioPCMBuffer] = []

    /// Serial queue for thread-safe buffer accumulation
    private let bufferQueue = DispatchQueue(label: "com.speech-to-clip.audiorecorder.buffer")

    /// Recording format: 16kHz mono PCM (suitable for Whisper API)
    private var recordingFormat: AVAudioFormat?

    /// Audio converter for resampling from hardware format to recording format
    private var audioConverter: AVAudioConverter?

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

        guard let recordingFormat = recordingFormat else {
            throw AudioRecorderError.invalidFormat
        }

        // Clear previous buffers
        bufferQueue.sync {
            audioBuffers.removeAll()
        }

        // Note: On macOS, we don't need to configure audio session like on iOS
        // The system handles microphone access and will prompt for permission if needed

        // Get the input node from the audio engine
        let inputNode = audioEngine.inputNode

        // Get the hardware format from the input node
        // The tap format MUST match the hardware format
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        print("ℹ️ Hardware format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount) channel(s)")

        // Create audio converter if hardware format doesn't match recording format
        // This handles sample rate conversion (e.g., 48kHz → 16kHz) and channel count (stereo → mono)
        if hardwareFormat.sampleRate != recordingFormat.sampleRate ||
           hardwareFormat.channelCount != recordingFormat.channelCount {
            guard let converter = AVAudioConverter(from: hardwareFormat, to: recordingFormat) else {
                throw AudioRecorderError.invalidFormat
            }
            audioConverter = converter
            print("ℹ️ Audio converter created: \(hardwareFormat.sampleRate)Hz → \(recordingFormat.sampleRate)Hz, \(hardwareFormat.channelCount) → \(recordingFormat.channelCount) channels")
        }

        // Install tap on input node to capture audio buffers
        // IMPORTANT: Tap format must match hardware format, we'll convert to recording format in the callback
        // Buffer size 1024 provides good balance between latency and efficiency
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, time in
            guard let self = self else { return }

            // Convert buffer from hardware format to recording format if needed
            let processedBuffer: AVAudioPCMBuffer
            if let converter = self.audioConverter, let recordingFormat = self.recordingFormat {
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

        // Start the audio engine
        do {
            try audioEngine.start()
            isRecording = true
            print("🎤 Recording started")
        } catch {
            // Clean up tap if engine start fails
            inputNode.removeTap(onBus: 0)
            print("❌ Failed to start audio engine: \(error.localizedDescription)")
            throw AudioRecorderError.engineStartFailed(error)
        }
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
    case engineStartFailed(Error)
    case notRecording
    case noAudioData
    case bufferAllocationFailed
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Audio recording format is invalid"
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
