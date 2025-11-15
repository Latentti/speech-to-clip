//
//  OnboardingCoordinator.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-15.
//  Story 8.2: Create Onboarding Flow
//

import Foundation
import SwiftUI
import Combine

/// Coordinator for managing onboarding flow state and logic
///
/// Handles:
/// - Step navigation (5 steps total)
/// - Permission status tracking and requests
/// - API key profile creation
/// - Settings persistence (onboardingCompleted flag)
class OnboardingCoordinator: ObservableObject {
    // MARK: - Published Properties

    /// Current step index (0-4)
    @Published var currentStep: Int = 0

    /// Microphone permission status
    @Published var microphonePermissionStatus: PermissionStatus = .notDetermined

    /// Accessibility permission status
    @Published var accessibilityPermissionStatus: PermissionStatus = .notDetermined

    /// Whether user has an API key configured
    @Published var hasAPIKey: Bool = false

    // MARK: - Dependencies

    /// Permission manager for checking/requesting permissions
    private let permissionManager: PermissionManager

    /// Profile manager for creating API key profiles
    private let profileManager: ProfileManager

    /// Settings service for persisting onboarding completion
    private let settingsService: SettingsService

    // MARK: - Private Properties

    /// Timer for polling accessibility permission status
    /// (required because accessibility can't be requested programmatically)
    private var accessibilityPollTimer: Timer?

    // MARK: - Initialization

    /// Create OnboardingCoordinator with dependencies
    ///
    /// - Parameters:
    ///   - permissionManager: Service for permission checks (default: new instance)
    ///   - profileManager: Service for profile management (default: new instance)
    ///   - settingsService: Service for settings persistence (default: new instance)
    init(
        permissionManager: PermissionManager = PermissionManager(),
        profileManager: ProfileManager = ProfileManager(),
        settingsService: SettingsService = SettingsService()
    ) {
        self.permissionManager = permissionManager
        self.profileManager = profileManager
        self.settingsService = settingsService

        // Check initial permission status
        refreshPermissions()

        // Check if API key exists
        refreshAPIKeyStatus()
    }

    // MARK: - Step Navigation

    /// Move to the next step in the onboarding flow
    func moveToNextStep() {
        withAnimation {
            if currentStep < 4 {
                currentStep += 1
            }
        }

        // Start polling accessibility permission when entering step 3
        if currentStep == 2 {
            startAccessibilityPolling()
        } else {
            stopAccessibilityPolling()
        }
    }

    /// Move to the previous step
    func moveToPreviousStep() {
        withAnimation {
            if currentStep > 0 {
                currentStep -= 1
            }
        }

        // Stop polling if leaving accessibility step
        if currentStep != 2 {
            stopAccessibilityPolling()
        }
    }

    /// Skip onboarding with confirmation
    func skip() {
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Skip Onboarding?"
        alert.informativeText = "You can complete setup later from the Settings menu."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Skip")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User confirmed skip
            complete()
        }
    }

    /// Complete onboarding and mark as done
    func complete() {
        stopAccessibilityPolling()

        // Mark onboarding as completed in settings
        var settings = settingsService.loadSettings() ?? AppSettings()
        settings.onboardingCompleted = true
        settingsService.saveSettings(settings)

        print("✅ Onboarding completed")
    }

    // MARK: - Permission Management

    /// Refresh all permission statuses
    func refreshPermissions() {
        microphonePermissionStatus = permissionManager.checkPermission(for: .microphone)
        accessibilityPermissionStatus = permissionManager.checkPermission(for: .accessibility)
    }

    /// Request microphone permission
    func requestMicrophonePermission() async {
        let status = await permissionManager.requestMicrophonePermission()

        // Update status on main thread
        await MainActor.run {
            microphonePermissionStatus = status
        }
    }

    /// Open System Settings for a specific permission type
    func openSystemSettings(for type: PermissionType) {
        permissionManager.openSystemSettings(for: type)

        // Start polling accessibility permission when user goes to settings
        if type == .accessibility {
            startAccessibilityPolling()
        }
    }

    /// Start polling accessibility permission status
    ///
    /// Required because accessibility permission can only be granted manually in System Settings.
    /// Polls every 1 second while on the accessibility step.
    private func startAccessibilityPolling() {
        // Stop any existing timer
        stopAccessibilityPolling()

        // Create timer that fires every 1 second
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let newStatus = self.permissionManager.checkPermission(for: .accessibility)

            // Only update if status changed
            if newStatus != self.accessibilityPermissionStatus {
                DispatchQueue.main.async {
                    self.accessibilityPermissionStatus = newStatus
                }
            }
        }
    }

    /// Stop polling accessibility permission status
    private func stopAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
    }

    // MARK: - API Key Management

    /// Refresh API key status (check if user has any profiles)
    func refreshAPIKeyStatus() {
        do {
            let profiles = try profileManager.getAllProfiles()
            hasAPIKey = !profiles.isEmpty
        } catch {
            print("⚠️ Failed to check API key status: \(error.localizedDescription)")
            hasAPIKey = false
        }
    }

    /// Save API key and create profile
    ///
    /// - Parameters:
    ///   - apiKey: The OpenAI API key
    ///   - profileName: Name for the profile
    /// - Throws: ProfileError if profile creation fails
    func saveAPIKey(_ apiKey: String, profileName: String) throws {
        // Validate API key format (basic check)
        guard !apiKey.isEmpty else {
            throw ProfileError.invalidProfileData
        }

        // Create profile with API key
        let profile = try profileManager.createProfile(
            name: profileName,
            apiKey: apiKey,
            language: WhisperLanguage.english.rawValue
        )

        // Set as active profile
        try profileManager.setActiveProfile(id: profile.id)

        // Update status
        refreshAPIKeyStatus()

        print("✅ API key profile created and activated: \(profileName)")
    }

    // MARK: - Cleanup

    deinit {
        stopAccessibilityPolling()
    }
}

// MARK: - Preview Support

#if DEBUG
extension OnboardingCoordinator {
    /// Preview coordinator with mock state
    static var preview: OnboardingCoordinator {
        let coordinator = OnboardingCoordinator()
        coordinator.microphonePermissionStatus = .notDetermined
        coordinator.accessibilityPermissionStatus = .notDetermined
        coordinator.hasAPIKey = false
        return coordinator
    }
}
#endif
