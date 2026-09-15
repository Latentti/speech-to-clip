//
//  TranscriptMerger.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: readable speaker turns from speech chunks
//

import Foundation

/// A speaker turn built from consecutive transcript segments
nonisolated struct TranscriptTurn: Identifiable, Equatable {
    /// Identifier of the first segment in the turn
    let id: UUID
    let speaker: MeetingSpeaker
    /// Seconds from meeting start
    let startTime: TimeInterval
    /// Seconds from meeting start
    let endTime: TimeInterval
    let text: String
}

/// Removes artifacts that whisper leaves at chunk boundaries
///
/// Chunks cut at a thinking pause end with a dangling dash ("koska tota, -")
/// or start with punctuation (",kun ne myy…"). The words themselves are not
/// touched; spoken language stays as it was said.
nonisolated enum TranscriptTextCleanup {
    static func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Dangling dash at the end, with an optional comma before it: "tavallaan, -"
        result = result.replacingOccurrences(of: "[\\s,]*[-–—]+$", with: "", options: .regularExpression)
        // Punctuation or dash at the start: ",kun", "- Joo"
        result = result.replacingOccurrences(of: "^[\\s,;\\-–—]+", with: "", options: .regularExpression)
        // Dash glued to the next sentence: "pointti. -Raskisti" → "pointti. Raskisti"
        result = result.replacingOccurrences(of: "([.!?])\\s*[-–—]\\s*", with: "$1 ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespaces)
    }
}

/// Joins fragmented segments of one speaker into readable turns
///
/// Speech is cut into chunks at pauses, so one spoken sentence often arrives
/// as several segments. Consecutive segments of the same speaker are joined when:
/// - the previous segment ends mid-sentence and the pause is short, or
/// - the previous segment ends a sentence, the pause is very short and the turn is not too long yet.
///
/// A segment from the other source always starts a new turn. The raw segments
/// stay unchanged in the live transcript file; turns are used for display and
/// for the final transcript written when the meeting ends.
nonisolated enum TranscriptMerger {
    struct Configuration {
        /// Longest pause joined when the previous segment ends mid-sentence
        var maximumGapInSentence: TimeInterval = 4
        /// Longest pause joined between complete sentences
        var maximumGapBetweenSentences: TimeInterval = 1.5
        /// Complete sentences start a new turn once the turn would exceed this length
        var maximumTurnDuration: TimeInterval = 60
    }

    static func merge(_ segments: [TranscriptSegment], configuration: Configuration = Configuration()) -> [TranscriptTurn] {
        var turns: [TranscriptTurn] = []
        for segment in segments.sorted(by: { $0.startTime < $1.startTime }) {
            let text = TranscriptTextCleanup.clean(segment.text)
            guard !text.isEmpty else { continue }

            if let last = turns.last,
               last.speaker == segment.speaker,
               shouldJoin(last, with: segment, text: text, configuration: configuration) {
                turns[turns.count - 1] = TranscriptTurn(
                    id: last.id,
                    speaker: last.speaker,
                    startTime: last.startTime,
                    endTime: max(last.endTime, segment.endTime),
                    text: join(last.text, text)
                )
            } else {
                turns.append(TranscriptTurn(
                    id: segment.id,
                    speaker: segment.speaker,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    text: text
                ))
            }
        }
        return turns
    }

    /// Whether text ends with sentence-final punctuation
    static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".!?…".contains(last)
    }

    /// A segment continues the sentence when the turn ends mid-sentence or the segment starts in lowercase
    private static func shouldJoin(
        _ turn: TranscriptTurn,
        with segment: TranscriptSegment,
        text: String,
        configuration: Configuration
    ) -> Bool {
        let gap = segment.startTime - turn.endTime
        let continuesSentence = !endsSentence(turn.text) || text.first?.isLowercase == true
        if continuesSentence {
            return gap <= configuration.maximumGapInSentence
        }
        return gap <= configuration.maximumGapBetweenSentences
            && segment.endTime - turn.startTime <= configuration.maximumTurnDuration
    }

    /// Join two texts and repair the punctuation whisper guessed at the chunk seam
    ///
    /// - A period before a lowercase continuation is removed ("rekordly. niminen" → "rekordly niminen").
    /// - A period is added between an unfinished chunk and a capitalized new sentence.
    private static func join(_ first: String, _ second: String) -> String {
        var head = first
        if let nextCharacter = second.first, let lastCharacter = head.last {
            if nextCharacter.isLowercase && lastCharacter == "." && !head.hasSuffix("...") {
                head.removeLast()
            } else if nextCharacter.isUppercase && !".!?…,;:".contains(lastCharacter) {
                head += "."
            }
        }
        return head + " " + second
    }
}
