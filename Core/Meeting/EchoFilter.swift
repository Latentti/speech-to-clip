//
//  EchoFilter.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: drop speaker echo picked up by the microphone
//

import Foundation

/// Detects microphone segments that only repeat what the system audio played
///
/// With speakers, the microphone hears the other participants and whisper
/// transcribes that echo almost word for word. A microphone segment counts as
/// echo when most of its words appear in system audio segments that overlap it
/// in time. The user's own speech during someone else's turn uses different
/// words and is kept.
///
/// The two channels rarely produce identical words: the echo is transcribed
/// with other Finnish inflections and spellings ("kaks" / "kaksi",
/// "rekordin" / "rekordlin"), so words are matched by their common beginning.
nonisolated enum EchoFilter {
    /// Share of microphone words that must appear in overlapping system audio
    static let defaultThreshold = 0.6
    /// Seconds of slack when matching segment times
    static let defaultTolerance: TimeInterval = 3

    /// Lowercased word tokens without punctuation
    static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Whether two words are the same word in a different form
    ///
    /// - Words of four or more letters match when their common beginning covers
    ///   at least four letters and 60 % of the shorter word ("valikoin" / "valikoiset").
    /// - Two- and three-letter words match exactly or as the start of a word at
    ///   most two letters longer ("et" / "että", "ku" / "kun").
    static func wordsMatch(_ first: String, _ second: String) -> Bool {
        if first == second { return true }
        let (short, long) = first.count <= second.count ? (first, second) : (second, first)
        let shortCount = short.count

        if shortCount < 4 {
            return shortCount >= 2 && long.hasPrefix(short) && long.count <= shortCount + 2
        }
        let commonPrefix = zip(short, long).prefix { $0 == $1 }.count
        let required = max(4, Int((Double(shortCount) * 0.6).rounded(.up)))
        return commonPrefix >= required
    }

    /// Fraction of words in `candidate` that also occur in `reference` (0...1)
    static func containment(of candidate: String, in reference: String) -> Double {
        let candidateWords = words(in: candidate)
        guard !candidateWords.isEmpty else { return 0 }
        let referenceWords = Set(words(in: reference))
        let matches = candidateWords.filter { word in
            referenceWords.contains(word) || referenceWords.contains { wordsMatch(word, $0) }
        }.count
        return Double(matches) / Double(candidateWords.count)
    }

    /// Whether a microphone segment is echo of the given system audio segments
    static func isEcho(
        _ micSegment: TranscriptSegment,
        of systemSegments: [TranscriptSegment],
        tolerance: TimeInterval = defaultTolerance,
        threshold: Double = defaultThreshold
    ) -> Bool {
        let overlapping = systemSegments.filter {
            $0.startTime <= micSegment.endTime + tolerance && $0.endTime >= micSegment.startTime - tolerance
        }
        guard !overlapping.isEmpty else { return false }
        let reference = overlapping.map(\.text).joined(separator: " ")
        return containment(of: micSegment.text, in: reference) >= threshold
    }

    /// Longest microphone line dropped whenever other participants speak at the same time
    static let shortLineMaximumWords = 2

    /// Whether a microphone segment should be dropped from the transcript
    ///
    /// Adds a rule for very short lines to `isEcho`: echo fragments such as
    /// "Kiitos." or "and" have too few words to compare, so a line of at most
    /// `shortLineMaximumWords` words is dropped when it overlaps other
    /// participants' speech. A short own interjection during someone else's
    /// turn is lost as well, which matters little for a memo.
    static func shouldDrop(_ micSegment: TranscriptSegment, of systemSegments: [TranscriptSegment]) -> Bool {
        if isEcho(micSegment, of: systemSegments) {
            return true
        }
        guard words(in: micSegment.text).count <= shortLineMaximumWords else { return false }
        return systemSegments.contains {
            $0.startTime <= micSegment.endTime + 1 && $0.endTime >= micSegment.startTime - 1
        }
    }
}
