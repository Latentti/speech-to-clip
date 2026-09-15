//
//  WhisperSegmentFilterTests.swift
//  speech-to-clipTests
//
//  Created on 2026-09-15.
//  Meeting transcription: drop text whisper invents for silence or noise
//

import XCTest
@testable import speech_to_clip

/// Tests for WhisperSegmentFilter
///
/// Texts and log probabilities are real values returned by the local
/// whisper-server for speech, silence and noise recordings.
final class WhisperSegmentFilterTests: XCTestCase {

    private func segment(_ text: String, _ avgLogprob: Double?) -> WhisperSegment {
        WhisperSegment(start: 0, end: 1, text: text, avgLogprob: avgLogprob)
    }

    func testKeepsSpeechAndDropsInventedText() {
        let segments = [
            segment(" Osaamme viennin ja vmylle myös vain tällä aikavälillä jatkossakinankin hyväksi.", -2.933),
            segment(" Selvä sovitaan näin. Nythän projektin osalta on semmoinen tilanne.", -0.142),
            segment(" Arvoisa herra puhemies. Hyvin olet. Kiitos.", -1.894),
            segment(" Sisällöksi ja meidän pitää tehdä linjaus.", -0.269),
        ]

        let text = WhisperSegmentFilter.acceptedText(from: segments)

        XCTAssertEqual(text, "Selvä sovitaan näin. Nythän projektin osalta on semmoinen tilanne. Sisällöksi ja meidän pitää tehdä linjaus.")
    }

    func testDropsPunctuationOnlySegmentsEvenWithGoodScore() {
        XCTAssertEqual(WhisperSegmentFilter.acceptedText(from: [segment(",", -0.334)]), "")
    }

    func testSegmentsWithoutScoreAreKept() {
        XCTAssertEqual(WhisperSegmentFilter.acceptedText(from: [segment("Jatketaan huomenna.", nil)]), "Jatketaan huomenna.")
    }

    func testThresholdIsInclusive() {
        let segments = [segment("Rajalla.", -1.0), segment("Alle rajan.", -1.01)]

        XCTAssertEqual(WhisperSegmentFilter.acceptedSegments(segments).map(\.text), ["Rajalla."])
    }
}
