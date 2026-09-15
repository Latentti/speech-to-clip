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
/// Examples are real transcripts: a speaker test with a Finnish sample and a
/// Slack huddle held on built-in speakers, where echo slipped through because
/// the microphone channel used other inflections and spellings.
final class EchoFilterTests: XCTestCase {

    private let systemSegment = TranscriptSegment(
        speaker: .others,
        startTime: 3,
        endTime: 20,
        text: "Hyvää huomenta kaikille, ja kiitos että pääsitte mukaan. Käydään tänään läpi projektin tilanne, aikataulu, ja seuraavat askeleet."
    )

    // MARK: - Echo Detection

    func testMicrophoneEchoOfSystemAudioIsDetected() {
        let echo = TranscriptSegment(
            speaker: .me,
            startTime: 3.2,
            endTime: 12,
            text: "Hyvää huomenta kaikille ja kiitos että pääsitte mukaan. Käydään tänään läpi projektin tilanne"
        )

        XCTAssertTrue(EchoFilter.isEcho(echo, of: [systemSegment]))
    }

    /// Huddle: "kaks" / "kaksi" and "valikoin" / "valikoiset"
    func testEchoWithDifferentInflectionsIsDetected() {
        let others = TranscriptSegment(
            speaker: .others,
            startTime: 28,
            endTime: 36,
            text: "Nii ja siis kyllähän jos antaa mulle linkit vaikka useampaakin paikkaa niin kyllä se voi lukea ne hakemukset läpi ja sit mä vaikka valikoin sielt kaks mihin mä haen."
        )
        let echo = TranscriptSegment(speaker: .me, startTime: 36, endTime: 38, text: "ovat valikoiset kaksi mihin mä haen.")

        XCTAssertTrue(EchoFilter.isEcho(echo, of: [others]))
    }

    /// Huddle: "ottanu" / "ottanut", "rekordin" / "rekordlin"
    func testEchoWithDifferentSpellingsIsDetected() {
        let others = TranscriptSegment(
            speaker: .others,
            startTime: 83,
            endTime: 90,
            text: "Niitä paikkoja mitä sä mainitsit, niin sehän ei nyt ottanut niitä vastaan, että nyt on Segein ja Rekordlin."
        )
        let echo = TranscriptSegment(
            speaker: .me,
            startTime: 84,
            endTime: 92,
            text: "niit paikkoja mitä sä mainitsit ja sinä ei nyt ottanu niitä vaan sä tyytä CGE:n ja rekordin."
        )

        XCTAssertTrue(EchoFilter.isEcho(echo, of: [others]))
    }

    /// Huddle: short spoken forms "et" / "että", "ku" / "kun"
    func testEchoWithShortSpokenFormsIsDetected() {
        let others = TranscriptSegment(speaker: .others, startTime: 61, endTime: 63, text: "Kun mä rupesin miettimään tätä, että kun -")
        let echo = TranscriptSegment(speaker: .me, startTime: 62, endTime: 64, text: "Mä rupesin miettii tota et ku.")

        XCTAssertTrue(EchoFilter.isEcho(echo, of: [others]))
    }

    // MARK: - Own Speech Is Kept

    func testOwnSpeechDuringOthersIsKept() {
        let ownSpeech = TranscriptSegment(
            speaker: .me,
            startTime: 10,
            endTime: 16,
            text: "Selvä, sovitaan näin. Meillä on neljä tai viisi konsulttia tässä projektissa."
        )

        XCTAssertFalse(EchoFilter.isEcho(ownSpeech, of: [systemSegment]))
    }

    /// Huddle: the user's reply right after the other participant spoke
    func testOwnReplyInHuddleIsKept() {
        let others = TranscriptSegment(
            speaker: .others,
            startTime: 83,
            endTime: 90,
            text: "Niitä paikkoja mitä sä mainitsit, niin sehän ei nyt ottanut niitä vastaan, että nyt on Segein ja Rekordlin."
        )
        let reply = TranscriptSegment(
            speaker: .me,
            startTime: 97,
            endTime: 104,
            text: "No sano sille, että mä muutinkin mielipiteen, että sä haluut nähdä kaiken, mutta sen kuuluu priorisoida."
        )

        XCTAssertFalse(EchoFilter.isEcho(reply, of: [others]))
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

    // MARK: - Word Matching

    func testWordsMatchInflectionsButNotDifferentWords() {
        XCTAssertTrue(EchoFilter.wordsMatch("kaks", "kaksi"))
        XCTAssertTrue(EchoFilter.wordsMatch("valikoiset", "valikoin"))
        XCTAssertTrue(EchoFilter.wordsMatch("et", "että"))
        XCTAssertFalse(EchoFilter.wordsMatch("se", "segein"))
        XCTAssertFalse(EchoFilter.wordsMatch("tota", "tätä"))
        XCTAssertFalse(EchoFilter.wordsMatch("sille", "sehän"))
    }

    func testContainmentIgnoresCaseAndPunctuation() {
        XCTAssertEqual(EchoFilter.containment(of: "Kiitos, KAIKILLE!", in: "kiitos kaikille"), 1.0, accuracy: 0.0001)
        XCTAssertEqual(EchoFilter.containment(of: "", in: "kiitos"), 0)
    }
}
