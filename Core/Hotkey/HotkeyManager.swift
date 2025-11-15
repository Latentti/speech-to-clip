//
//  HotkeyManager.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 2.1: Implement Global Hotkey Registration
//

import Foundation
import AppKit
import HotKey

/// Manages global hotkey registration for triggering voice recording
///
/// HotkeyManager uses the HotKey library to register system-wide keyboard shortcuts
/// that work even when the app is in the background. The default hotkey is Control+Space.
///
/// The manager integrates with AppState via dependency injection to update recording
/// state when the hotkey is pressed. State updates are dispatched to the main actor
/// to ensure thread safety.
///
/// Usage:
/// ```swift
/// let hotkeyManager = HotkeyManager(appState: appState)
/// // Hotkey is automatically registered and will persist until deallocation
/// ```
///
/// Story 6.3 enhancements:
/// - Dynamic hotkey registration via updateHotkey()
/// - User-customizable hotkey via Settings integration
class HotkeyManager {
    // MARK: - Properties

    /// HotKey instance - must be retained for the hotkey to remain registered
    /// The hotkey automatically unregisters when this instance is deallocated
    private var hotkey: HotKey?

    /// Reference to central app state for publishing hotkey events
    /// Weak reference to avoid retain cycles, though AppState typically outlives HotkeyManager
    private weak var appState: AppState?

    /// Currently registered hotkey configuration
    /// Tracked to enable rollback on failed updates
    private var currentConfig: HotkeyConfig?

    // MARK: - Initialization

    /// Initialize HotkeyManager with AppState dependency
    ///
    /// - Parameter appState: The central app state manager to update when hotkey is pressed
    ///
    /// The hotkey is registered immediately upon initialization with Control+Space as default.
    /// If registration fails (e.g., hotkey conflict with system), a warning is logged but
    /// the app continues to function.
    init(appState: AppState) {
        self.appState = appState
        // Story 6.3: Use hotkey from AppState.settings if available
        let hotkeyConfig = appState.settings.hotkey
        registerHotkey(key: hotkeyConfig.key, modifiers: hotkeyConfig.modifiers)
        self.currentConfig = hotkeyConfig
    }

    // MARK: - Hotkey Registration

    /// Update hotkey to a new key combination
    ///
    /// Story 6.3: Allows dynamic hotkey changes from Settings UI.
    /// Safely swaps the hotkey by unregistering the old one before registering the new one.
    ///
    /// - Parameters:
    ///   - key: The new main key
    ///   - modifiers: The new modifier flags
    /// - Throws: HotkeyRegistrationError if registration fails
    ///
    /// Error recovery: If registration fails, the previous hotkey is restored
    func updateHotkey(key: Key, modifiers: NSEvent.ModifierFlags) throws {
        // Store previous config for rollback
        let previousConfig = currentConfig
        let previousHotkey = hotkey

        // Step 1: Unregister current hotkey
        unregisterHotkey()

        // Step 2: Register new hotkey
        registerHotkey(key: key, modifiers: modifiers)

        // Step 3: Verify registration succeeded
        if hotkey == nil {
            // Registration failed - restore previous hotkey
            print("⚠️ Hotkey registration failed, restoring previous hotkey")

            if let previous = previousConfig {
                registerHotkey(key: previous.key, modifiers: previous.modifiers)
                currentConfig = previous
            } else {
                // Restore previous hotkey instance
                hotkey = previousHotkey
            }

            throw HotkeyRegistrationError.registrationFailed
        }

        // Step 4: Update current config
        currentConfig = HotkeyConfig(key: key, modifiers: modifiers)
    }

    /// Unregister the current hotkey
    ///
    /// Story 6.3: Allows explicit hotkey unregistration.
    /// The hotkey is automatically unregistered when set to nil (HotKey library behavior).
    func unregisterHotkey() {
        if let config = currentConfig {
            print("🔌 Unregistering hotkey: \(config.displayString)")
        }
        hotkey = nil
        currentConfig = nil
    }

    /// Register the global hotkey with the system
    ///
    /// This method creates a HotKey instance with a keyDownHandler closure that
    /// updates AppState.recordingState when pressed. The HotKey instance must be
    /// retained as a property - if it's deallocated, the hotkey stops working.
    ///
    /// - Parameters:
    ///   - key: The main key for the hotkey
    ///   - modifiers: The modifier flags (Command, Option, Control, Shift)
    ///
    /// Error handling:
    /// - If hotkey registration fails (already in use by system), logs a warning
    /// - App continues to function, but hotkey will not work
    private func registerHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        // Create and store HotKey instance
        // The keyDownHandler closure is called when the hotkey is pressed
        // Note: HotKey initializer does not throw - it silently fails if hotkey cannot be registered
        hotkey = HotKey(key: key, modifiers: modifiers)

        // Set up the handler that responds to hotkey presses
        hotkey?.keyDownHandler = { [weak self] in
            self?.handleHotkeyPressed()
        }

        // Create display string for logging
        let config = HotkeyConfig(key: key, modifiers: modifiers)
        let displayString = config.displayString

        // Verify hotkey was registered successfully
        if hotkey != nil {
            print("✅ Global hotkey registered: \(displayString)")
        } else {
            // Hotkey registration failed (key combination already in use)
            print("⚠️ Failed to register global hotkey \(displayString)")
            print("   This usually means the hotkey is already in use by another app or system shortcut")
        }
    }

    /// Handle hotkey press event
    ///
    /// This method is called by HotKey when Control+Space is pressed.
    /// It delegates to AppState recording lifecycle methods to manage the
    /// recording state machine.
    ///
    /// State transitions:
    /// - idle → recording: Calls appState.startRecording()
    /// - recording → idle: Calls appState.stopRecording()
    ///
    /// Thread safety: Dispatches to @MainActor since AppState requires
    /// main actor isolation for all state changes.
    private func handleHotkeyPressed() {
        guard let appState = appState else {
            print("⚠️ HotkeyManager: AppState reference is nil")
            return
        }

        // Dispatch to main actor for AppState method calls
        // AppState is marked with @MainActor
        Task { @MainActor in
            // Get current recording state
            let currentState = appState.recordingState

            switch currentState {
            case .idle:
                // Start recording via AppState method
                // AppState handles state transition, AudioRecorder lifecycle, and error handling
                appState.startRecording()

            case .recording:
                // Stop recording via AppState method
                // AppState handles state transition, audio data retrieval, and error handling
                appState.stopRecording()

            case .processing, .success, .error:
                // Ignore hotkey presses during these states
                print("⏭️ Hotkey ignored - app is currently \(currentState)")
            }
        }
    }

    // MARK: - Deinitialization

    deinit {
        // HotKey automatically unregisters when deallocated
        print("🔌 HotkeyManager deinitialized - hotkey unregistered")
    }
}

// MARK: - Errors

/// Errors that can occur during hotkey registration
enum HotkeyRegistrationError: Error, LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Failed to register hotkey. The key combination may already be in use by another application or system shortcut."
        }
    }
}
