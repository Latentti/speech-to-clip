//
//  PermissionManager.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-15.
//  Story 8.1: Implement Permission Check Logic
//

import Foundation
import AVFoundation
import ApplicationServices
import AppKit

/// Permission status enum that maps from system-specific permission states
///
/// Story 8.1 AC 1 - Unified status representation for all permission types
enum PermissionStatus {
    /// User hasn't been asked for permission yet
    case notDetermined

    /// Permission has been granted
    case authorized

    /// Permission has been denied by user
    case denied

    /// Permission is restricted (parental controls, MDM, etc.)
    case restricted
}

/// Permission type enum for identifying which system permission to check
///
/// Story 8.1 AC 1 - Type-safe permission identification
enum PermissionType {
    /// Microphone access for audio recording
    case microphone

    /// Accessibility API access for auto-paste functionality
    case accessibility
}

/// Service for checking and requesting system permissions
///
/// Story 8.1 - Implements permission checking for microphone and accessibility access.
/// Follows established service pattern (injectable, not singleton).
/// Does not throw errors - returns PermissionStatus enums (error handling in Story 8.3).
class PermissionManager {

    // MARK: - Initialization

    /// Initialize PermissionManager
    ///
    /// No dependencies required - uses system APIs directly
    init() {
        // No initialization needed
    }

    // MARK: - Permission Checking

    /// Check the current status of a specific permission
    ///
    /// Story 8.1 AC 1 - Check permission status for microphone and accessibility
    ///
    /// - Parameter type: The permission type to check
    /// - Returns: Current permission status
    func checkPermission(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .microphone:
            return checkMicrophonePermission()

        case .accessibility:
            return checkAccessibilityPermission()
        }
    }

    /// Check microphone permission status
    ///
    /// Uses AVCaptureDevice.authorizationStatus and maps to PermissionStatus
    private func checkMicrophonePermission() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        let permissionStatus: PermissionStatus
        switch status {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .authorized:
            permissionStatus = .authorized
        case .denied:
            permissionStatus = .denied
        case .restricted:
            permissionStatus = .restricted
        @unknown default:
            // Future-proof for new authorization statuses
            permissionStatus = .denied
        }

        // Log the permission check result
        switch permissionStatus {
        case .authorized:
            print("✅ Permission granted: microphone")
        case .denied:
            print("⚠️ Permission denied: microphone")
        case .notDetermined:
            print("ℹ️ Permission not determined: microphone")
        case .restricted:
            print("⚠️ Permission restricted: microphone")
        }

        return permissionStatus
    }

    /// Check accessibility permission status
    ///
    /// Uses AXIsProcessTrusted() and maps to PermissionStatus
    private func checkAccessibilityPermission() -> PermissionStatus {
        let isGranted = AXIsProcessTrusted()
        let permissionStatus: PermissionStatus = isGranted ? .authorized : .denied

        // Log the permission check result
        if isGranted {
            print("✅ Permission granted: accessibility")
        } else {
            print("⚠️ Permission denied: accessibility")
        }

        return permissionStatus
    }

    // MARK: - Permission Requesting

    /// Request microphone permission from the user
    ///
    /// Story 8.1 AC 1 - Request microphone permission programmatically
    ///
    /// Shows system permission dialog on first call. Subsequent calls return cached result.
    ///
    /// - Returns: Updated permission status after request completes
    func requestMicrophonePermission() async -> PermissionStatus {
        // Check current status first
        let currentStatus = checkMicrophonePermission()

        // If already determined (granted or denied), return immediately
        // System won't show dialog again
        if currentStatus != .notDetermined {
            print("ℹ️ Microphone permission already determined: \(currentStatus)")
            return currentStatus
        }

        print("ℹ️ Requesting microphone permission...")

        // Request permission using continuation-based async wrapper
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }

        // Return updated status
        let newStatus: PermissionStatus = granted ? .authorized : .denied

        if granted {
            print("✅ Microphone permission granted by user")
        } else {
            print("⚠️ Microphone permission denied by user")
        }

        return newStatus
    }

    // MARK: - System Settings Deep Linking

    /// Open System Settings to the relevant permission pane
    ///
    /// Story 8.1 AC 1 - Open System Settings to relevant pane if needed
    ///
    /// Uses deep link URLs to navigate directly to the correct privacy pane.
    /// Falls back to generic Security & Privacy if specific pane fails to open.
    ///
    /// - Parameter type: The permission type to open settings for
    func openSystemSettings(for type: PermissionType) {
        let urlString: String
        let permissionName: String

        switch type {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            permissionName = "microphone"

        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            permissionName = "accessibility"
        }

        guard let url = URL(string: urlString) else {
            print("❌ Failed to create URL for \(permissionName) settings")
            openGenericSecuritySettings()
            return
        }

        let success = NSWorkspace.shared.open(url)

        if success {
            print("✅ Opened System Settings for \(permissionName) permission")
        } else {
            print("⚠️ Failed to open specific settings pane, trying generic Security & Privacy")
            openGenericSecuritySettings()
        }
    }

    /// Open generic Security & Privacy settings as fallback
    private func openGenericSecuritySettings() {
        let fallbackURLString = "x-apple.systempreferences:com.apple.preference.security"

        guard let url = URL(string: fallbackURLString) else {
            print("❌ Failed to create fallback URL for Security settings")
            return
        }

        let success = NSWorkspace.shared.open(url)

        if success {
            print("✅ Opened System Settings (Security & Privacy)")
        } else {
            print("❌ Failed to open System Settings")
        }
    }

    // MARK: - Helper Methods

    /// Check if all required permissions are granted
    ///
    /// Story 8.1 AC 1 - Helper method to check both permissions at once
    ///
    /// - Returns: true if both microphone and accessibility permissions are authorized
    func areAllPermissionsGranted() -> Bool {
        let microphoneStatus = checkPermission(for: .microphone)
        let accessibilityStatus = checkPermission(for: .accessibility)

        let allGranted = (microphoneStatus == .authorized) && (accessibilityStatus == .authorized)

        if allGranted {
            print("✅ All permissions granted (microphone + accessibility)")
        } else {
            print("⚠️ Not all permissions granted - microphone: \(microphoneStatus), accessibility: \(accessibilityStatus)")
        }

        return allGranted
    }
}
