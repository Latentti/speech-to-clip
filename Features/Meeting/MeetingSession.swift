//
//  MeetingSession.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: session orchestration
//

import AppKit
import AVFoundation
import Combine
import os.log

/// Lifecycle of a meeting transcription session
enum MeetingState: Equatable {
    case idle
    case starting
    case running
    /// Captures stopped; remaining chunks are being transcribed
    case stopping
}

/// whisper.cpp server settings taken from a Local Whisper profile
struct WhisperServerConfig {
    let port: Int
    let model: String
    let language: String
    let profileName: String

    /// Prefer the active profile when it uses Local Whisper, otherwise the first Local Whisper profile
    static func resolve(profileManager: ProfileManager = ProfileManager()) -> WhisperServerConfig? {
        let active = try? profileManager.getActiveProfile()
        let profiles = (try? profileManager.getAllProfiles()) ?? []
        let localActive = active.flatMap { $0.transcriptionEngine == .localWhisper ? $0 : nil }
        guard let profile = localActive ?? profiles.first(where: { $0.transcriptionEngine == .localWhisper }) else {
            return nil
        }
        return WhisperServerConfig(
            port: profile.whisperServerPort,
            model: profile.whisperModelName ?? "base",
            language: profile.language,
            profileName: profile.name
        )
    }
}

/// Live transcription of a Teams or Google Meet meeting
///
/// Captures the microphone ("Minä") and system audio ("Muut") separately,
/// cuts both into speech chunks, transcribes them one at a time with the local
/// whisper.cpp server and appends each result to `transcript.md`.
///
/// **Reliability:** every chunk is written to the session's `.pending` folder
/// before transcription and deleted only after its text is in the transcript.
/// Chunks left behind by a crash or an unavailable server are transcribed by
/// `recoverPendingChunks()` on the next launch. Captures that stop delivering
/// audio are restarted automatically.
///
/// **Echo:** when the meeting plays through speakers the microphone hears the
/// other participants too. Microphone segments are held until the overlapping
/// system audio has been transcribed and dropped if their words largely match it.
///
/// Dictation is disabled while a session is active (see `HotkeyManager`).
@MainActor
final class MeetingSession: ObservableObject {
    static let shared = MeetingSession()

    // MARK: - Published State

    @Published private(set) var state: MeetingState = .idle
    /// Accepted segments in chronological order
    @Published private(set) var segments: [TranscriptSegment] = []
    @Published private(set) var micLevel: Float = 0
    @Published private(set) var systemLevel: Float = 0
    @Published private(set) var isMicrophoneActive = false
    @Published private(set) var isSystemAudioActive = false
    @Published private(set) var microphoneStalled = false
    @Published private(set) var systemAudioStalled = false
    @Published private(set) var pendingCount = 0
    @Published private(set) var startedAt: Date?
    @Published private(set) var endedAt: Date?
    @Published private(set) var lastSegmentAt: Date?
    @Published private(set) var folderURL: URL?
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    var isActive: Bool { state != .idle }

    // MARK: - Tuning

    /// Seconds without samples before a capture is considered stalled
    private let stallThreshold: TimeInterval = 3
    /// Minimum seconds between start attempts of one capture
    private let restartInterval: TimeInterval = 5

    // MARK: - Dependencies

    private let whisperClient = WhisperCppClient()
    private let ioQueue = DispatchQueue(label: "com.latentti.speech-to-clip.meeting.io")
    private let logger = Logger(subsystem: "com.latentti.speech-to-clip", category: "MeetingSession")

    // MARK: - Session State

    private var config: WhisperServerConfig?
    private var writer: TranscriptWriter?
    private var microphone: MicrophoneCapture?
    private var systemAudio: SystemAudioCapture?
    private var micChunker: SpeechChunker?
    private var systemChunker: SpeechChunker?
    private var wantsMicrophone = false
    private var wantsSystemAudio = false
    private var lastMicrophoneStart = Date.distantPast
    private var lastSystemAudioStart = Date.distantPast
    private var queue: [PendingChunk] = []
    private var heldMicSegments: [TranscriptSegment] = []
    private var capturesFlushed = false
    private var serverWarningShown = false
    private var meterTimer: Timer?
    private var isRecovering = false

    private init() {}

    // MARK: - Start and Stop

    /// Start a meeting session
    ///
    /// Requires a Local Whisper profile. Recording starts even if whisper-server
    /// is not responding yet; chunks wait in the queue until it answers.
    func start() async {
        guard state == .idle else { return }
        state = .starting
        errorMessage = nil
        statusMessage = nil

        guard let config = WhisperServerConfig.resolve() else {
            failStart("Palaveritila tarvitsee Local Whisper -profiilin. Lisää se asetusten Profiles-välilehdellä.")
            return
        }
        self.config = config

        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        let microphoneAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

        let start = Date()
        do {
            let folder = try MeetingStorage.createSessionFolder(for: start)
            writer = try TranscriptWriter(folderURL: folder, meetingStart: start)
            folderURL = folder
        } catch {
            failStart("Palaverikansiota ei voitu luoda: \(error.localizedDescription)")
            return
        }

        segments = []
        heldMicSegments = []
        queue = []
        pendingCount = 0
        capturesFlushed = false
        startedAt = start
        endedAt = nil
        lastSegmentAt = nil

        let pendingURL = writer?.pendingURL ?? MeetingStorage.rootURL
        systemChunker = makeChunker(speaker: .others, pendingURL: pendingURL)
        micChunker = makeChunker(speaker: .me, pendingURL: pendingURL)

        wantsSystemAudio = true
        startSystemAudio()
        if microphoneAllowed {
            wantsMicrophone = true
            startMicrophone()
        } else {
            statusMessage = "Mikrofonilupa puuttuu, joten vain muiden puhe tallentuu."
        }

        guard isSystemAudioActive || isMicrophoneActive else {
            let reason = statusMessage ?? "Äänen kaappaus ei käynnistynyt."
            if let folderURL {
                try? FileManager.default.removeItem(at: folderURL)
            }
            folderURL = nil
            failStart(reason)
            return
        }

        state = .running
        logger.info("Meeting started with profile \(config.profileName) on port \(config.port)")
        startMeterTimer()
        Task { await processQueue() }

        if (try? await whisperClient.checkServerAvailability(port: config.port)) != true {
            serverWarningShown = true
            statusMessage = "whisper-server ei vastaa portissa \(config.port). Tallennus jatkuu, ja pätkät odottavat jonossa."
        }
    }

    /// Stop capturing and transcribe the remaining chunks
    func stop() {
        guard state == .running else { return }
        state = .stopping
        endedAt = Date()
        statusMessage = "Litteroidaan viimeiset pätkät…"

        stopCaptures()
        micChunker?.flush()
        systemChunker?.flush()

        // Chunk writes are queued on ioQueue and then delivered on the main queue;
        // this marker runs after all of them.
        ioQueue.async {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    MeetingSession.shared.capturesFlushed = true
                }
            }
        }
    }

    private func failStart(_ message: String) {
        logger.error("Meeting start failed: \(message)")
        errorMessage = message
        stopCaptures()
        writer = nil
        micChunker = nil
        systemChunker = nil
        state = .idle
    }

    // MARK: - Captures

    private func makeChunker(speaker: MeetingSpeaker, pendingURL: URL) -> SpeechChunker {
        let ioQueue = self.ioQueue
        return SpeechChunker(speaker: speaker) { chunk in
            ioQueue.async {
                let fileURL = pendingURL.appendingPathComponent(
                    PendingChunkName.fileName(speaker: chunk.speaker, startTime: chunk.startTime, endTime: chunk.endTime)
                )
                let writeError: String?
                do {
                    let wav = WAVEncoder.encode(samples: chunk.samples, sampleRate: Int(MonoResampler.outputSampleRate))
                    try wav.write(to: fileURL, options: .atomic)
                    writeError = nil
                } catch {
                    writeError = error.localizedDescription
                }
                let pending = PendingChunk(
                    speaker: chunk.speaker,
                    startTime: chunk.startTime,
                    endTime: chunk.endTime,
                    fileURL: fileURL
                )
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        MeetingSession.shared.chunkWritten(pending, writeError: writeError)
                    }
                }
            }
        }
    }

    private func startSystemAudio() {
        lastSystemAudioStart = Date()
        systemAudio?.stop()
        systemAudio = nil
        if let startedAt {
            systemChunker?.resync(to: Date().timeIntervalSince(startedAt))
        }

        let capture = SystemAudioCapture()
        let chunker = systemChunker
        do {
            try capture.start(
                onSamples: { samples in chunker?.append(samples) },
                onDeviceChange: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        MainActor.assumeIsolated {
                            MeetingSession.shared.restartSystemAudio(reason: "output device changed")
                        }
                    }
                }
            )
            systemAudio = capture
            isSystemAudioActive = true
            if statusMessage?.hasPrefix("Tietokoneen äänen") == true {
                statusMessage = nil
            }
        } catch {
            isSystemAudioActive = false
            statusMessage = "Tietokoneen äänen kaappaus ei käynnistynyt: \(error.localizedDescription)"
            logger.error("System audio capture failed: \(error.localizedDescription)")
        }
    }

    private func startMicrophone() {
        lastMicrophoneStart = Date()
        microphone?.stop()
        microphone = nil
        if let startedAt {
            micChunker?.resync(to: Date().timeIntervalSince(startedAt))
        }

        let capture = MicrophoneCapture()
        let chunker = micChunker
        do {
            try capture.start(
                onSamples: { samples in chunker?.append(samples) },
                onConfigurationChange: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        MainActor.assumeIsolated {
                            MeetingSession.shared.restartMicrophone(reason: "input configuration changed")
                        }
                    }
                }
            )
            microphone = capture
            isMicrophoneActive = true
            if statusMessage?.hasPrefix("Mikrofonin") == true {
                statusMessage = nil
            }
        } catch {
            isMicrophoneActive = false
            statusMessage = "Mikrofonin kaappaus ei käynnistynyt: \(error.localizedDescription)"
            logger.error("Microphone capture failed: \(error.localizedDescription)")
        }
    }

    private func restartSystemAudio(reason: String) {
        guard state == .running, wantsSystemAudio else { return }
        logger.info("Restarting system audio capture: \(reason)")
        startSystemAudio()
    }

    private func restartMicrophone(reason: String) {
        guard state == .running, wantsMicrophone else { return }
        logger.info("Restarting microphone capture: \(reason)")
        startMicrophone()
    }

    private func stopCaptures() {
        wantsSystemAudio = false
        wantsMicrophone = false
        systemAudio?.stop()
        microphone?.stop()
        systemAudio = nil
        microphone = nil
        isSystemAudioActive = false
        isMicrophoneActive = false
    }

    // MARK: - Meters and Stall Detection

    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated {
                MeetingSession.shared.tick()
            }
        }
    }

    private func tick() {
        micLevel = microphone?.level ?? 0
        systemLevel = systemAudio?.level ?? 0
        guard state == .running else { return }

        let now = Date()
        systemAudioStalled = wantsSystemAudio && (systemAudio?.secondsSinceLastSamples ?? .infinity) > stallThreshold
        microphoneStalled = wantsMicrophone && (microphone?.secondsSinceLastSamples ?? .infinity) > stallThreshold

        if systemAudioStalled && now.timeIntervalSince(lastSystemAudioStart) > restartInterval {
            restartSystemAudio(reason: "no audio for \(stallThreshold) s")
        }
        if microphoneStalled && now.timeIntervalSince(lastMicrophoneStart) > restartInterval {
            restartMicrophone(reason: "no audio for \(stallThreshold) s")
        }

        releaseHeldMicSegments(final: false)
    }

    // MARK: - Transcription Queue

    private func chunker(for speaker: MeetingSpeaker) -> SpeechChunker? {
        speaker == .me ? micChunker : systemChunker
    }

    private func chunkWritten(_ chunk: PendingChunk, writeError: String?) {
        chunker(for: chunk.speaker)?.acknowledgeDelivery(startTime: chunk.startTime)
        if let writeError {
            errorMessage = "Äänipätkän tallennus epäonnistui: \(writeError)"
            logger.error("Chunk write failed: \(writeError)")
            return
        }
        let index = queue.firstIndex { $0.startTime > chunk.startTime } ?? queue.endIndex
        queue.insert(chunk, at: index)
        pendingCount = queue.count
    }

    private func processQueue() async {
        var failures = 0
        while true {
            releaseHeldMicSegments(final: false)

            guard let chunk = queue.first, let config else {
                if state == .stopping && capturesFlushed { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
                continue
            }

            do {
                let audio = try Data(contentsOf: chunk.fileURL)
                let text = try await whisperClient.transcribe(
                    audioData: audio,
                    model: config.model,
                    port: config.port,
                    language: config.language,
                    translate: false
                )
                removeFromQueue(chunk, deleteFile: true)
                failures = 0
                if serverWarningShown {
                    serverWarningShown = false
                    statusMessage = nil
                }
                handleTranscription(text, for: chunk)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                logger.error("Pending chunk disappeared: \(chunk.fileURL.lastPathComponent)")
                removeFromQueue(chunk, deleteFile: false)
            } catch {
                failures += 1
                serverWarningShown = true
                statusMessage = "whisper-server ei vastaa (\(error.localizedDescription)). Jonossa \(queue.count) pätkää."
                logger.error("Transcription failed (\(failures)): \(error.localizedDescription)")
                if state == .stopping && failures >= 3 { break }
                let delay = min(pow(2, Double(failures)), 15)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        finishStopping()
    }

    private func removeFromQueue(_ chunk: PendingChunk, deleteFile: Bool) {
        queue.removeAll { $0.fileURL == chunk.fileURL }
        pendingCount = queue.count
        if deleteFile {
            try? FileManager.default.removeItem(at: chunk.fileURL)
        }
    }

    private func handleTranscription(_ text: String, for chunk: PendingChunk) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let segment = TranscriptSegment(
            speaker: chunk.speaker,
            startTime: chunk.startTime,
            endTime: chunk.endTime,
            text: trimmed
        )
        if segment.speaker == .me && systemChunker != nil {
            heldMicSegments.append(segment)
            releaseHeldMicSegments(final: false)
        } else {
            accept(segment)
        }
    }

    private func accept(_ segment: TranscriptSegment) {
        let index = segments.firstIndex { $0.startTime > segment.startTime } ?? segments.endIndex
        segments.insert(segment, at: index)
        lastSegmentAt = Date()
        do {
            try writer?.append(segment)
        } catch {
            errorMessage = "Transkriptin kirjoitus epäonnistui: \(error.localizedDescription)"
            logger.error("Transcript append failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Echo Handling

    /// Seconds of system audio that has been fully transcribed
    private var systemTranscribedUntil: TimeInterval {
        guard let systemChunker else { return .infinity }
        if state == .running && !isSystemAudioActive { return .infinity }
        let pendingSystemStart = queue.first { $0.speaker == .others }?.startTime ?? .infinity
        return min(systemChunker.coveredUntil, pendingSystemStart)
    }

    private func releaseHeldMicSegments(final: Bool) {
        guard !heldMicSegments.isEmpty else { return }
        let transcribedUntil = final ? TimeInterval.infinity : systemTranscribedUntil
        let systemSegments = segments.filter { $0.speaker == .others }

        var stillHeld: [TranscriptSegment] = []
        for segment in heldMicSegments {
            guard segment.endTime + EchoFilter.defaultTolerance <= transcribedUntil else {
                stillHeld.append(segment)
                continue
            }
            if EchoFilter.isEcho(segment, of: systemSegments) {
                logger.info("Dropped microphone echo at \(segment.startTime) s")
            } else {
                accept(segment)
            }
        }
        heldMicSegments = stillHeld
    }

    // MARK: - Finish

    private func finishStopping() {
        releaseHeldMicSegments(final: true)
        meterTimer?.invalidate()
        meterTimer = nil
        micLevel = 0
        systemLevel = 0
        microphoneStalled = false
        systemAudioStalled = false

        if let writer {
            if queue.isEmpty {
                do {
                    try writer.rewrite(with: segments)
                } catch {
                    errorMessage = "Transkriptin viimeistely epäonnistui: \(error.localizedDescription)"
                }
                writer.removePendingFolderIfEmpty()
                statusMessage = "Transkripti tallennettu (\(segments.count) riviä)."
            } else {
                statusMessage = "\(queue.count) pätkää jäi litteroimatta. Ne litteroidaan seuraavalla käynnistyksellä, kun whisper-server vastaa."
            }
        }

        logger.info("Meeting finished with \(self.segments.count) segments, \(self.queue.count) pending")
        writer = nil
        micChunker = nil
        systemChunker = nil
        queue = []
        pendingCount = 0
        heldMicSegments = []
        state = .idle
    }

    // MARK: - Recovery

    /// Transcribe chunks left in session folders by an interrupted meeting
    ///
    /// Recovered lines are appended to the end of the original transcript.
    /// If whisper-server does not respond, the chunks stay for the next launch.
    func recoverPendingChunks() {
        guard state == .idle, !isRecovering else { return }
        let folders = MeetingStorage.foldersWithPendingChunks()
        guard !folders.isEmpty else { return }
        guard let config = WhisperServerConfig.resolve() else {
            logger.error("Pending meeting chunks found but no Local Whisper profile")
            return
        }

        isRecovering = true
        Task {
            defer { isRecovering = false }
            for folder in folders {
                guard let start = MeetingStorage.sessionStart(in: folder),
                      let writer = try? TranscriptWriter(folderURL: folder, meetingStart: start) else { continue }

                for file in writer.pendingChunkFiles() {
                    guard let info = PendingChunkName.parse(file.lastPathComponent) else { continue }
                    do {
                        let audio = try Data(contentsOf: file)
                        let text = try await whisperClient.transcribe(
                            audioData: audio,
                            model: config.model,
                            port: config.port,
                            language: config.language,
                            translate: false
                        )
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            try writer.append(TranscriptSegment(
                                speaker: info.speaker,
                                startTime: info.startTime,
                                endTime: info.endTime,
                                text: trimmed
                            ))
                        }
                        try? FileManager.default.removeItem(at: file)
                    } catch {
                        logger.error("Recovery paused: \(error.localizedDescription)")
                        return
                    }
                }
                writer.removePendingFolderIfEmpty()
                logger.info("Recovered pending chunks in \(folder.lastPathComponent)")
            }
        }
    }
}
