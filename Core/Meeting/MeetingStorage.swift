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
/// ~/Documents/Meetings/2026-09-15_1400 Client Oy – steering group/
///   transcript.md     transcript, appended after every segment
///   session.json      meeting start time (used for crash recovery)
///   .pending/         WAV chunks not yet transcribed
/// ```
///
/// The title in the folder name lets a memo project pick the transcripts of
/// one client without separate sorting.
nonisolated enum MeetingStorage {
    static let transcriptFileName = "transcript.md"
    static let sessionFileName = "session.json"
    static let pendingFolderName = ".pending"

    /// Longest title kept in a folder name
    static let maximumFolderTitleLength = 80

    /// `~/Documents/Meetings` in the real home folder (the sandbox container home is not used)
    ///
    /// The app sandbox grants access through a home-relative exception in the entitlements.
    static var rootURL: URL {
        realHomeDirectory().appendingPathComponent("Documents/Meetings", isDirectory: true)
    }

    /// Create a new session folder named after the meeting start time and title
    ///
    /// Adds a `-2`, `-3`… suffix if a folder with the same name already exists.
    static func createSessionFolder(
        for start: Date,
        title: String = "",
        in root: URL = rootURL,
        timeZone: TimeZone = .current
    ) throws -> URL {
        let folder = uniqueFolderURL(named: folderName(for: start, title: title, timeZone: timeZone), in: root)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let info = ["startedAt": ISO8601DateFormatter().string(from: start)]
        let data = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted])
        try data.write(to: folder.appendingPathComponent(sessionFileName))
        return folder
    }

    /// Rename a session folder when the title was changed during the meeting
    ///
    /// - Returns: The folder's URL after renaming (unchanged if the name already matches)
    static func renameSessionFolder(_ folder: URL, start: Date, title: String, timeZone: TimeZone = .current) throws -> URL {
        let desiredName = folderName(for: start, title: title, timeZone: timeZone)
        let currentName = folder.lastPathComponent
        let hasCollisionSuffix = currentName.hasPrefix(desiredName + "-")
            && Int(currentName.dropFirst(desiredName.count + 1)) != nil
        guard currentName != desiredName && !hasCollisionSuffix else { return folder }

        let target = uniqueFolderURL(named: desiredName, in: folder.deletingLastPathComponent())
        try FileManager.default.moveItem(at: folder, to: target)
        return target
    }

    /// Folder name such as `2026-09-15_1400` or `2026-09-15_1400 Client Oy – steering group`
    static func folderName(for start: Date, title: String = "", timeZone: TimeZone = .current) -> String {
        let stamp = TranscriptFormatter.format(start, pattern: "yyyy-MM-dd_HHmm", timeZone: timeZone)
        let safeTitle = folderSafeTitle(title)
        return safeTitle.isEmpty ? stamp : "\(stamp) \(safeTitle)"
    }

    /// Title usable in a folder name: one line, no path separators, not hidden, at most 80 characters
    static func folderSafeTitle(_ title: String) -> String {
        let singleLine = TranscriptFormatter.singleLineTitle(title)
        let withoutSeparators = singleLine.replacingOccurrences(of: "[/:\\\\]", with: "-", options: .regularExpression)
        let visible = String(withoutSeparators.drop { $0 == "." || $0 == " " })
        return String(visible.prefix(maximumFolderTitleLength)).trimmingCharacters(in: .whitespaces)
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

    private static func uniqueFolderURL(named name: String, in root: URL) -> URL {
        var folder = root.appendingPathComponent(name, isDirectory: true)
        var suffix = 2
        while FileManager.default.fileExists(atPath: folder.path) {
            folder = root.appendingPathComponent("\(name)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        return folder
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
///
/// The transcript is raw material for a separate memo project: words are kept
/// as transcribed, and names, terms and proofreading are handled there.
nonisolated enum TranscriptFormatter {
    /// `# Meeting 2026-09-15 14:00` or `# Meeting 2026-09-15 14:00 – Client Oy – steering group`
    static func header(meetingStart: Date, title: String = "", timeZone: TimeZone = .current) -> String {
        let stamp = format(meetingStart, pattern: "yyyy-MM-dd HH:mm", timeZone: timeZone)
        let cleanTitle = singleLineTitle(title)
        return cleanTitle.isEmpty ? "# Meeting \(stamp)\n\n" : "# Meeting \(stamp) – \(cleanTitle)\n\n"
    }

    /// `[14:02:15] Me: text`, followed by a blank line
    static func line(
        speaker: MeetingSpeaker,
        startTime: TimeInterval,
        text: String,
        meetingStart: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let time = format(meetingStart.addingTimeInterval(startTime), pattern: "HH:mm:ss", timeZone: timeZone)
        return "[\(time)] \(speaker.rawValue): \(text)\n\n"
    }

    static func line(for segment: TranscriptSegment, meetingStart: Date, timeZone: TimeZone = .current) -> String {
        line(speaker: segment.speaker, startTime: segment.startTime, text: segment.text, meetingStart: meetingStart, timeZone: timeZone)
    }

    /// Complete transcript with speaker turns in chronological order
    static func document(
        turns: [TranscriptTurn],
        meetingStart: Date,
        title: String = "",
        timeZone: TimeZone = .current
    ) -> String {
        header(meetingStart: meetingStart, title: title, timeZone: timeZone)
            + turns
                .sorted { $0.startTime < $1.startTime }
                .map { line(speaker: $0.speaker, startTime: $0.startTime, text: $0.text, meetingStart: meetingStart, timeZone: timeZone) }
                .joined()
    }

    /// Title on one line with single spaces
    static func singleLineTitle(_ title: String) -> String {
        title.components(separatedBy: .newlines)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Format a date with a fixed pattern independent of the user's locale
    static func format(_ date: Date, pattern: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
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
    /// Meeting title written to the transcript heading
    var title: String

    init(folderURL: URL, meetingStart: Date, title: String = "") throws {
        self.folderURL = folderURL
        self.meetingStart = meetingStart
        self.title = title
        transcriptURL = folderURL.appendingPathComponent(MeetingStorage.transcriptFileName)
        pendingURL = folderURL.appendingPathComponent(MeetingStorage.pendingFolderName, isDirectory: true)

        try FileManager.default.createDirectory(at: pendingURL, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: transcriptURL.path) {
            let header = TranscriptFormatter.header(meetingStart: meetingStart, title: title)
            try Data(header.utf8).write(to: transcriptURL)
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

    /// Replace the file with merged speaker turns in chronological order
    ///
    /// Live appends are raw chunks in transcription order; the finished meeting
    /// is rewritten as readable turns with the current title.
    func rewrite(with turns: [TranscriptTurn]) throws {
        let document = TranscriptFormatter.document(turns: turns, meetingStart: meetingStart, title: title)
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
