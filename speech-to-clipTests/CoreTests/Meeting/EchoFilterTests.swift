//
//  EchoFilterTests.swift
//  speech-to-clipTests
//
//  Created on 2026-09-15.
//  Meeting transcription: speaker echo filtering
//

import XCTest
@testable import speech_to_clip

/// Tests for EchoFilter
///
/// The echo example uses real transcripts from a speaker test: the system audio
/// and the built-in microphone both transcribed the same Finnish sample.
final class EchoFilterTests: XCTestCase {

    private let systemSegment = TranscriptSegment(
        speaker: .others,
        startTime: 3,
        endTime: 20,
        text: "Hyvää huomenta kaikille, ja kiitos että pääsitte mukaan. Käydään tänään läpi projektin tilanne, aikataulu, ja seuraavat askeleet."
    )

    func testMicrophoneEchoOfSystemAudioIsDetected() {
        let echo = TranscriptSegment(
            speaker: .me,
            startTime: 3.2,
            endTime: 12,
            text: "Hyvää huomenta kaikille ja kiitos että pääsitte mukaan. Käydään tänään läpi projektin tilanne"
        )

        XCTAssertTrue(EchoFilter.isEcho(echo, of: [systemSegment]))
    }

    func testOwnSpeechDuringOthersIsKept() {
        let ownSpeech = TranscriptSegment(
            speaker: .me,
            startTime: 10,
            endTime: 16,
            text: "Selvä, sovitaan näin. Meillä on neljä tai viisi konsulttia tässä projektissa."
        )

        XCTAssertFalse(EchoFilter.isEcho(ownSpeech, of: [systemSegment]))
    }

    func testMatchingTextWithoutTimeOverlapIsKept() {
        let later = TranscriptSegment(
            speaker: .me,
            startTime: 120,
            endTime: 125,
            text: "Käydään tänään läpi projektin tilanne"
        )

        XCTAssertFalse(EchoFilter.isEcho(later, of: [systemSegment]))
    }

    func testNoSystemSegmentsMeansNoEcho() {
        let speech = TranscriptSegment(speaker: .me, startTime: 0, endTime: 5, text: "Hyvää huomenta kaikille")

        XCTAssertFalse(EchoFilter.isEcho(speech, of: []))
    }

    func testContainmentIgnoresCaseAndPunctuation() {
        XCTAssertEqual(EchoFilter.containment(of: "Kiitos, KAIKILLE!", in: "kiitos kaikille"), 1.0, accuracy: 0.0001)
        XCTAssertEqual(EchoFilter.containment(of: "", in: "kiitos"), 0)
    }
}
