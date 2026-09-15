//
//  WhisperTextNormalizer.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Fix: whisper.cpp server output pasted with line breaks inside words
//

import Foundation

/// Cleans up the `text` field returned by the whisper.cpp server
///
/// The server joins transcription segments with newlines. A segment may start
/// with or without a leading space, and punctuation-only fragments (such as ",")
/// sometimes arrive as their own segments at the end of the audio.
///
/// Mid-word line breaks are prevented on the request side by sending
/// `split_on_word=true` (see `WhisperCppClient`); this normalizer then joins
/// the remaining segment boundaries into a single line of text.
///
/// Example:
/// ```swift
/// WhisperTextNormalizer.normalize("Hyvää huomenta.\nKäydään läpi\n tilanne.\n,\n")
/// // "Hyvää huomenta. Käydään läpi tilanne."
/// ```
enum WhisperTextNormalizer {
    /// Join server segments into a single line of text
    ///
    /// - Parameter text: Raw text from the whisper.cpp server response
    /// - Returns: Segments joined with single spaces, without punctuation-only fragments
    nonisolated static func normalize(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { segment in
                segment.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
            }
            .joined(separator: " ")
            .replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
    }
}
