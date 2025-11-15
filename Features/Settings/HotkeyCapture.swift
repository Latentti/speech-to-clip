//
//  HotkeyCapture.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.3: Implement Hotkey Capture Control
//

import SwiftUI
import AppKit
import HotKey

/// Interactive hotkey capture control for customizing global shortcuts
///
/// Allows users to click and press a new key combination to customize
/// their global hotkey. Provides visual feedback during capture and
/// validates against system conflicts.
///
/// Usage:
/// ```swift
/// HotkeyCapture(
///     currentHotkey: $appState.settings.hotkey,
///     onHotkeyChanged: { newHotkey in
///         // Update HotkeyManager with new hotkey
///     }
/// )
/// ```
struct HotkeyCapture: View {
    // MARK: - Properties

    /// Current hotkey configuration
    @Binding var currentHotkey: HotkeyConfig

    /// Callback when hotkey is successfully changed
    var onHotkeyChanged: ((HotkeyConfig) -> Void)?

    /// Whether the control is in listening mode
    @State private var isListening = false

    /// Captured key combination during listening
    @State private var capturedKey: Key?
    @State private var capturedModifiers: NSEvent.ModifierFlags = []

    /// Conflict detection result
    @State private var conflictResult: HotkeyConflictDetector.ConflictResult = .none

    /// Local event monitor for key capture
    @State private var eventMonitor: Any?

    /// Conflict detector instance
    private let conflictDetector = HotkeyConflictDetector()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hotkey button
            Button(action: toggleListening) {
                HStack {
                    if isListening {
                        Text("Press keys...")
                            .foregroundColor(.secondary)
                    } else {
                        Text(currentHotkey.displayString)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    if isListening {
                        Image(systemName: "keyboard")
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(8)
                .frame(minWidth: 200)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isListening ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isListening ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)

            // Conflict warning/error
            if case .warning(let message) = conflictResult {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }

            if case .blocked(let message) = conflictResult {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }

            // Helper text
            if isListening {
                Text("Press Escape to cancel")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if currentHotkey == .default {
                Text("Default: Control+Space (to change, click and press a different combination)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onDisappear {
            stopListening()
        }
    }

    // MARK: - Actions

    /// Toggle listening mode
    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    /// Start listening for key events
    private func startListening() {
        isListening = true
        capturedKey = nil
        capturedModifiers = []
        conflictResult = .none

        // Add local event monitor to capture key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
            return nil // Consume the event
        }
    }

    /// Stop listening for key events
    private func stopListening() {
        isListening = false

        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// Handle captured key event
    private func handleKeyEvent(_ event: NSEvent) -> Void {
        // Handle Escape key to cancel
        if event.keyCode == 53 { // Escape key
            stopListening()
            conflictResult = .none
            return
        }

        // Ignore pure modifier key presses (flagsChanged events without main key)
        if event.type == .flagsChanged {
            // Just track modifiers, don't commit yet
            capturedModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            return
        }

        // Key down event - capture the combination
        let key = event.keyCode
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // Validate: Must have at least one modifier
        guard !modifiers.isEmpty else {
            conflictResult = .blocked("Please use at least one modifier key (⌘, ⌥, ⌃, or ⇧)")
            return
        }

        // Convert to HotKey Key type
        guard let hotkeyKey = Key(carbonKeyCode: UInt32(key)) else {
            conflictResult = .blocked("Invalid key combination")
            return
        }

        // Check for conflicts
        let conflict = conflictDetector.detectConflict(key: hotkeyKey, modifiers: modifiers)
        conflictResult = conflict

        // Block if hard conflict
        if case .blocked = conflict {
            return
        }

        // Valid combination - update hotkey
        let newConfig = HotkeyConfig(key: hotkeyKey, modifiers: modifiers)
        currentHotkey = newConfig
        stopListening()

        // Notify callback
        onHotkeyChanged?(newConfig)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HotkeyCapture(
            currentHotkey: .constant(.default),
            onHotkeyChanged: { config in
                print("Hotkey changed to: \(config.displayString)")
            }
        )
        .padding()

        HotkeyCapture(
            currentHotkey: .constant(HotkeyConfig(key: .a, modifiers: [.command, .option])),
            onHotkeyChanged: nil
        )
        .padding()
    }
    .frame(width: 400)
}
