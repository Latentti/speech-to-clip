//
//  RecordingState.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 1.4: Implement Central AppState
//

import Foundation

/// Represents the current state of the recording lifecycle
///
/// This enum drives the entire application state machine, controlling
/// UI updates for the menu bar icon and visualizer states.
///
/// State transitions:
/// - idle → recording (user presses hotkey)
/// - recording → processing (user presses hotkey again)
/// - processing → proofreading (when AI proofreading is enabled)
/// - processing → success (transcription completes without proofreading)
/// - proofreading → success (proofreading completes)
/// - processing/proofreading → error (transcription or proofreading fails)
/// - success/error → idle (ready for next recording)
///
/// - Note: Story 11.5-4 added `.proofreading` state for AI proofreading visualization
enum RecordingState: Equatable {
    case idle
    case recording(startTime: Date)
    case processing
    case proofreading
    case success
    case error(Error)

    // Custom Equatable conformance since Error is not Equatable
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.recording(let lhsTime), .recording(let rhsTime)):
            return lhsTime == rhsTime
        case (.processing, .processing):
            return true
        case (.proofreading, .proofreading):
            return true
        case (.success, .success):
            return true
        case (.error, .error):
            // Note: We can't compare errors directly, so we just check if both are error states
            return true
        default:
            return false
        }
    }
}
