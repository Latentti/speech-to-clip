//
//  SpeechToClipError.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 4.3: Implement Transcription Service
//

import Foundation

/// Unified error type for speech-to-clip application
///
/// This enum provides app-wide error handling with user-friendly messages
/// and actionable recovery suggestions. All errors from lower-level services
/// (AudioFormatService, WhisperClient, etc.) are mapped to this enum before
/// being presented to the user.
enum SpeechToClipError: LocalizedError {
    // MARK: - Transcription Errors

    /// Audio file exceeds 25MB limit
    case audioTooLarge(sizeMB: Double)

    /// Audio format is invalid or corrupted
    case audioFormatInvalid

    /// API key is missing or not configured
    case apiKeyMissing

    /// API key is invalid (authentication failed)
    case apiKeyInvalid

    /// Network is unavailable or request failed
    case networkUnavailable(underlying: Error)

    /// API rate limit exceeded
    case rateLimitExceeded

    /// Transcription failed for other reasons
    case transcriptionFailed(reason: String)

    // MARK: - Future Errors (for other epics)

    /// Microphone permission was denied
    case microphonePermissionDenied

    /// Accessibility permission was denied (needed for auto-paste)
    case accessibilityPermissionDenied

    /// Could not find target application for paste
    case pasteTargetNotFound

    // MARK: - LocalizedError Implementation

    var errorDescription: String? {
        switch self {
        case .audioTooLarge(let sizeMB):
            return "Audio file too large (\(String(format: "%.1f", sizeMB))MB). Maximum size is 25MB."
        case .audioFormatInvalid:
            return "Audio format is invalid or corrupted. Expected WAV format."
        case .apiKeyMissing:
            return "No API key configured. Please add your OpenAI API key in Settings."
        case .apiKeyInvalid:
            return "Invalid API key. Authentication failed with OpenAI Whisper API."
        case .networkUnavailable(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again in a few moments."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .microphonePermissionDenied:
            return "Microphone Permission Required - speech-to-clip needs access to your microphone to record your voice."
        case .accessibilityPermissionDenied:
            return "Auto-paste Unavailable - speech-to-clip needs accessibility permission to automatically paste transcribed text. Text has been copied to clipboard."
        case .pasteTargetNotFound:
            return "Could not find active application to paste text."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .audioTooLarge:
            return "Try recording a shorter audio clip. Whisper API has a 25MB file size limit."
        case .audioFormatInvalid:
            return "Please try recording again. If the problem persists, restart the application."
        case .apiKeyMissing:
            return "Open Settings and add your OpenAI API key to enable transcription."
        case .apiKeyInvalid:
            return "Check your API key in Settings. You can get a valid key from platform.openai.com."
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .rateLimitExceeded:
            return "Wait a few moments before trying again, or check your OpenAI API usage limits."
        case .transcriptionFailed:
            return "Try recording again. If the problem persists, check your API key and network connection."
        case .microphonePermissionDenied:
            return "To enable voice recording, open System Settings → Privacy & Security → Microphone and turn on access for speech-to-clip."
        case .accessibilityPermissionDenied:
            return "You can still use speech-to-clip - transcribed text is copied to clipboard. To enable auto-paste, open System Settings → Privacy & Security → Accessibility and turn on access for speech-to-clip."
        case .pasteTargetNotFound:
            return "Click on a text field in another application, then try recording again."
        }
    }
}
