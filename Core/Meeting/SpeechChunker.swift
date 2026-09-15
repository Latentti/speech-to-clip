//
//  SpeechChunker.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: split continuous audio into speech chunks
//

import Foundation

/// A span of speech cut from one audio source, ready for transcription
nonisolated struct AudioChunk {
    let speaker: MeetingSpeaker
    /// Seconds from meeting start
    let startTime: TimeInterval
    /// Seconds from meeting start
    let endTime: TimeInterval
    /// 16 kHz mono samples
    let samples: [Float]
}

/// Splits a continuous 16 kHz sample stream into speech chunks
///
/// Whisper invents text for silent audio and at its internal 30-second window
/// seams, so the chunker:
/// - skips silence entirely, keeping a short pre-roll before speech starts
/// - cuts at pauses, accepting shorter pauses as the chunk grows long
/// - never emits a chunk longer than `hardMaximumDuration`
/// - drops chunks with too little speech to be meaningful
///
/// Speech is detected per 30 ms frame by comparing RMS energy against an
/// adaptive noise floor.
///
/// **Delivery tracking:** `coveredUntil` does not move past an emitted chunk
/// until the receiver calls `acknowledgeDelivery(startTime:)`. The meeting
/// session uses it to know when all system audio up to a moment has reached
/// the transcription queue.
///
/// Thread-safe: `append` runs on an audio thread, `flush` and `resync` on the main thread.
/// `onChunk` is called synchronously on the calling thread.
nonisolated final class SpeechChunker: @unchecked Sendable {
    struct Configuration {
        var sampleRate: Double = MonoResampler.outputSampleRate
        var frameDuration: TimeInterval = 0.03
        /// Frames below this RMS are always silence
        var minimumSpeechThreshold: Float = 0.006
        /// Speech must be this many times louder than the noise floor
        var noiseFloorMultiplier: Float = 3
        /// Upper bound for the adaptive noise floor so long speech is never reclassified as noise
        var maximumNoiseFloor: Float = 0.015
        /// Pause that ends a chunk (shorter pauses inside a thought keep the sentence in one chunk)
        var silenceToSplit: TimeInterval = 0.9
        /// Shorter pause accepted once the chunk exceeds `softMaximumDuration`
        var shortSilenceToSplit: TimeInterval = 0.25
        var softMaximumDuration: TimeInterval = 18
        /// Kept well below whisper's 30-second window
        var hardMaximumDuration: TimeInterval = 25
        /// Chunks with less detected speech are discarded
        var minimumSpeechDuration: TimeInterval = 0.5
        var preRollDuration: TimeInterval = 0.3
        var trailingSilenceToKeep: TimeInterval = 0.3
    }

    let speaker: MeetingSpeaker
    private let configuration: Configuration
    private let onChunk: @Sendable (AudioChunk) -> Void
    private let lock = NSLock()

    private let frameLength: Int
    private let preRollFrames: Int
    private let trailingFramesToKeep: Int

    private var pendingSamples: [Float] = []
    /// Absolute sample position of the next frame
    private var processedSamples = 0
    private var chunk: [Float] = []
    private var chunkStartSample = 0
    private var speechFrames = 0
    private var silenceFrames = 0
    private var preRoll: [[Float]] = []
    private var noiseFloor: Float = 0.002
    private var undeliveredStarts: [TimeInterval] = []

    init(
        speaker: MeetingSpeaker,
        configuration: Configuration = Configuration(),
        onChunk: @escaping @Sendable (AudioChunk) -> Void
    ) {
        self.speaker = speaker
        self.configuration = configuration
        self.onChunk = onChunk
        frameLength = Int(configuration.sampleRate * configuration.frameDuration)
        preRollFrames = Int((configuration.preRollDuration / configuration.frameDuration).rounded())
        trailingFramesToKeep = Int((configuration.trailingSilenceToKeep / configuration.frameDuration).rounded())
    }

    // MARK: - Public API

    /// Seconds of audio that is either delivered as chunks or discarded as silence
    var coveredUntil: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        let openStart = chunk.isEmpty ? processedSamples : chunkStartSample
        let analysed = Double(openStart) / configuration.sampleRate
        return min(analysed, undeliveredStarts.min() ?? .infinity)
    }

    /// Append 16 kHz mono samples
    func append(_ samples: [Float]) {
        var emitted: [AudioChunk] = []
        lock.lock()
        pendingSamples.append(contentsOf: samples)
        var offset = 0
        while pendingSamples.count - offset >= frameLength {
            let frame = Array(pendingSamples[offset..<(offset + frameLength)])
            offset += frameLength
            if let chunk = process(frame) {
                emitted.append(chunk)
            }
        }
        pendingSamples.removeFirst(offset)
        lock.unlock()
        emitted.forEach(onChunk)
    }

    /// Emit the open chunk, if it contains enough speech
    func flush() {
        lock.lock()
        let emitted = closeOpenChunk()
        lock.unlock()
        if let emitted {
            onChunk(emitted)
        }
    }

    /// Jump the timeline forward after a capture restart, emitting the open chunk first
    ///
    /// - Parameter time: Seconds from meeting start where the next samples belong
    func resync(to time: TimeInterval) {
        lock.lock()
        let emitted = closeOpenChunk()
        processedSamples = max(processedSamples, Int(time * configuration.sampleRate))
        preRoll.removeAll()
        lock.unlock()
        if let emitted {
            onChunk(emitted)
        }
    }

    /// Mark an emitted chunk as received so `coveredUntil` can move past it
    func acknowledgeDelivery(startTime: TimeInterval) {
        lock.lock()
        if let index = undeliveredStarts.firstIndex(of: startTime) {
            undeliveredStarts.remove(at: index)
        }
        lock.unlock()
    }

    // MARK: - Frame Processing (lock held)

    private func process(_ frame: [Float]) -> AudioChunk? {
        let frameStart = processedSamples
        processedSamples += frame.count

        let rms = LevelMeter.rms(frame)
        let threshold = max(configuration.minimumSpeechThreshold, noiseFloor * configuration.noiseFloorMultiplier)
        let isSpeech = rms > threshold
        updateNoiseFloor(with: rms)

        if chunk.isEmpty {
            guard isSpeech else {
                preRoll.append(frame)
                if preRoll.count > preRollFrames {
                    preRoll.removeFirst()
                }
                return nil
            }
            let preRollSamples = preRoll.reduce(0) { $0 + $1.count }
            chunkStartSample = frameStart - preRollSamples
            chunk = preRoll.flatMap { $0 }
            chunk.append(contentsOf: frame)
            preRoll.removeAll()
            speechFrames = 1
            silenceFrames = 0
            return nil
        }

        chunk.append(contentsOf: frame)
        if isSpeech {
            speechFrames += 1
            silenceFrames = 0
        } else {
            silenceFrames += 1
        }

        let duration = Double(chunk.count) / configuration.sampleRate
        let silence = Double(silenceFrames) * configuration.frameDuration
        let requiredSilence = duration >= configuration.softMaximumDuration
            ? configuration.shortSilenceToSplit
            : configuration.silenceToSplit

        if silenceFrames > 0 && silence >= requiredSilence {
            return finishChunk(trimTrailingSilence: true)
        }
        // Cut before the next frame would push the chunk past the hard maximum
        let durationWithNextFrame = Double(chunk.count + frameLength) / configuration.sampleRate
        if durationWithNextFrame > configuration.hardMaximumDuration {
            return finishChunk(trimTrailingSilence: false)
        }
        return nil
    }

    /// Follow quiet frames down immediately, rise slowly and never above the cap
    private func updateNoiseFloor(with rms: Float) {
        if rms < noiseFloor {
            noiseFloor = rms
        } else {
            noiseFloor += (rms - noiseFloor) * 0.0005
        }
        noiseFloor = min(noiseFloor, configuration.maximumNoiseFloor)
    }

    private func closeOpenChunk() -> AudioChunk? {
        if !chunk.isEmpty {
            chunk.append(contentsOf: pendingSamples)
        }
        processedSamples += pendingSamples.count
        pendingSamples.removeAll()
        return finishChunk(trimTrailingSilence: false)
    }

    private func finishChunk(trimTrailingSilence: Bool) -> AudioChunk? {
        guard !chunk.isEmpty else { return nil }
        defer {
            chunk.removeAll(keepingCapacity: true)
            speechFrames = 0
            silenceFrames = 0
        }

        if trimTrailingSilence && silenceFrames > trailingFramesToKeep {
            let removable = (silenceFrames - trailingFramesToKeep) * frameLength
            chunk.removeLast(min(removable, chunk.count))
        }

        let speechDuration = Double(speechFrames) * configuration.frameDuration
        guard speechDuration >= configuration.minimumSpeechDuration else { return nil }

        let startTime = Double(chunkStartSample) / configuration.sampleRate
        let endTime = Double(chunkStartSample + chunk.count) / configuration.sampleRate
        undeliveredStarts.append(startTime)
        return AudioChunk(speaker: speaker, startTime: startTime, endTime: endTime, samples: chunk)
    }
}
