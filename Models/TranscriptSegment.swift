//
//  TranscriptSegment.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: transcript data model
//

import Foundation

/// Audio source of a meeting transcript line
///
/// The microphone is the user ("Minä"); system audio carries every other
/// participant ("Muut"). Individual remote speakers are not separated.
nonisolated enum MeetingSpeaker: String, Codable, CaseIterable {
    case me = "Minä"
    case others = "Muut"

    /// ASCII tag used in pending chunk file names
    var fileTag: String {
        switch self {
        case .me: return "me"
        case .others: return "others"
        }
    }

    init?(fileTag: String) {
        guard let speaker = Self.allCases.first(where: { $0.fileTag == fileTag }) else { return nil }
        self = speaker
    }
}

/// One transcribed speech chunk of a meeting
nonisolated struct TranscriptSegment: Identifiable, Equatable {
    let id = UUID()
    let speaker: MeetingSpeaker
    /// Seconds from meeting start
    let startTime: TimeInterval
    /// Seconds from meeting start
    let endTime: TimeInterval
    let text: String
}
