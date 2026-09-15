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

    /// Fraction of words in `candidate` that also occur in `reference` (0...1)
    static func containment(of candidate: String, in reference: String) -> Double {
        let candidateWords = words(in: candidate)
        guard !candidateWords.isEmpty else { return 0 }
        let referenceWords = Set(words(in: reference))
        let matches = candidateWords.filter { referenceWords.contains($0) }.count
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
}
