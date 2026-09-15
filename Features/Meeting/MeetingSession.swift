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

    /// Choose the Local Whisper profile for meetings
    ///
    /// Order: the profile selected in Settings, the active profile if it uses
    /// Local Whisper, then the first Local Whisper profile.
    static func resolve(preferredProfileID: UUID? = nil, profileManager: ProfileManager = ProfileManager()) -> WhisperServerConfig? {
        let localProfiles = ((try? profileManager.getAllProfiles()) ?? []).filter { $0.transcriptionEngine == .localWhisper }
        let preferred = preferredProfileID.flatMap { id in localProfiles.first { $0.id == id } }
        let active = (try? profileManager.getActiveProfile()).flatMap { active in localProfiles.first { $0.id == active.id } }
        guard let profile = preferred ?? active ?? localProfiles.first else {
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

/// Live transcription of a Teams, Google Meet or Slack huddle meeting
///
/// Captures the microphone ("Me") and system audio ("Others") separately,
/// cuts both into speech chunks, transcribes them one at a time with the local
/// whisper.cpp server and appends each result to `transcript.md`.
///
/// **Reliability:** every chunk is written to the session's `.pending` folder
/// before transcription and deleted only after its text is in the transcript.
/// Chunks left behind by a crash or an unavailable server are transcribed by
/// `recoverPendingChunks()` on the next launch. Captures that stop delivering
/// audio are restarted automatically.
///
/// **Quality:** whisper segments with low confidence (text invented for silence
/// or noise) are dropped. Fragmented segments are joined into speaker turns for
/// the window and for the final transcript; the live file keeps the raw chunks.
///
/// **Echo:** when the meeting plays through speakers the microphone hears the
/// other participants too. Microphone segments are held until the overlapping
/// system audio has been transcribed and dropped if they repeat it.
///
/// Dictation is disabled while a session is active (see `HotkeyManager`).
@MainActor
final class MeetingSession: ObservableObject {
    static let shared = MeetingSession()

    private static let vocabularyDefaultsKey = "meetingVocabulary"

    // MARK: - Published State

    @Published private(set) var state: MeetingState = .idle
    /// Accepted raw segments in chronological order
    @Published private(set) var segments: [TranscriptSegment] = []
    /// Segments joined into readable speaker turns
    @Published private(set) var turns: [TranscriptTurn] = []
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
    /// Whether `statusMessage` is a warning rather than information
    @Published private(set) var statusIsWarning = false
    @Published private(set) var errorMessage: String?

    /// Names and terms written to the transcript header for later processing
    ///
    /// Remembered between meetings. Not sent to whisper: prompting the model
    /// did not fix term spelling in tests and introduced new errors.
    @Published var vocabulary: String {
        didSet {
            UserDefaults.standard.set(vocabulary, forKey: Self.vocabularyDefaultsKey)
            writer?.vocabulary = vocabulary
        }
    }

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

    private init() {
        vocabulary = UserDefaults.standard.string(forKey: Self.vocabularyDefaultsKey) ?? ""
    }

    // MARK: - Start and Stop

    /// Start a meeting session
    ///
    /// Requires a Local Whisper profile. Recording starts even if whisper-server
    /// is not responding yet; chunks wait in the queue until it answers.
    func start() async {
        guard state == .idle else { return }
        state = .starting
        errorMessage = nil
        setStatus(nil)

        guard let config = WhisperServerConfig.resolve(preferredProfileID: AppState.shared.settings.meetingProfileId) else {
            failStart("Meeting transcription needs a Local Whisper profile. Add one in Settings → Profiles.")
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
            writer = try TranscriptWriter(folderURL: folder, meetingStart: start, vocabulary: vocabulary)
            folderURL = folder
        } catch {
            failStart("Could not create the meeting folder: \(error.localizedDescription)")
            return
        }

        segments = []
        turns = []
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
            setStatus("Microphone access is missing, so only other participants are recorded.", warning: true)
        }

        guard isSystemAudioActive || isMicrophoneActive else {
            let reason = statusMessage ?? "Audio capture did not start."
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
            setStatus("whisper-server is not responding on port \(config.port). Recording continues and audio waits in the queue.", warning: true)
        }
    }

    /// Stop capturing and transcribe the remaining chunks
    func stop() {
        guard state == .running else { return }
        state = .stopping
        endedAt = Date()
        setStatus("Transcribing the remaining audio…")

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
        setStatus(nil)
        stopCaptures()
        writer = nil
        micChunker = nil
        systemChunker = nil
        state = .idle
    }

    private func setStatus(_ message: String?, warning: Bool = false) {
        statusMessage = message
        statusIsWarning = warning
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
            if statusMessage?.hasPrefix("System audio capture") == true {
                setStatus(nil)
            }
        } catch {
            isSystemAudioActive = false
            setStatus("System audio capture did not start: \(error.localizedDescription)", warning: true)
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
            if statusMessage?.hasPrefix("Microphone capture") == true {
                setStatus(nil)
            }
        } catch {
            isMicrophoneActive = false
            setStatus("Microphone capture did not start: \(error.localizedDescription)", warning: true)
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
            errorMessage = "Saving an audio chunk failed: \(writeError)"
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
                let text = try await transcribe(chunk.fileURL, config: config)
                removeFromQueue(chunk, deleteFile: true)
                failures = 0
                if serverWarningShown {
                    serverWarningShown = false
                    setStatus(nil)
                }
                handleTranscription(text, for: chunk)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                logger.error("Pending chunk disappeared: \(chunk.fileURL.lastPathComponent)")
                removeFromQueue(chunk, deleteFile: false)
            } catch {
                failures += 1
                serverWarningShown = true
                setStatus("whisper-server is not responding (\(error.localizedDescription)). \(queue.count) chunks in the queue.", warning: true)
                logger.error("Transcription failed (\(failures)): \(error.localizedDescription)")
                if state == .stopping && failures >= 3 { break }
                let delay = min(pow(2, Double(failures)), 15)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        finishStopping()
    }

    /// Transcribe one chunk file, keeping only confident segments
    private func transcribe(_ fileURL: URL, config: WhisperServerConfig) async throws -> String {
        let audio = try Data(contentsOf: fileURL)
        let whisperSegments = try await whisperClient.transcribeSegments(
            audioData: audio,
            model: config.model,
            port: config.port,
            language: config.language,
            translate: false
        )
        let dropped = whisperSegments.count - WhisperSegmentFilter.acceptedSegments(whisperSegments).count
        if dropped > 0 {
            logger.info("Dropped \(dropped) low-confidence segment(s) in \(fileURL.lastPathComponent)")
        }
        return WhisperSegmentFilter.acceptedText(from: whisperSegments)
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
        turns = TranscriptMerger.merge(segments)
        lastSegmentAt = Date()
        do {
            try writer?.append(segment)
        } catch {
            errorMessage = "Writing the transcript failed: \(error.localizedDescription)"
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
            if EchoFilter.shouldDrop(segment, of: systemSegments) {
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
                    try writer.rewrite(with: turns)
                } catch {
                    errorMessage = "Finalizing the transcript failed: \(error.localizedDescription)"
                }
                writer.removePendingFolderIfEmpty()
                setStatus("Transcript saved (\(turns.count) turns).")
            } else {
                setStatus("\(queue.count) chunks were not transcribed. They will be transcribed on the next launch when whisper-server responds.", warning: true)
            }
        }

        logger.info("Meeting finished with \(self.segments.count) segments, \(self.turns.count) turns, \(self.queue.count) pending")
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
        guard let config = WhisperServerConfig.resolve(preferredProfileID: AppState.shared.settings.meetingProfileId) else {
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
                        let text = try await transcribe(file, config: config)
                        if !text.isEmpty {
                            try writer.append(TranscriptSegment(
                                speaker: info.speaker,
                                startTime: info.startTime,
                                endTime: info.endTime,
                                text: text
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
