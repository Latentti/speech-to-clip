//
//  MeetingStorageTests.swift
//  speech-to-clipTests
//
//  Created on 2026-09-15.
//  Meeting transcription: files, naming and transcript format
//

import XCTest
@testable import speech_to_clip

/// Tests for MeetingStorage, PendingChunkName, TranscriptFormatter, TranscriptWriter and WAVEncoder
final class MeetingStorageTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetingStorageTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    // MARK: - Pending Chunk Names

    func testPendingChunkNameRoundTrip() throws {
        let name = PendingChunkName.fileName(speaker: .me, startTime: 12.345, endTime: 19.87)

        XCTAssertEqual(name, "0000012345_0000019870_me.wav")
        let parsed = try XCTUnwrap(PendingChunkName.parse(name))
        XCTAssertEqual(parsed.speaker, .me)
        XCTAssertEqual(parsed.startTime, 12.345, accuracy: 0.0005)
        XCTAssertEqual(parsed.endTime, 19.87, accuracy: 0.0005)
    }

    func testPendingChunkNamesSortChronologically() {
        let later = PendingChunkName.fileName(speaker: .me, startTime: 100.5, endTime: 110)
        let earlier = PendingChunkName.fileName(speaker: .others, startTime: 9.5, endTime: 20)

        XCTAssertEqual([later, earlier].sorted(), [earlier, later])
    }

    func testParseRejectsUnrelatedFiles() {
        XCTAssertNil(PendingChunkName.parse(".DS_Store"))
        XCTAssertNil(PendingChunkName.parse("0000000001_0000000002_someone.wav"))
        XCTAssertNil(PendingChunkName.parse("recording.wav"))
    }

    // MARK: - Transcript Format

    func testTranscriptLineUsesClockTimeAndSpeaker() {
        let start = Date(timeIntervalSince1970: 1_789_470_000) // 2026-09-15 11:00:00 UTC
        let segment = TranscriptSegment(speaker: .others, startTime: 135, endTime: 140, text: "Asiakas toivoo versiota lokakuussa.")

        let line = TranscriptFormatter.line(for: segment, meetingStart: start, timeZone: utc)

        XCTAssertEqual(line, "[11:02:15] Muut: Asiakas toivoo versiota lokakuussa.\n\n")
    }

    func testDocumentHasHeaderAndChronologicalLines() {
        let start = Date(timeIntervalSince1970: 1_789_470_000)
        let segments = [
            TranscriptSegment(speaker: .me, startTime: 20, endTime: 25, text: "Toinen."),
            TranscriptSegment(speaker: .others, startTime: 5, endTime: 10, text: "Ensimmäinen."),
        ]

        let document = TranscriptFormatter.document(segments: segments, meetingStart: start, timeZone: utc)

        XCTAssertEqual(
            document,
            "# Palaveri 15.9.2026 klo 11.00\n\n[11:00:05] Muut: Ensimmäinen.\n\n[11:00:20] Minä: Toinen.\n\n"
        )
    }

    // MARK: - Session Folders and Writer

    func testSessionFolderWriterAndPendingDetection() throws {
        let start = Date(timeIntervalSince1970: 1_789_470_000)

        let folder = try MeetingStorage.createSessionFolder(for: start, in: temporaryRoot, timeZone: utc)
        XCTAssertEqual(folder.lastPathComponent, "2026-09-15_1100")
        XCTAssertEqual(MeetingStorage.sessionStart(in: folder)?.timeIntervalSince1970 ?? 0, start.timeIntervalSince1970, accuracy: 1)

        let writer = try TranscriptWriter(folderURL: folder, meetingStart: start)
        try writer.append(TranscriptSegment(speaker: .me, startTime: 1, endTime: 2, text: "Ensimmäinen rivi."))
        let contents = try String(contentsOf: writer.transcriptURL, encoding: .utf8)
        XCTAssertTrue(contents.hasPrefix("# Palaveri"))
        XCTAssertTrue(contents.contains("Minä: Ensimmäinen rivi."))

        XCTAssertTrue(MeetingStorage.foldersWithPendingChunks(in: temporaryRoot).isEmpty)
        try Data().write(to: writer.pendingURL.appendingPathComponent("0000001000_0000002000_me.wav"))
        // Compare names: the temporary directory is reported both as /var and /private/var
        XCTAssertEqual(MeetingStorage.foldersWithPendingChunks(in: temporaryRoot).map(\.lastPathComponent), [folder.lastPathComponent])
        XCTAssertEqual(writer.pendingChunkFiles().count, 1)

        let second = try MeetingStorage.createSessionFolder(for: start, in: temporaryRoot, timeZone: utc)
        XCTAssertEqual(second.lastPathComponent, "2026-09-15_1100-2")
    }

    func testRewriteSortsAndRemovesEmptyPendingFolder() throws {
        let start = Date(timeIntervalSince1970: 1_789_470_000)
        let folder = try MeetingStorage.createSessionFolder(for: start, in: temporaryRoot, timeZone: utc)
        let writer = try TranscriptWriter(folderURL: folder, meetingStart: start)

        let late = TranscriptSegment(speaker: .me, startTime: 30, endTime: 35, text: "Myöhempi.")
        let early = TranscriptSegment(speaker: .others, startTime: 10, endTime: 15, text: "Aiempi.")
        try writer.append(late)
        try writer.append(early)
        try writer.rewrite(with: [late, early])
        writer.removePendingFolderIfEmpty()

        let contents = try String(contentsOf: writer.transcriptURL, encoding: .utf8)
        let earlyRange = try XCTUnwrap(contents.range(of: "Aiempi."))
        let lateRange = try XCTUnwrap(contents.range(of: "Myöhempi."))
        XCTAssertLessThan(earlyRange.lowerBound, lateRange.lowerBound)
        XCTAssertFalse(FileManager.default.fileExists(atPath: writer.pendingURL.path))
    }

    // MARK: - WAV Encoding

    func testWAVEncoderWritesMono16BitHeaderAndSamples() {
        let data = WAVEncoder.encode(samples: [0, 0.5, -1], sampleRate: 16_000)

        XCTAssertEqual(data.count, 44 + 6)
        XCTAssertEqual(String(data: data.subdata(in: 0..<4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data.subdata(in: 8..<12), encoding: .ascii), "WAVE")
        XCTAssertEqual(readLittleEndian(UInt16.self, from: data, at: 22), 1)      // channels
        XCTAssertEqual(readLittleEndian(UInt32.self, from: data, at: 24), 16_000) // sample rate
        XCTAssertEqual(readLittleEndian(UInt16.self, from: data, at: 34), 16)     // bits per sample
        XCTAssertEqual(readLittleEndian(UInt32.self, from: data, at: 40), 6)      // data size
        XCTAssertEqual(readLittleEndian(Int16.self, from: data, at: 48), -Int16.max)
    }

    private func readLittleEndian<T: FixedWidthInteger>(_ type: T.Type, from data: Data, at offset: Int) -> T {
        let bytes = data.subdata(in: offset..<(offset + MemoryLayout<T>.size))
        return T(littleEndian: bytes.withUnsafeBytes { $0.loadUnaligned(as: T.self) })
    }
}
