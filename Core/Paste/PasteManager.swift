//
//  PasteManager.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 5.2: Implement Auto-Paste with Accessibility API
//

import Foundation
import AppKit
import ApplicationServices

/// Protocol for clipboard operations (enables dependency injection and testing)
protocol ClipboardProviding {
    func copyText(_ text: String) throws
}

/// ClipboardService conforms to ClipboardProviding protocol
extension ClipboardService: ClipboardProviding {}

/// Service for pasting text into the active application using accessibility APIs
///
/// Uses CGEvent API to simulate Cmd+V keystroke after copying text to clipboard.
/// This approach works across the widest range of macOS applications including
/// browsers (Chrome, Safari, Firefox), code editors (VS Code, Xcode, Cursor),
/// terminals (Terminal, iTerm2), and Electron apps (Claude Code).
///
/// **Accessibility Permission Required:**
/// - The app must have accessibility permission granted in System Settings
/// - Check with `AXIsProcessTrusted()` before attempting paste
/// - Without permission, CGEvent.post() silently fails
///
/// **Usage:**
/// ```swift
/// let pasteManager = PasteManager(clipboardService: ClipboardService())
/// do {
///     try pasteManager.paste("Hello, world!")
/// } catch PasteError.permissionDenied {
///     // Prompt user to grant accessibility permission
/// }
/// ```
///
/// - Note: Story 5.2 - Auto-paste mechanism using NSAccessibility/CGEvent API
class PasteManager {

    // MARK: - Properties

    /// Clipboard service for copying text before paste simulation
    private let clipboardService: ClipboardProviding

    // MARK: - Initialization

    /// Initialize with clipboard service dependency
    ///
    /// - Parameter clipboardService: Service for clipboard operations (defaults to new instance)
    init(clipboardService: ClipboardProviding = ClipboardService()) {
        self.clipboardService = clipboardService
    }

    // MARK: - Public Methods

    /// Paste text into the active application at cursor position
    ///
    /// This method:
    /// 1. Checks accessibility permission
    /// 2. Copies text to clipboard using ClipboardService
    /// 3. Simulates Cmd+V keystroke using CGEvent API
    ///
    /// **Important:** Text is always copied to clipboard, even if paste simulation fails.
    /// This provides a fallback mechanism - users can manually paste if auto-paste fails.
    ///
    /// - Parameter text: The text to paste (must not be empty)
    /// - Throws: PasteError if permission denied or paste simulation fails
    ///
    /// - Complexity: O(1) - Direct system API calls
    func paste(_ text: String) throws {
        // Validate input
        guard !text.isEmpty else {
            throw PasteError.emptyText
        }

        // Check accessibility permission BEFORE attempting paste
        guard AXIsProcessTrusted() else {
            throw PasteError.permissionDenied
        }

        // Copy text to clipboard first (ensures fallback if simulation fails)
        do {
            try clipboardService.copyText(text)
        } catch {
            // Rethrow clipboard errors as paste errors
            throw PasteError.clipboardFailed(underlying: error)
        }

        // Simulate Cmd+V keystroke
        try simulateCmdV()
    }

    // MARK: - Private Methods

    /// Simulate Cmd+V keystroke using CGEvent API
    ///
    /// Creates and posts keyboard events for Command+V:
    /// 1. Key down event with Cmd modifier
    /// 2. Key up event with Cmd modifier
    ///
    /// - Throws: PasteError.pasteSimulationFailed if event creation or posting fails
    private func simulateCmdV() throws {
        // Virtual key code for 'V' key
        let vKeyCode: CGKeyCode = 0x09

        // Create event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw PasteError.pasteSimulationFailed(reason: "Failed to create event source")
        }

        // Create key down event for 'V' with Cmd modifier
        guard let keyDownEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: vKeyCode, keyDown: true) else {
            throw PasteError.pasteSimulationFailed(reason: "Failed to create key down event")
        }
        keyDownEvent.flags = .maskCommand

        // Create key up event for 'V' with Cmd modifier
        guard let keyUpEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: vKeyCode, keyDown: false) else {
            throw PasteError.pasteSimulationFailed(reason: "Failed to create key up event")
        }
        keyUpEvent.flags = .maskCommand

        // Post events to system
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }
}

// MARK: - Errors

/// Errors that can occur during paste operations
enum PasteError: LocalizedError, Equatable {
    case emptyText
    case permissionDenied
    case pasteSimulationFailed(reason: String)
    case clipboardFailed(underlying: Error)
    case noActiveApplication

    // MARK: - Equatable

    static func == (lhs: PasteError, rhs: PasteError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyText, .emptyText):
            return true
        case (.permissionDenied, .permissionDenied):
            return true
        case (.pasteSimulationFailed(let lhsReason), .pasteSimulationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.clipboardFailed(let lhsError), .clipboardFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.noActiveApplication, .noActiveApplication):
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Cannot paste empty text"
        case .permissionDenied:
            return "Accessibility permission denied. speech-to-clip needs accessibility permission to paste text."
        case .pasteSimulationFailed(let reason):
            return "Failed to simulate paste: \(reason)"
        case .clipboardFailed(let underlying):
            return "Clipboard operation failed: \(underlying.localizedDescription)"
        case .noActiveApplication:
            return "No active application found to paste text"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyText:
            return "Ensure transcription produced valid text before pasting."
        case .permissionDenied:
            return "Open System Settings → Privacy & Security → Accessibility and enable access for speech-to-clip."
        case .pasteSimulationFailed:
            return "Text was copied to clipboard. You can manually paste with Cmd+V."
        case .clipboardFailed:
            return "Try closing other apps using the clipboard, then record again."
        case .noActiveApplication:
            return "Click on a text field in another application, then try recording again."
        }
    }
}
