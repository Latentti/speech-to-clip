//
//  SpeechChunkerTests.swift
//  speech-to-clipTests
//
//  Created on 2026-09-15.
//  Meeting transcription: speech chunking
//

import XCTest
@testable import speech_to_clip

/// Tests for SpeechChunker using synthetic tone and silence at 16 kHz
final class SpeechChunkerTests: XCTestCase {

    private let sampleRate = 16_000.0

    /// Collects emitted chunks from the chunker callback
    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [AudioChunk] = []

        func add(_ chunk: AudioChunk) {
            lock.lock()
            storage.append(chunk)
            lock.unlock()
        }

        var chunks: [AudioChunk] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    private func silence(_ seconds: Double) -> [Float] {
        Array(repeating: 0, count: Int(seconds * sampleRate))
    }

    private func tone(_ seconds: Double, amplitude: Float = 0.1) -> [Float] {
        let rate = Float(sampleRate)
        return (0..<Int(seconds * sampleRate)).map { amplitude * sin(2 * .pi * 220 * Float($0) / rate) }
    }

    /// Feed samples in 100 ms blocks like an audio callback
    private func feed(_ samples: [Float], to chunker: SpeechChunker) {
        for start in stride(from: 0, to: samples.count, by: 1_600) {
            chunker.append(Array(samples[start..<min(start + 1_600, samples.count)]))
        }
    }

    /// Two utterances separated by a pause become two chunks with pre-roll and trailing silence
    func testSplitsAtPausesAndSkipsSilence() {
        let collector = Collector()
        let chunker = SpeechChunker(speaker: .others) { collector.add($0) }

        feed(silence(1) + tone(2) + silence(1) + tone(2) + silence(1), to: chunker)
        chunker.flush()

        let chunks = collector.chunks
        XCTAssertEqual(chunks.count, 2)
        guard chunks.count == 2 else { return }
        XCTAssertEqual(chunks[0].startTime, 0.7, accuracy: 0.05)
        XCTAssertEqual(chunks[0].endTime, 3.3, accuracy: 0.1)
        XCTAssertEqual(chunks[1].startTime, 3.7, accuracy: 0.05)
        XCTAssertEqual(chunks[1].endTime, 6.3, accuracy: 0.1)
        XCTAssertTrue(chunks.allSatisfy { $0.speaker == .others })
        XCTAssertEqual(Double(chunks[0].samples.count) / sampleRate, chunks[0].endTime - chunks[0].startTime, accuracy: 0.001)
    }

    /// A short click is not worth transcribing (whisper would invent text)
    func testDropsChunksWithTooLittleSpeech() {
        let collector = Collector()
        let chunker = SpeechChunker(speaker: .me) { collector.add($0) }

        feed(silence(1) + tone(0.2) + silence(1), to: chunker)
        chunker.flush()

        XCTAssertTrue(collector.chunks.isEmpty)
    }

    /// Pure silence produces nothing
    func testSilenceProducesNoChunks() {
        let collector = Collector()
        let chunker = SpeechChunker(speaker: .me) { collector.add($0) }

        feed(silence(10), to: chunker)
        chunker.flush()

        XCTAssertTrue(collector.chunks.isEmpty)
    }

    /// Speech without pauses is cut below whisper's 30-second window
    func testLongSpeechIsSplitBelowWhisperWindow() {
        let collector = Collector()
        let chunker = SpeechChunker(speaker: .others) { collector.add($0) }

        feed(tone(60), to: chunker)
        chunker.flush()

        let chunks = collector.chunks
        XCTAssertGreaterThanOrEqual(chunks.count, 3)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.endTime - chunk.startTime, 25.01)
        }
        XCTAssertEqual(chunks.last?.endTime ?? 0, 60, accuracy: 0.05)
    }

    /// `flush` emits speech that is still open when the meeting stops
    func testFlushEmitsOpenChunk() {
        let collector = Collector()
        let chunker = SpeechChunker(speaker: .me) { collector.add($0) }

        feed(silence(0.5) + tone(3), to: chunker)
        XCTAssertTrue(collector.chunks.isEmpty)

        chunker.flush()

        XCTAssertEqual(collector.chunks.count, 1)
        XCTAssertEqual(collector.chunks.first?.endTime ?? 0, 3.5, accuracy: 0.05)
    }

    /// `coveredUntil` stays at an emitted chunk until its delivery is acknowledged
    func testCoveredUntilWaitsForDeliveryAcknowledgement() throws {
        let collector = Collector()
        let chunker = SpeechChunker(speaker: .others) { collector.add($0) }

        feed(silence(1) + tone(2) + silence(1), to: chunker)
        let chunk = try XCTUnwrap(collector.chunks.first)

        XCTAssertEqual(chunker.coveredUntil, chunk.startTime, accuracy: 0.001)

        chunker.acknowledgeDelivery(startTime: chunk.startTime)

        XCTAssertEqual(chunker.coveredUntil, 4.0, accuracy: 0.05)
    }

    /// After a capture restart the timeline continues from wall-clock time
    func testResyncMovesTimelineForward() {
        let collector = Collector()
        let chunker = SpeechChunker(speaker: .me) { collector.add($0) }

        feed(silence(1), to: chunker)
        chunker.resync(to: 10)
        feed(tone(2) + silence(1), to: chunker)

        XCTAssertEqual(collector.chunks.count, 1)
        XCTAssertEqual(collector.chunks.first?.startTime ?? 0, 10, accuracy: 0.05)
    }
}
