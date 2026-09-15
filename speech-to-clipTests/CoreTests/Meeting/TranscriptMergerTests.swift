//
//  TranscriptMergerTests.swift
//  speech-to-clipTests
//
//  Created on 2026-09-15.
//  Meeting transcription: turns and chunk boundary cleanup
//

import XCTest
@testable import speech_to_clip

/// Tests for TranscriptMerger and TranscriptTextCleanup
///
/// Segment texts come from a real Slack huddle transcript.
final class TranscriptMergerTests: XCTestCase {

    private func segment(_ speaker: MeetingSpeaker, _ start: TimeInterval, _ end: TimeInterval, _ text: String) -> TranscriptSegment {
        TranscriptSegment(speaker: speaker, startTime: start, endTime: end, text: text)
    }

    // MARK: - Cleanup

    func testCleanupRemovesDanglingDashes() {
        XCTAssertEqual(TranscriptTextCleanup.clean("Mä mietin tavallaan, -"), "Mä mietin tavallaan")
        XCTAssertEqual(TranscriptTextCleanup.clean("Mä uskon, että se voisi olla monenlaista myös, että se antaa -"),
                       "Mä uskon, että se voisi olla monenlaista myös, että se antaa")
    }

    func testCleanupRemovesLeadingPunctuation() {
        XCTAssertEqual(TranscriptTextCleanup.clean(",kun ne myy noit konsultteja asiakkaalle. Se on mun mielestä"),
                       "kun ne myy noit konsultteja asiakkaalle. Se on mun mielestä")
        XCTAssertEqual(TranscriptTextCleanup.clean("Nii. - Joo."), "Nii. Joo.")
    }

    func testCleanupKeepsHyphenatedCompoundsAndEllipsis() {
        XCTAssertEqual(TranscriptTextCleanup.clean("out of scope -työt arvioidaan erikseen"), "out of scope -työt arvioidaan erikseen")
        XCTAssertEqual(TranscriptTextCleanup.clean("Mutta se pitäisi..."), "Mutta se pitäisi...")
        XCTAssertEqual(TranscriptTextCleanup.clean(" - "), "")
    }

    // MARK: - Merging

    /// Huddle 09:09:22–09:09:30: one sentence arrived as three segments
    func testJoinsSentenceSplitAcrossSegments() {
        let segments = [
            segment(.me, 22.0, 23.5, "koska tota, -"),
            segment(.me, 24.0, 25.5, "niitten se -"),
            segment(.me, 26.0, 30.0, "toiminta perustuu siihen ajatukseen, että ne saa myytyä sut eteenpäin."),
        ]

        let turns = TranscriptMerger.merge(segments)

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns.first?.text, "koska tota niitten se toiminta perustuu siihen ajatukseen, että ne saa myytyä sut eteenpäin.")
        XCTAssertEqual(turns.first?.startTime ?? 0, 22.0, accuracy: 0.001)
        XCTAssertEqual(turns.first?.endTime ?? 0, 30.0, accuracy: 0.001)
        XCTAssertEqual(turns.first?.id, segments[0].id)
    }

    func testOtherSpeakerStartsNewTurn() {
        let turns = TranscriptMerger.merge([
            segment(.me, 0, 5, "Siellä pitää oikeesti olla melko tämmönen niinku seniori"),
            segment(.others, 5.2, 6, "Kyllä, kyllä."),
            segment(.me, 6.2, 9, "asiantuntija, kun ne myy konsultteja asiakkaalle."),
        ])

        XCTAssertEqual(turns.map(\.speaker), [.me, .others, .me])
    }

    func testCompleteSentencesJoinOnlyAfterShortPause() {
        let shortPause = TranscriptMerger.merge([
            segment(.me, 0, 4, "Sinänsä toi lista oli varmaan ihan hyvä."),
            segment(.me, 5, 8, "Mitä se antoi sulle?"),
        ])
        let longPause = TranscriptMerger.merge([
            segment(.me, 0, 4, "Sinänsä toi lista oli varmaan ihan hyvä."),
            segment(.me, 10, 13, "Mitä se antoi sulle?"),
        ])

        XCTAssertEqual(shortPause.count, 1)
        XCTAssertEqual(longPause.count, 2)
    }

    func testUnfinishedSentenceJoinsAcrossLongerPause() {
        let turns = TranscriptMerger.merge([
            segment(.me, 0, 3, "Nyt on mielenkiintoista nähdä, että tuota -"),
            segment(.me, 6, 9, "minkälaiseksi se muuttaa sitä edellistä järjestystä."),
        ])

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns.first?.text, "Nyt on mielenkiintoista nähdä, että tuota minkälaiseksi se muuttaa sitä edellistä järjestystä.")
    }

    /// Huddle: whisper ended a chunk with a period in the middle of a sentence
    func testPeriodBeforeLowercaseContinuationIsRemoved() {
        let turns = TranscriptMerger.merge([
            segment(.me, 0, 5, "Koska toi nosto minkä se nosti sulle nyt kakkosyritykseksi tuolla toi rekordly."),
            segment(.me, 7, 12, "niminen yhtiö, niin sen mä tiedän suoraan."),
        ])

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns.first?.text, "Koska toi nosto minkä se nosti sulle nyt kakkosyritykseksi tuolla toi rekordly niminen yhtiö, niin sen mä tiedän suoraan.")
    }

    /// Huddle: an unfinished chunk followed by a new sentence gets a period at the seam
    func testPeriodIsAddedBeforeNewSentence() {
        let turns = TranscriptMerger.merge([
            segment(.others, 0, 2, "Mä mietin tavallaan, -"),
            segment(.others, 3, 9, "Nii ja siis kyllähän jos antaa mulle linkit."),
        ])

        XCTAssertEqual(turns.first?.text, "Mä mietin tavallaan. Nii ja siis kyllähän jos antaa mulle linkit.")
    }

    func testEllipsisIsKeptBeforeLowercaseContinuation() {
        let turns = TranscriptMerger.merge([
            segment(.others, 0, 2, "niin sitä Värtsilää tai..."),
            segment(.others, 2.5, 6, "muita paikkoja."),
        ])

        XCTAssertEqual(turns.first?.text, "niin sitä Värtsilää tai... muita paikkoja.")
    }

    func testLongMonologueIsSplitIntoParagraphs() {
        let segments = (0..<10).map { index in
            segment(.me, Double(index) * 10, Double(index) * 10 + 9.5, "Lause numero \(index).")
        }

        let turns = TranscriptMerger.merge(segments)

        XCTAssertGreaterThan(turns.count, 1)
        for turn in turns {
            XCTAssertLessThanOrEqual(turn.endTime - turn.startTime, 60.001)
        }
    }

    func testSegmentsAreSortedAndEmptyTextSkipped() {
        let turns = TranscriptMerger.merge([
            segment(.others, 10, 12, "Jatketaan huomenna."),
            segment(.me, 0, 2, " - "),
            segment(.me, 3, 5, "Oki doki."),
        ])

        XCTAssertEqual(turns.map(\.text), ["Oki doki.", "Jatketaan huomenna."])
    }
}
