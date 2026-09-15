//
//  WhisperSegmentFilter.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: drop text whisper invents for silence or noise
//

import Foundation

/// Keeps whisper segments that are likely real speech
///
/// whisper.cpp reports `no_speech_prob` as 0 even for invented text, but the
/// average log probability separates the two clearly. Measured with the local
/// Finnish large-v3 model on this app's recordings: real speech scored between
/// -0.01 and -0.34, while text invented for silence and noise ("Arvoisa herra
/// puhemies.", "bekäätä") scored between -1.9 and -3.6.
nonisolated enum WhisperSegmentFilter {
    /// Segments below this average log probability are dropped
    static let defaultMinimumAverageLogProbability = -1.0

    /// Segments that pass the confidence threshold; segments without a value are kept
    static func acceptedSegments(
        _ segments: [WhisperSegment],
        minimumAverageLogProbability: Double = defaultMinimumAverageLogProbability
    ) -> [WhisperSegment] {
        segments.filter { ($0.avgLogprob ?? 0) >= minimumAverageLogProbability }
    }

    /// Text of the accepted segments joined into one line
    static func acceptedText(
        from segments: [WhisperSegment],
        minimumAverageLogProbability: Double = defaultMinimumAverageLogProbability
    ) -> String {
        acceptedSegments(segments, minimumAverageLogProbability: minimumAverageLogProbability)
            .map { WhisperTextNormalizer.normalize($0.text) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
