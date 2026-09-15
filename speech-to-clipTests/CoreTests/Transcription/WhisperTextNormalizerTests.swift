//
//  WhisperTextNormalizerTests.swift
//  speech-to-clipTests
//
//  Created on 2026-09-15.
//  Fix: whisper.cpp server output pasted with line breaks inside words
//

import XCTest
@testable import speech_to_clip

/// Tests for WhisperTextNormalizer
///
/// Inputs mirror real whisper.cpp server responses captured with
/// `split_on_word=true`: newline-separated segments, inconsistent leading
/// spaces and a trailing punctuation-only fragment.
final class WhisperTextNormalizerTests: XCTestCase {

    /// Segment boundaries with and without a leading space become single spaces
    func testJoinsSegmentsWithSingleSpaces() {
        let raw = "Selvä, sovitaan näin.\n Ja tämän projektin sisältö on laajentunut.\nMeidän pitää tehdä linjaus."

        let result = WhisperTextNormalizer.normalize(raw)

        XCTAssertEqual(result, "Selvä, sovitaan näin. Ja tämän projektin sisältö on laajentunut. Meidän pitää tehdä linjaus.")
    }

    /// Punctuation-only fragments at the end of the audio are dropped
    func testDropsPunctuationOnlySegments() {
        let raw = "Mikko kirjoittaa muistion perjantaihin mennessä.\n,\n"

        let result = WhisperTextNormalizer.normalize(raw)

        XCTAssertEqual(result, "Mikko kirjoittaa muistion perjantaihin mennessä.")
    }

    /// Already clean text passes through unchanged
    func testCleanTextIsUnchanged() {
        let raw = "Hyvää huomenta kaikille, ja kiitos että pääsitte mukaan."

        XCTAssertEqual(WhisperTextNormalizer.normalize(raw), raw)
    }

    /// Whitespace and punctuation only responses normalize to an empty string
    func testEmptyAndPunctuationOnlyInput() {
        XCTAssertEqual(WhisperTextNormalizer.normalize(""), "")
        XCTAssertEqual(WhisperTextNormalizer.normalize("\n ,\n.\n"), "")
    }

    /// Repeated spaces inside a segment collapse to one
    func testCollapsesRepeatedSpaces() {
        XCTAssertEqual(WhisperTextNormalizer.normalize("out of  scope   -työt"), "out of scope -työt")
    }
}
