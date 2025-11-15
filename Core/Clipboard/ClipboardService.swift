//
//  ClipboardService.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 5.1: Implement Clipboard Management
//

import Foundation
import AppKit

/// Service for managing system clipboard operations
///
/// Provides a simple interface for copying text to the macOS clipboard
/// using NSPasteboard. Handles error cases gracefully.
///
/// **Usage:**
/// ```swift
/// let clipboard = ClipboardService()
/// try clipboard.copyText("Hello, clipboard!")
/// ```
///
/// - Note: Story 5.1 - Fallback mechanism before auto-paste (Story 5.2)
class ClipboardService {

    /// Copy text to system clipboard
    ///
    /// Clears any existing clipboard contents and sets the new text as plain string.
    /// Text is immediately available for Cmd+V in any application.
    ///
    /// - Parameter text: The text to copy (must not be empty)
    /// - Throws: ClipboardError if operation fails
    ///
    /// - Complexity: O(1) - Direct NSPasteboard API call
    func copyText(_ text: String) throws {
        guard !text.isEmpty else {
            throw ClipboardError.emptyText
        }

        // Clear previous clipboard contents
        NSPasteboard.general.clearContents()

        // Set new text as plain string
        let success = NSPasteboard.general.setString(text, forType: .string)

        guard success else {
            throw ClipboardError.copyFailed
        }
    }
}

/// Errors that can occur during clipboard operations
enum ClipboardError: LocalizedError {
    case emptyText
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Cannot copy empty text to clipboard"
        case .copyFailed:
            return "Failed to copy text to clipboard"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyText:
            return "Ensure transcription produced valid text before copying."
        case .copyFailed:
            return "Try closing other apps using the clipboard."
        }
    }
}
