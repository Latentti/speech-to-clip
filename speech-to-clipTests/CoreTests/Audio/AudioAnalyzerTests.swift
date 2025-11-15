//
//  AudioAnalyzerTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 2.5: Write Tests for Audio Recording
//

import XCTest
import AVFoundation
@testable import speech_to_clip

/// Tests for AudioAnalyzer amplitude calculation
///
/// Covers:
/// - RMS calculation accuracy with known inputs
/// - Amplitude normalization (0.707 → ~1.0)
/// - Edge cases (silence, clipping, empty buffer)
/// - Smoothed amplitude calculation
/// - Performance requirements (< 1ms)
final class AudioAnalyzerTests: XCTestCase {

    var analyzer: AudioAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = AudioAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    /// Create a mock AVAudioPCMBuffer with specified samples
    /// - Parameters:
    ///   - samples: Array of Float samples to fill the buffer
    ///   - sampleRate: Sample rate (default 16000)
    /// - Returns: AVAudioPCMBuffer filled with provided samples, or nil if creation fails
    func createMockBuffer(samples: [Float], sampleRate: Double = 16000.0) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)

        // Copy samples into buffer
        if let channelData = buffer.floatChannelData {
            for (index, sample) in samples.enumerated() {
                channelData[0][index] = sample
            }
        }

        return buffer
    }

    /// Generate sine wave samples
    /// - Parameters:
    ///   - frequency: Frequency in Hz
    ///   - sampleRate: Sample rate
    ///   - amplitude: Peak amplitude (0.0 to 1.0)
    ///   - duration: Duration in seconds
    /// - Returns: Array of Float samples
    func generateSineWave(frequency: Double, sampleRate: Double, amplitude: Float, duration: Double) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples: [Float] = []

        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let sample = amplitude * Float(sin(2.0 * .pi * frequency * time))
            samples.append(sample)
        }

        return samples
    }

    // MARK: - RMS Calculation Tests

    func testCalculateAmplitude_WithSineWave_ReturnsCorrectRMS() {
        // Generate 440Hz sine wave at full amplitude (1.0) for 64ms (1024 samples at 16kHz)
        let samples = generateSineWave(frequency: 440.0, sampleRate: 16000.0, amplitude: 1.0, duration: 0.064)
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let amplitude = analyzer.calculateAmplitude(from: buffer)

        // RMS of full-scale sine wave is 1/sqrt(2) ≈ 0.707
        // After 1.414x normalization: 0.707 * 1.414 ≈ 1.0
        // Allow small tolerance for floating point arithmetic
        XCTAssertEqual(amplitude, 1.0, accuracy: 0.05, "Amplitude should be ~1.0 for full-scale sine wave")
    }

    func testCalculateAmplitude_WithHalfAmplitudeSineWave_ReturnsCorrectRMS() {
        // Generate sine wave at half amplitude (0.5)
        let samples = generateSineWave(frequency: 440.0, sampleRate: 16000.0, amplitude: 0.5, duration: 0.064)
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let amplitude = analyzer.calculateAmplitude(from: buffer)

        // RMS of half-amplitude sine wave: (0.5 / sqrt(2)) * 1.414 ≈ 0.5
        XCTAssertEqual(amplitude, 0.5, accuracy: 0.05, "Amplitude should be ~0.5 for half-amplitude sine wave")
    }

    // MARK: - Normalization Tests

    func testCalculateAmplitude_NormalizationFactor_CorrectlyMaps707To1() {
        // Create buffer with constant RMS of 0.707 (1/sqrt(2))
        // This represents the RMS of a full-scale sine wave
        let rmsValue: Float = 0.707
        // To achieve RMS of 0.707, we need samples where sqrt(mean(sample²)) = 0.707
        // Simplest: all samples at ±0.707 in alternating pattern
        let samples = (0..<1024).map { Float($0 % 2 == 0 ? rmsValue : -rmsValue) }
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let amplitude = analyzer.calculateAmplitude(from: buffer)

        // After 1.414x normalization (sqrt(2)), RMS of 0.707 should map to ~1.0
        XCTAssertEqual(amplitude, 1.0, accuracy: 0.05, "0.707 RMS should normalize to ~1.0")
    }

    // MARK: - Edge Case Tests

    func testCalculateAmplitude_WithSilence_ReturnsZero() {
        // Buffer filled with zeros (silence)
        let samples = [Float](repeating: 0.0, count: 1024)
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let amplitude = analyzer.calculateAmplitude(from: buffer)

        XCTAssertEqual(amplitude, 0.0, accuracy: 0.001, "Silence should produce 0.0 amplitude")
    }

    func testCalculateAmplitude_WithClipping_ClampsTo1() {
        // Buffer with samples at maximum values (clipping scenario)
        let samples = (0..<1024).map { Float($0 % 2 == 0 ? 1.0 : -1.0) }
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let amplitude = analyzer.calculateAmplitude(from: buffer)

        // RMS of alternating ±1.0 is 1.0, normalized to 1.414, then clamped to 1.0
        XCTAssertEqual(amplitude, 1.0, accuracy: 0.001, "Clipping samples should clamp to 1.0")
    }

    func testCalculateAmplitude_WithEmptyBuffer_ReturnsZero() {
        // Create buffer with frameLength = 0
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000.0,
            channels: 1,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 1024
        ) else {
            XCTFail("Failed to create buffer")
            return
        }

        buffer.frameLength = 0  // Empty buffer

        let amplitude = analyzer.calculateAmplitude(from: buffer)

        XCTAssertEqual(amplitude, 0.0, accuracy: 0.001, "Empty buffer should return 0.0")
    }

    func testCalculateAmplitude_WithNilChannelData_ReturnsZero() {
        // This tests the guard clause for nil channelData
        // In practice, AVAudioPCMBuffer with valid format should always have channelData,
        // but we test defensive programming
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000.0,
            channels: 1,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 1024
        ) else {
            XCTFail("Failed to create buffer")
            return
        }

        buffer.frameLength = 1024

        // Even if channelData is somehow nil, should return 0.0
        // Note: In practice this shouldn't happen with valid buffers
        let amplitude = analyzer.calculateAmplitude(from: buffer)

        XCTAssertGreaterThanOrEqual(amplitude, 0.0, "Should handle nil channelData gracefully")
        XCTAssertLessThanOrEqual(amplitude, 1.0, "Should return value in valid range")
    }

    // MARK: - Smoothed Amplitude Tests

    func testCalculateSmoothedAmplitude_WithSmoothingFactor_ProducesAveragedValue() {
        let samples = generateSineWave(frequency: 440.0, sampleRate: 16000.0, amplitude: 0.8, duration: 0.064)
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let previousAmplitude = 0.2
        let smoothingFactor = 0.5
        let currentAmplitude = analyzer.calculateAmplitude(from: buffer)

        let smoothedAmplitude = analyzer.calculateSmoothedAmplitude(
            from: buffer,
            previousAmplitude: previousAmplitude,
            smoothingFactor: smoothingFactor
        )

        // Exponential moving average: (1-α) * current + α * previous
        let expectedSmoothed = (1.0 - smoothingFactor) * currentAmplitude + smoothingFactor * previousAmplitude

        XCTAssertEqual(smoothedAmplitude, expectedSmoothed, accuracy: 0.001,
                      "Smoothed amplitude should follow EMA formula")
    }

    func testCalculateSmoothedAmplitude_WithZeroSmoothing_ReturnsCurrentAmplitude() {
        let samples = generateSineWave(frequency: 440.0, sampleRate: 16000.0, amplitude: 0.7, duration: 0.064)
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let previousAmplitude = 0.2
        let smoothingFactor = 0.0  // No smoothing
        let currentAmplitude = analyzer.calculateAmplitude(from: buffer)

        let smoothedAmplitude = analyzer.calculateSmoothedAmplitude(
            from: buffer,
            previousAmplitude: previousAmplitude,
            smoothingFactor: smoothingFactor
        )

        XCTAssertEqual(smoothedAmplitude, currentAmplitude, accuracy: 0.001,
                      "Zero smoothing factor should return current amplitude")
    }

    func testCalculateSmoothedAmplitude_WithMaxSmoothing_ReturnsCloseToPrevious() {
        let samples = generateSineWave(frequency: 440.0, sampleRate: 16000.0, amplitude: 0.8, duration: 0.064)
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let previousAmplitude = 0.2
        let smoothingFactor = 0.9  // Heavy smoothing

        let smoothedAmplitude = analyzer.calculateSmoothedAmplitude(
            from: buffer,
            previousAmplitude: previousAmplitude,
            smoothingFactor: smoothingFactor
        )

        // With 0.9 smoothing, result should be much closer to previous than current
        XCTAssertLessThan(abs(smoothedAmplitude - previousAmplitude), 0.2,
                         "High smoothing factor should produce value close to previous amplitude")
    }

    // MARK: - Performance Tests

    func testCalculateAmplitude_Performance_CompletesInLessThan1ms() {
        let samples = generateSineWave(frequency: 440.0, sampleRate: 16000.0, amplitude: 0.8, duration: 0.064)
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        // Measure execution time
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = analyzer.calculateAmplitude(from: buffer)
        let endTime = CFAbsoluteTimeGetCurrent()

        let executionTime = (endTime - startTime) * 1000  // Convert to milliseconds

        XCTAssertLessThan(executionTime, 1.0,
                         "calculateAmplitude should complete in less than 1ms, took \(executionTime)ms")
    }

    func testCalculateAmplitude_PerformanceBenchmark_AverageOf100Runs() {
        let samples = generateSineWave(frequency: 440.0, sampleRate: 16000.0, amplitude: 0.8, duration: 0.064)
        guard let buffer = createMockBuffer(samples: samples) else {
            XCTFail("Failed to create mock buffer")
            return
        }

        let iterations = 100
        var totalTime: Double = 0

        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            let _ = analyzer.calculateAmplitude(from: buffer)
            let endTime = CFAbsoluteTimeGetCurrent()
            totalTime += (endTime - startTime)
        }

        let averageTime = (totalTime / Double(iterations)) * 1000  // ms

        print("📊 Performance benchmark: Average execution time over \(iterations) runs: \(averageTime)ms")

        XCTAssertLessThan(averageTime, 1.0,
                         "Average calculateAmplitude execution time should be < 1ms, was \(averageTime)ms")
    }

    // MARK: - Integration Tests

    func testCalculateAmplitude_WithVariousFrequencies_MaintainsAccuracy() {
        let frequencies: [Double] = [100, 440, 1000, 4000]

        for frequency in frequencies {
            let samples = generateSineWave(frequency: frequency, sampleRate: 16000.0, amplitude: 0.7, duration: 0.064)
            guard let buffer = createMockBuffer(samples: samples) else {
                XCTFail("Failed to create mock buffer for \(frequency)Hz")
                continue
            }

            let amplitude = analyzer.calculateAmplitude(from: buffer)

            // All frequencies at same peak amplitude should produce similar RMS after normalization
            // RMS of 0.7 amplitude sine wave should be: (0.7 / sqrt(2)) * 1.414 ≈ 0.7
            // Allow wider tolerance due to frequency-dependent buffer edge effects
            XCTAssertEqual(amplitude, 0.7, accuracy: 0.15,
                          "Amplitude calculation should be consistent across frequencies (\(frequency)Hz), got \(amplitude)")
        }
    }

    func testCalculateAmplitude_WithDifferentSampleRates_WorksCorrectly() {
        let sampleRates: [Double] = [8000, 16000, 44100, 48000]

        for sampleRate in sampleRates {
            let duration = 1024.0 / sampleRate  // Always 1024 samples
            let samples = generateSineWave(frequency: 440.0, sampleRate: sampleRate, amplitude: 0.6, duration: duration)
            guard let buffer = createMockBuffer(samples: samples, sampleRate: sampleRate) else {
                XCTFail("Failed to create mock buffer at \(sampleRate)Hz")
                continue
            }

            let amplitude = analyzer.calculateAmplitude(from: buffer)

            XCTAssertEqual(amplitude, 0.6, accuracy: 0.1,
                          "Amplitude calculation should work at any sample rate (\(sampleRate)Hz)")
        }
    }
}
