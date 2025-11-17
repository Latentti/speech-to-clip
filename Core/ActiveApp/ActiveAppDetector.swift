//
//  ActiveAppDetector.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 5.3: Detect Active Application and Cursor
//

import Foundation
import AppKit
import ApplicationServices

/// Information about the active application
///
/// Contains metadata about the frontmost application and whether
/// it currently accepts text input (has a text field focused).
///
/// - Note: Story 5.3 - Active application detection for paste target validation
struct ActiveAppInfo {
    /// Human-readable application name (e.g., "Google Chrome")
    let appName: String

    /// Application bundle identifier (e.g., "com.google.Chrome")
    let bundleID: String

    /// Whether the application currently has a text field focused
    let acceptsTextInput: Bool
}

/// Service for detecting the active application and text input state
///
/// Uses NSWorkspace to identify the frontmost application and NSAccessibility
/// to check if a text field is currently focused. This information is used by
/// Story 5.4 to validate the paste target before attempting auto-paste.
///
/// **Accessibility Permission Required:**
/// - The app must have accessibility permission granted in System Settings
/// - Check with `AXIsProcessTrusted()` before querying focused element
/// - Without permission, text input detection will fail
///
/// **Usage:**
/// ```swift
/// let detector = ActiveAppDetector()
/// if let appInfo = try detector.getActiveApplication() {
///     if appInfo.acceptsTextInput {
///         // Safe to paste text
///     } else {
///         // Show error: no text field focused
///     }
/// }
/// ```
///
/// - Note: Story 5.3 - Application detection and text input validation
class ActiveAppDetector {

    // MARK: - Initialization

    /// Initialize the active app detector
    init() {}

    // MARK: - Public Methods

    /// Get information about the currently active application
    ///
    /// This method:
    /// 1. Queries NSWorkspace for the frontmost application
    /// 2. Extracts application name and bundle identifier
    /// 3. Checks if a text field is currently focused (requires accessibility permission)
    ///
    /// **Important:** If accessibility permission is not granted, acceptsTextInput will be false.
    /// The application name and bundle ID are still available without permission.
    ///
    /// **Whitelist:** Some applications (Terminal, iTerm2, code editors) are whitelisted because
    /// they don't properly report focused text elements via AX API.
    ///
    /// - Returns: ActiveAppInfo if an application is active, nil if no application is frontmost
    /// - Throws: ActiveAppError if an error occurs during detection
    ///
    /// - Complexity: O(1) - Direct system API calls
    func getActiveApplication() throws -> ActiveAppInfo? {
        // Get frontmost application from NSWorkspace
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        // Extract application metadata
        let appName = app.localizedName ?? "Unknown Application"
        let bundleID = app.bundleIdentifier ?? "unknown.bundle.id"

        // Whitelist of applications that accept text but don't report it via AX API
        // This includes Electron apps and terminals that don't properly support accessibility
        let alwaysAcceptsTextBundleIDs = [
            // Terminals
            "com.apple.Terminal",           // macOS Terminal
            "com.googlecode.iterm2",        // iTerm2

            // Code Editors
            "com.microsoft.VSCode",         // VS Code
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.github.atom",              // Atom
            "com.sublimetext.4",            // Sublime Text
            "com.jetbrains.intellij",       // IntelliJ IDEA
            "com.jetbrains.pycharm",        // PyCharm
            "com.jetbrains.WebStorm",       // WebStorm
            "org.vim.MacVim",               // MacVim
            "com.panic.Coda2",              // Coda
            "com.barebones.bbedit",         // BBEdit

            // Communication Apps (Electron-based)
            "com.tinyspeck.slackmacgap",    // Slack
            "com.hnc.Discord",              // Discord
            "com.microsoft.teams",          // Microsoft Teams
            "us.zoom.xos",                  // Zoom

            // Note-taking Apps
            "com.electron.notion",          // Notion
            "md.obsidian",                  // Obsidian
            "com.apple.Notes",              // Apple Notes
        ]

        // Check if this app is whitelisted
        if alwaysAcceptsTextBundleIDs.contains(bundleID) {
            print("✅ App is whitelisted for paste: \(appName) (\(bundleID))")
            return ActiveAppInfo(
                appName: appName,
                bundleID: bundleID,
                acceptsTextInput: true
            )
        }

        // Check if focused element accepts text input via AX API
        let acceptsTextInput: Bool
        do {
            acceptsTextInput = try checkFocusedElementIsTextField()
        } catch ActiveAppError.accessibilityPermissionDenied {
            // Permission denied - return app info but mark as not accepting text
            // This allows caller to show permission request dialog
            throw ActiveAppError.accessibilityPermissionDenied
        } catch {
            // AX API failed (error -25204 etc.) - likely an Electron app or other app
            // that doesn't properly report focused elements via Accessibility API.
            // Allow paste attempt and let the paste operation itself validate.
            // This provides better UX than blocking paste for apps not on whitelist.
            print("⚠️ AX API check failed for \(appName) (\(bundleID)), allowing paste attempt")
            acceptsTextInput = true
        }

        return ActiveAppInfo(
            appName: appName,
            bundleID: bundleID,
            acceptsTextInput: acceptsTextInput
        )
    }

    // MARK: - Private Methods

    /// Check if the currently focused UI element is a text field
    ///
    /// Uses NSAccessibility AX API to query the focused element and check its role.
    /// Text fields have roles: kAXTextFieldRole, kAXTextAreaRole, or kAXComboBoxRole.
    ///
    /// - Returns: true if focused element is a text field, false otherwise
    /// - Throws: ActiveAppError.accessibilityPermissionDenied if permission not granted
    /// - Throws: ActiveAppError.focusedElementNotAccessible if AX API fails
    private func checkFocusedElementIsTextField() throws -> Bool {
        // Check accessibility permission before attempting AX API calls
        guard AXIsProcessTrusted() else {
            print("🔍 AX permission check failed in checkFocusedElementIsTextField")
            throw ActiveAppError.accessibilityPermissionDenied
        }

        print("🔍 Starting focused element check...")

        // Create system-wide accessibility element
        let systemElement = AXUIElementCreateSystemWide()

        // Get focused UI element
        var focusedElement: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        print("🔍 Focused element query result: \(focusedResult.rawValue)")

        // Check if we successfully got the focused element
        guard focusedResult == .success, let element = focusedElement else {
            // No focused element or AX API call failed
            print("🔍 No focused element found or AX API call failed")
            throw ActiveAppError.focusedElementNotAccessible
        }

        print("🔍 Focused element found, getting role...")

        // Get the role attribute of the focused element
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXRoleAttribute as CFString,
            &role
        )

        print("🔍 Role query result: \(roleResult.rawValue)")

        guard roleResult == .success, let roleValue = role as? String else {
            // Couldn't get role - assume not a text field
            print("⚠️ Could not get AX role for focused element")
            return false
        }

        // Debug: Log the actual role we detected
        print("🔍 Focused element AX role: \(roleValue)")

        // Check if role is one of the text input types
        let textInputRoles = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String
        ]

        let isTextInput = textInputRoles.contains(roleValue)
        print("🔍 Is text input role? \(isTextInput)")

        return isTextInput
    }
}

// MARK: - Errors

/// Errors that can occur during active application detection
enum ActiveAppError: LocalizedError, Equatable {
    case noActiveApplication
    case accessibilityPermissionDenied
    case focusedElementNotAccessible

    var errorDescription: String? {
        switch self {
        case .noActiveApplication:
            return "No active application found"
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied. speech-to-clip needs accessibility permission to detect text fields."
        case .focusedElementNotAccessible:
            return "Could not access focused UI element"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noActiveApplication:
            return "Click on a text field in another application, then try recording again."
        case .accessibilityPermissionDenied:
            return "Open System Settings → Privacy & Security → Accessibility and enable access for speech-to-clip."
        case .focusedElementNotAccessible:
            return "Try clicking on a text field in the active application, then record again."
        }
    }
}
