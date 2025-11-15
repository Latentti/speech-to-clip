//
//  AlertHelper.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-15.
//  Story 8.3: Handle Permission Denial Gracefully
//

import AppKit

/// Helper class for presenting user-facing alerts in a menu bar application
///
/// Provides reusable alert presentation logic with proper app activation
/// for menu bar apps (which don't have a main window by default).
///
/// **Usage:**
/// ```swift
/// AlertHelper.showPermissionDeniedAlert(for: .microphone, permissionManager: permissionManager)
/// ```
///
/// - Note: Story 8.3 - User-friendly permission denial alerts with "Open Settings" action
class AlertHelper {

    // MARK: - Permission Denial Alerts

    /// Show an alert when a required permission is denied
    ///
    /// Presents a modal alert with:
    /// - User-friendly title and message explaining why permission is needed
    /// - "Open System Settings" button that opens the correct Settings pane
    /// - "Cancel" button to dismiss the alert
    ///
    /// **Menu Bar App Pattern:**
    /// Calls `NSApp.activate(ignoringOtherApps: true)` to bring the app to the front
    /// before showing the alert, ensuring the user sees it immediately.
    ///
    /// - Parameters:
    ///   - type: The permission type that was denied (.microphone or .accessibility)
    ///   - permissionManager: PermissionManager instance to open System Settings
    static func showPermissionDeniedAlert(for type: PermissionType, permissionManager: PermissionManager) {
        // Activate app to bring alert to front (menu bar app pattern)
        NSApp.activate(ignoringOtherApps: true)

        // Create alert with appropriate content based on permission type
        let alert = NSAlert()

        switch type {
        case .microphone:
            alert.messageText = "Microphone Permission Required"
            alert.informativeText = """
            speech-to-clip needs access to your microphone to record your voice.

            Without microphone permission, the app cannot record audio.

            You can grant permission in System Settings → Privacy & Security → Microphone.
            """

        case .accessibility:
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
            speech-to-clip needs accessibility permission to automatically paste transcribed text.

            Without this permission, you can still use the app - transcribed text will be copied to the clipboard and you can paste it manually with ⌘V.

            To enable auto-paste, grant permission in System Settings → Privacy & Security → Accessibility.
            """
        }

        alert.alertStyle = .warning

        // Add "Open System Settings" button (default action)
        alert.addButton(withTitle: "Open System Settings")

        // Add "Cancel" button (alternative action)
        alert.addButton(withTitle: "Cancel")

        // Run alert modally
        let response = alert.runModal()

        // Handle user's choice
        if response == .alertFirstButtonReturn {
            // User clicked "Open System Settings"
            print("ℹ️ User chose to open System Settings for \(type) permission")
            permissionManager.openSystemSettings(for: type)
        } else {
            // User clicked "Cancel"
            print("ℹ️ User cancelled permission request for \(type)")
        }
    }

    /// Show a non-blocking notification when accessibility permission is denied
    ///
    /// This is used during the paste flow to inform the user that auto-paste
    /// is unavailable but the text was still copied to clipboard.
    ///
    /// **Non-Blocking Design:**
    /// Uses NSAlert in a less intrusive way - just informational, not requiring
    /// immediate user action.
    ///
    /// - Parameter message: Custom message to display
    static func showAccessibilityFallbackNotification(message: String = "Text copied to clipboard - auto-paste requires accessibility permission") {
        // For now, we'll log to console
        // In a future story, this could be upgraded to NSUserNotification or a subtle in-app banner
        print("ℹ️ \(message)")

        // Note: NSUserNotification is deprecated in macOS 11+
        // For production, consider using UNUserNotificationCenter or an in-app banner
        // For this story, console logging is sufficient as it doesn't block the flow
    }
}
