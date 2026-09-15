//
//  AudioSampleUtilities.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: shared audio sample helpers
//

@preconcurrency import AVFoundation
import Foundation

/// Converts audio buffers of any format to 16 kHz mono Float32 samples
///
/// One converter instance is reused for the whole stream so the sample-rate
/// converter keeps its filter state between buffers. Speakers deliver 48 kHz
/// stereo, Bluetooth headsets 24 kHz; whisper.cpp expects 16 kHz mono.
nonisolated final class MonoResampler {
    /// Output sample rate used for whisper.cpp
    static let outputSampleRate: Double = 16_000

    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init?(inputFormat: AVAudioFormat) {
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.outputSampleRate,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return nil
        }
        converter.downmix = true
        self.converter = converter
        self.outputFormat = outputFormat
    }

    /// Convert one buffer
    /// - Returns: 16 kHz mono samples, or an empty array if conversion fails
    func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard buffer.frameLength > 0 else { return [] }
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return [] }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil, let channel = output.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength)))
    }
}

/// Thread-safe audio level for the live meters and stall detection
nonisolated final class LevelMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Float = 0
    private var lastUpdate = Date()

    /// Record a new block of samples (called from an audio thread)
    func update(with samples: [Float]) {
        guard !samples.isEmpty else { return }
        let rms = Self.rms(samples)
        lock.lock()
        current = max(rms, current * 0.7)
        lastUpdate = Date()
        lock.unlock()
    }

    /// Latest RMS level, or 0 when no samples arrived recently
    var value: Float {
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(lastUpdate) < 0.5 ? current : 0
    }

    /// Seconds since samples last arrived (measured from creation before the first block)
    var secondsSinceLastUpdate: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(lastUpdate)
    }

    static func rms<Samples: Collection>(_ samples: Samples) -> Float where Samples.Element == Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return (sum / Float(samples.count)).squareRoot()
    }
}

/// Encodes mono Float32 samples as a 16-bit PCM WAV file
nonisolated enum WAVEncoder {
    static func encode(samples: [Float], sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let dataSize = samples.count * bytesPerSample

        var data = Data(capacity: 44 + dataSize)
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16))                          // fmt chunk size
        data.appendLittleEndian(UInt16(1))                           // PCM
        data.appendLittleEndian(UInt16(1))                           // mono
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * bytesPerSample)) // byte rate
        data.appendLittleEndian(UInt16(bytesPerSample))              // block align
        data.appendLittleEndian(UInt16(16))                          // bits per sample

        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(UInt32(dataSize))

        let pcm = samples.map { Int16(max(-1, min(1, $0)) * Float(Int16.max)).littleEndian }
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}

private extension Data {
    nonisolated mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
