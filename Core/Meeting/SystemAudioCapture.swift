//
//  SystemAudioCapture.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: capture what other participants say
//

import AudioToolbox
import AVFoundation
import CoreAudio
import os.log

/// Errors from meeting audio capture
nonisolated enum MeetingCaptureError: LocalizedError {
    case coreAudio(String, OSStatus)
    case unsupportedFormat
    case engineStartFailed(Error)

    var errorDescription: String? {
        switch self {
        case .coreAudio(let call, let status):
            return "\(call) epäonnistui (OSStatus \(status))"
        case .unsupportedFormat:
            return "Äänilaitteen formaattia ei tueta"
        case .engineStartFailed(let error):
            return "Mikrofonin käynnistys epäonnistui: \(error.localizedDescription)"
        }
    }
}

/// Captures everything the Mac plays, excluding this app, as 16 kHz mono samples
///
/// Uses a Core Audio process tap (macOS 14.2+) attached to a private aggregate
/// device built on the default output device. A global tap is used because
/// Teams plays audio through several helper processes and Google Meet runs
/// inside a browser.
///
/// Requires `NSAudioCaptureUsageDescription`; macOS asks the user once for
/// permission to record system audio. No screen recording permission is needed.
///
/// When the default output device changes (for example AirPods connect), the
/// aggregate device no longer follows the audio; `onDeviceChange` tells the
/// owner to restart the capture.
nonisolated final class SystemAudioCapture: @unchecked Sendable {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var tapFormat: AVAudioFormat?
    private var resampler: MonoResampler?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private let queue = DispatchQueue(label: "com.latentti.speech-to-clip.meeting.system-audio", qos: .userInitiated)
    private let meter = LevelMeter()
    private let logger = Logger(subsystem: "com.latentti.speech-to-clip", category: "SystemAudioCapture")

    /// Current RMS level for the live meter
    var level: Float { meter.value }

    /// Seconds since the tap last delivered audio (the tap delivers silence too)
    var secondsSinceLastSamples: TimeInterval { meter.secondsSinceLastUpdate }

    // MARK: - Lifecycle

    /// Start capturing
    ///
    /// - Parameters:
    ///   - onSamples: Receives 16 kHz mono samples on a capture queue
    ///   - onDeviceChange: Called when the default output device changes
    func start(
        onSamples: @escaping @Sendable ([Float]) -> Void,
        onDeviceChange: @escaping @Sendable () -> Void
    ) throws {
        do {
            try createTap()
            try createAggregateDevice()
            try startIO(onSamples: onSamples)
            listenForOutputDeviceChanges(onDeviceChange)
        } catch {
            stop()
            throw error
        }
    }

    /// Stop capturing and release the tap and aggregate device
    func stop() {
        if let deviceListener {
            var address = Self.address(kAudioHardwarePropertyDefaultSystemOutputDevice)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, deviceListener)
            self.deviceListener = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, ioProcID)
            if let ioProcID {
                AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
            ioProcID = nil
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    // MARK: - Setup

    private func createTap() throws {
        let ownProcess = Self.processObjectID(for: getpid())
        let excluded = ownProcess == kAudioObjectUnknown ? [] : [ownProcess]

        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
        description.uuid = UUID()
        description.name = "Speech to Clip meeting tap"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        let status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else { throw MeetingCaptureError.coreAudio("AudioHardwareCreateProcessTap", status) }

        var streamDescription = try Self.value(of: kAudioTapPropertyFormat, on: tapID, initial: AudioStreamBasicDescription())
        guard let format = AVAudioFormat(streamDescription: &streamDescription),
              let resampler = MonoResampler(inputFormat: format) else {
            throw MeetingCaptureError.unsupportedFormat
        }
        tapFormat = format
        self.resampler = resampler
        tapUUID = description.uuid
        logger.info("Tap created with format \(format.description)")
    }

    private var tapUUID = UUID()

    private func createAggregateDevice() throws {
        let outputDevice = try Self.value(
            of: kAudioHardwarePropertyDefaultSystemOutputDevice,
            on: AudioObjectID(kAudioObjectSystemObject),
            initial: AudioDeviceID(kAudioObjectUnknown)
        )
        let outputUID = try Self.string(of: kAudioDevicePropertyDeviceUID, on: outputDevice)

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Speech to Clip meeting capture",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: tapUUID.uuidString,
            ]],
        ]
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
        guard status == noErr else { throw MeetingCaptureError.coreAudio("AudioHardwareCreateAggregateDevice", status) }
        logger.info("Aggregate device created on output \(outputUID)")
    }

    private func startIO(onSamples: @escaping @Sendable ([Float]) -> Void) throws {
        var status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, queue) { [weak self] _, inputData, _, _, _ in
            guard let self, let format = self.tapFormat, let resampler = self.resampler,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inputData, deallocator: nil)
            else { return }
            let samples = resampler.convert(buffer)
            self.meter.update(with: samples)
            onSamples(samples)
        }
        guard status == noErr else { throw MeetingCaptureError.coreAudio("AudioDeviceCreateIOProcIDWithBlock", status) }

        status = AudioDeviceStart(aggregateID, ioProcID)
        guard status == noErr else { throw MeetingCaptureError.coreAudio("AudioDeviceStart", status) }
    }

    private func listenForOutputDeviceChanges(_ onDeviceChange: @escaping @Sendable () -> Void) {
        var address = Self.address(kAudioHardwarePropertyDefaultSystemOutputDevice)
        let listener: AudioObjectPropertyListenerBlock = { _, _ in onDeviceChange() }
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, listener)
        if status == noErr {
            deviceListener = listener
        } else {
            logger.error("Output device listener failed: \(status)")
        }
    }

    // MARK: - Core Audio Property Helpers

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func value<T>(of selector: AudioObjectPropertySelector, on objectID: AudioObjectID, initial: T) throws -> T {
        var address = address(selector)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
        }
        guard status == noErr else { throw MeetingCaptureError.coreAudio("AudioObjectGetPropertyData", status) }
        return value
    }

    private static func string(of selector: AudioObjectPropertySelector, on objectID: AudioObjectID) throws -> String {
        var address = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let string = value else {
            throw MeetingCaptureError.coreAudio("AudioObjectGetPropertyData", status)
        }
        return string.takeRetainedValue() as String
    }

    private static func processObjectID(for pid: pid_t) -> AudioObjectID {
        var address = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var qualifier = pid
        var result = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address,
            UInt32(MemoryLayout<pid_t>.size), &qualifier, &size, &result
        )
        return status == noErr ? result : AudioObjectID(kAudioObjectUnknown)
    }
}
