//
//  AudioAnalyzer.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 2.3: Implement Real-time Amplitude Detection
//

import Foundation
import AVFoundation

/// AudioAnalyzer provides real-time audio amplitude analysis
///
/// This class calculates RMS (Root Mean Square) amplitude from audio buffers
/// to provide visual feedback during recording. The amplitude is normalized
/// to a 0.0-1.0 range where 0.0 represents silence and 1.0 represents maximum
/// possible amplitude (clipping).
///
/// Performance characteristics:
/// - Calculation time: < 1ms per buffer (1024 samples)
/// - Update rate: ~15.6 Hz (every 64ms at 16kHz sample rate)
/// - Thread-safe: Can be called from audio callback thread
///
/// Usage:
/// ```swift
/// let analyzer = AudioAnalyzer()
/// let amplitude = analyzer.calculateAmplitude(from: buffer)
/// // amplitude is in range 0.0...1.0
/// ```
class AudioAnalyzer {

    /// Calculate RMS amplitude from audio buffer
    ///
    /// This method computes the Root Mean Square (RMS) amplitude from the provided
    /// PCM audio buffer. RMS provides a perceptually accurate measure of loudness
    /// that correlates well with how humans perceive sound intensity.
    ///
    /// Algorithm:
    /// 1. Extract Float32 samples from buffer
    /// 2. Square each sample
    /// 3. Calculate mean of squared values
    /// 4. Take square root
    /// 5. Normalize to 0.0-1.0 range
    ///
    /// Performance: Optimized for real-time use. Completes in < 1ms for typical
    /// buffer sizes (1024 samples).
    ///
    /// - Parameter buffer: AVAudioPCMBuffer containing Float32 PCM samples
    /// - Returns: Normalized amplitude in range 0.0 (silence) to 1.0 (max amplitude)
    ///
    /// - Note: Thread-safe - can be called from audio callback thread
    func calculateAmplitude(from buffer: AVAudioPCMBuffer) -> Double {
        // Ensure buffer has valid audio data
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            return 0.0
        }

        // Get first channel (mono recording, so only one channel)
        let channel = channelData[0]
        let frameLength = Int(buffer.frameLength)

        // Calculate RMS (Root Mean Square)
        // RMS = sqrt(sum(sample²) / count)
        var sum: Float = 0.0

        for frame in 0..<frameLength {
            let sample = channel[frame]
            sum += sample * sample  // Square the sample
        }

        let meanSquare = sum / Float(frameLength)  // Mean of squared values
        let rms = sqrt(meanSquare)  // Square root

        // Normalize to 0.0-1.0 range
        // PCM Float32 samples are in range -1.0 to 1.0
        // RMS of a full-scale sine wave is 1/sqrt(2) ≈ 0.707
        // We normalize so that 0.707 maps to approximately 1.0 for typical audio
        // This makes the amplitude more intuitive (louder = higher value)
        let normalized = Double(rms) * 1.414  // Multiply by sqrt(2)

        // Clamp to 0.0-1.0 range (in case of clipping or very loud audio)
        return min(max(normalized, 0.0), 1.0)
    }

    /// Calculate amplitude with smoothing factor
    ///
    /// This variant applies exponential smoothing to reduce rapid fluctuations
    /// and provide a more stable amplitude reading.
    ///
    /// - Parameters:
    ///   - buffer: AVAudioPCMBuffer containing audio samples
    ///   - previousAmplitude: Previous amplitude value for smoothing
    ///   - smoothingFactor: Smoothing factor (0.0 = no smoothing, 1.0 = maximum smoothing)
    /// - Returns: Smoothed amplitude in range 0.0-1.0
    ///
    /// - Note: Currently not used, but available for future enhancements if amplitude
    ///         fluctuates too rapidly for visual feedback
    func calculateSmoothedAmplitude(
        from buffer: AVAudioPCMBuffer,
        previousAmplitude: Double,
        smoothingFactor: Double = 0.3
    ) -> Double {
        let currentAmplitude = calculateAmplitude(from: buffer)

        // Exponential moving average: new = (1-α) * current + α * previous
        // where α is the smoothing factor
        let smoothed = (1.0 - smoothingFactor) * currentAmplitude + smoothingFactor * previousAmplitude

        return smoothed
    }
}
