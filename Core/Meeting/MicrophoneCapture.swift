//
//  MicrophoneCapture.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: capture the user's own voice
//

import AVFoundation
import Foundation

/// Captures the default input device as 16 kHz mono samples for a meeting
///
/// Voice processing (echo cancellation) is deliberately not enabled: it stops
/// the system audio tap from receiving audio. Speaker echo is filtered from the
/// transcript instead (see `EchoFilter`).
///
/// AVAudioEngine stops when the input device changes; `onConfigurationChange`
/// tells the owner to restart with a new capture instance.
nonisolated final class MicrophoneCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var resampler: MonoResampler?
    private var configurationObserver: NSObjectProtocol?
    private let meter = LevelMeter()

    /// Current RMS level for the live meter
    var level: Float { meter.value }

    /// Seconds since the input last delivered audio
    var secondsSinceLastSamples: TimeInterval { meter.secondsSinceLastUpdate }

    /// Start capturing
    ///
    /// - Parameters:
    ///   - onSamples: Receives 16 kHz mono samples on the audio tap thread
    ///   - onConfigurationChange: Called when the audio hardware configuration changes
    func start(
        onSamples: @escaping @Sendable ([Float]) -> Void,
        onConfigurationChange: @escaping @Sendable () -> Void
    ) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0,
              let resampler = MonoResampler(inputFormat: format) else {
            throw MeetingCaptureError.unsupportedFormat
        }
        self.resampler = resampler

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let resampler = self.resampler else { return }
            let samples = resampler.convert(buffer)
            self.meter.update(with: samples)
            onSamples(samples)
        }

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { _ in
            onConfigurationChange()
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            stop()
            throw MeetingCaptureError.engineStartFailed(error)
        }
    }

    /// Stop capturing
    func stop() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
