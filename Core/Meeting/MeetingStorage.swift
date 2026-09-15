//
//  MeetingStorage.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: session folders, pending chunks and transcript file
//

import Foundation

/// A speech chunk written to disk and waiting for transcription
nonisolated struct PendingChunk: Equatable {
    let speaker: MeetingSpeaker
    let startTime: TimeInterval
    let endTime: TimeInterval
    let fileURL: URL
}

/// Locations and folder layout for meeting transcripts
///
/// ```
/// ~/Documents/Palaverit/2026-09-15_1400/
///   transcript.md     transcript, appended after every segment
///   session.json      meeting start time (used for crash recovery)
///   .pending/         WAV chunks not yet transcribed
/// ```
nonisolated enum MeetingStorage {
    static let transcriptFileName = "transcript.md"
    static let sessionFileName = "session.json"
    static let pendingFolderName = ".pending"

    /// `~/Documents/Palaverit` in the real home folder (the sandbox container home is not used)
    static var rootURL: URL {
        realHomeDirectory().appendingPathComponent("Documents/Palaverit", isDirectory: true)
    }

    /// Create a new session folder named after the meeting start time
    ///
    /// Adds a `-2`, `-3`… suffix if a folder for the same minute already exists.
    static func createSessionFolder(for start: Date, in root: URL = rootURL, timeZone: TimeZone = .current) throws -> URL {
        let baseName = folderName(for: start, timeZone: timeZone)
        var folder = root.appendingPathComponent(baseName, isDirectory: true)
        var suffix = 2
        while FileManager.default.fileExists(atPath: folder.path) {
            folder = root.appendingPathComponent("\(baseName)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let info = ["startedAt": ISO8601DateFormatter().string(from: start)]
        let data = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted])
        try data.write(to: folder.appendingPathComponent(sessionFileName))
        return folder
    }

    /// Folder name such as `2026-09-15_1400`
    static func folderName(for start: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: start)
    }

    /// Meeting start time stored in a session folder
    static func sessionStart(in folder: URL) -> Date? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(sessionFileName)),
              let info = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let startedAt = info["startedAt"] else {
            return nil
        }
        return ISO8601DateFormatter().date(from: startedAt)
    }

    /// Session folders that still contain untranscribed chunks, oldest first
    static func foldersWithPendingChunks(in root: URL = rootURL) -> [URL] {
        let fileManager = FileManager.default
        guard let folders = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return folders
            .filter { folder in
                let pendingPath = folder.appendingPathComponent(pendingFolderName, isDirectory: true).path
                let names = (try? fileManager.contentsOfDirectory(atPath: pendingPath)) ?? []
                return names.contains { PendingChunkName.parse($0) != nil }
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func realHomeDirectory() -> URL {
        if let passwd = getpwuid(getuid()), let directory = passwd.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}

/// File names for pending chunks: `<start ms>_<end ms>_<speaker>.wav`
///
/// Zero-padded times make alphabetical order chronological.
nonisolated enum PendingChunkName {
    static func fileName(speaker: MeetingSpeaker, startTime: TimeInterval, endTime: TimeInterval) -> String {
        let start = String(format: "%010d", Int((startTime * 1000).rounded()))
        let end = String(format: "%010d", Int((endTime * 1000).rounded()))
        return "\(start)_\(end)_\(speaker.fileTag).wav"
    }

    static func parse(_ fileName: String) -> (speaker: MeetingSpeaker, startTime: TimeInterval, endTime: TimeInterval)? {
        guard fileName.hasSuffix(".wav") else { return nil }
        let parts = fileName.dropLast(4).split(separator: "_")
        guard parts.count == 3,
              let start = Int(parts[0]),
              let end = Int(parts[1]),
              let speaker = MeetingSpeaker(fileTag: String(parts[2])) else {
            return nil
        }
        return (speaker, Double(start) / 1000, Double(end) / 1000)
    }
}

/// Markdown formatting of the meeting transcript
nonisolated enum TranscriptFormatter {
    /// `# Palaveri 15.9.2026 klo 14.00`
    static func header(meetingStart: Date, timeZone: TimeZone = .current) -> String {
        "# Palaveri \(format(meetingStart, pattern: "d.M.yyyy 'klo' HH.mm", timeZone: timeZone))\n\n"
    }

    /// `[14:02:15] Minä: text`, followed by a blank line
    static func line(for segment: TranscriptSegment, meetingStart: Date, timeZone: TimeZone = .current) -> String {
        let time = format(meetingStart.addingTimeInterval(segment.startTime), pattern: "HH:mm:ss", timeZone: timeZone)
        return "[\(time)] \(segment.speaker.rawValue): \(segment.text)\n\n"
    }

    /// Complete transcript with segments in chronological order
    static func document(segments: [TranscriptSegment], meetingStart: Date, timeZone: TimeZone = .current) -> String {
        header(meetingStart: meetingStart, timeZone: timeZone)
            + segments
                .sorted { $0.startTime < $1.startTime }
                .map { line(for: $0, meetingStart: meetingStart, timeZone: timeZone) }
                .joined()
    }

    private static func format(_ date: Date, pattern: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fi_FI")
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

/// Writes one meeting's transcript file and owns its pending chunk folder
///
/// Every segment is appended and flushed to disk immediately, so a crash
/// loses at most the chunks still in `.pending`, which recovery transcribes later.
nonisolated final class TranscriptWriter {
    let folderURL: URL
    let transcriptURL: URL
    let pendingURL: URL
    let meetingStart: Date

    init(folderURL: URL, meetingStart: Date) throws {
        self.folderURL = folderURL
        self.meetingStart = meetingStart
        transcriptURL = folderURL.appendingPathComponent(MeetingStorage.transcriptFileName)
        pendingURL = folderURL.appendingPathComponent(MeetingStorage.pendingFolderName, isDirectory: true)

        try FileManager.default.createDirectory(at: pendingURL, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: transcriptURL.path) {
            try Data(TranscriptFormatter.header(meetingStart: meetingStart).utf8).write(to: transcriptURL)
        }
    }

    /// Append one segment and flush it to disk
    func append(_ segment: TranscriptSegment) throws {
        let handle = try FileHandle(forWritingTo: transcriptURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(TranscriptFormatter.line(for: segment, meetingStart: meetingStart).utf8))
        try handle.synchronize()
    }

    /// Replace the file with all segments in chronological order
    ///
    /// Live appends follow transcription order, which can differ slightly between
    /// the two sources; the finished meeting is rewritten sorted.
    func rewrite(with segments: [TranscriptSegment]) throws {
        let document = TranscriptFormatter.document(segments: segments, meetingStart: meetingStart)
        try Data(document.utf8).write(to: transcriptURL, options: .atomic)
    }

    /// Pending chunk files in chronological order
    func pendingChunkFiles() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: pendingURL.path)) ?? []
        return names
            .filter { PendingChunkName.parse($0) != nil }
            .sorted()
            .map { pendingURL.appendingPathComponent($0) }
    }

    func removePendingFolderIfEmpty() {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: pendingURL.path)) ?? []
        if names.isEmpty {
            try? FileManager.default.removeItem(at: pendingURL)
        }
    }
}
