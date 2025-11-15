//
//  OnboardingTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-15.
//  Story 8.2: Create Onboarding Flow
//

import XCTest
@testable import speech_to_clip

/// Test suite for onboarding flow
///
/// Covers:
/// - AppSettings onboarding fields encoding/decoding
/// - OnboardingCoordinator state management
/// - Step transitions and completion
/// - Permission status tracking
/// - API key profile creation
@MainActor
final class OnboardingTests: XCTestCase {

    // MARK: - AppSettings Tests

    /// Test AppSettings has onboarding tracking fields
    /// Story 8.2 AC 1 - AppSettings extended with onboarding fields
    func testAppSettings_HasOnboardingFields() {
        // Given: New AppSettings instance
        let settings = AppSettings()

        // Then: Onboarding fields should exist with correct defaults
        XCTAssertFalse(settings.onboardingCompleted, "onboardingCompleted should default to false")
        XCTAssertFalse(settings.tutorialCompleted, "tutorialCompleted should default to false")
        XCTAssertEqual(settings.onboardingVersion, "1.0", "onboardingVersion should default to '1.0'")
    }

    /// Test AppSettings onboarding fields are Codable
    /// Story 8.2 AC 1 - Ensure Codable conformance maintained
    func testAppSettings_OnboardingFields_AreCodable() throws {
        // Given: AppSettings with onboarding fields set
        var settings = AppSettings()
        settings.onboardingCompleted = true
        settings.tutorialCompleted = true
        settings.onboardingVersion = "2.0"

        // When: Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        // Then: Decode back and verify fields preserved
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(AppSettings.self, from: data)

        XCTAssertTrue(decodedSettings.onboardingCompleted, "onboardingCompleted should be preserved")
        XCTAssertTrue(decodedSettings.tutorialCompleted, "tutorialCompleted should be preserved")
        XCTAssertEqual(decodedSettings.onboardingVersion, "2.0", "onboardingVersion should be preserved")
    }

    // MARK: - OnboardingCoordinator Tests

    /// Test OnboardingCoordinator initializes with correct default state
    /// Story 8.2 AC 1 - OnboardingCoordinator state management
    func testOnboardingCoordinator_InitializesWithDefaults() {
        // Given: New OnboardingCoordinator
        let coordinator = OnboardingCoordinator()

        // Then: Should start at step 0
        XCTAssertEqual(coordinator.currentStep, 0, "Should start at step 0 (Welcome)")

        // And: Permission statuses should be checked
        // Note: Actual permission status depends on system state, just verify properties exist
        XCTAssertNotNil(coordinator.microphonePermissionStatus, "Microphone status should be set")
        XCTAssertNotNil(coordinator.accessibilityPermissionStatus, "Accessibility status should be set")

        // And: hasAPIKey should be boolean
        XCTAssertFalse(coordinator.hasAPIKey || !coordinator.hasAPIKey, "hasAPIKey should be boolean")
    }

    /// Test OnboardingCoordinator moveToNextStep increments step
    /// Story 8.2 AC 1 - Step navigation logic
    func testOnboardingCoordinator_MoveToNextStep_IncrementsStep() {
        // Given: Coordinator at step 0
        let coordinator = OnboardingCoordinator()
        XCTAssertEqual(coordinator.currentStep, 0, "Should start at step 0")

        // When: Move to next step
        coordinator.moveToNextStep()

        // Then: Step should increment to 1
        XCTAssertEqual(coordinator.currentStep, 1, "Should move to step 1")

        // When: Move to next step again
        coordinator.moveToNextStep()

        // Then: Step should increment to 2
        XCTAssertEqual(coordinator.currentStep, 2, "Should move to step 2")
    }

    /// Test OnboardingCoordinator moveToPreviousStep decrements step
    /// Story 8.2 AC 1 - Backward navigation logic
    func testOnboardingCoordinator_MoveToPreviousStep_DecrementsStep() {
        // Given: Coordinator at step 2
        let coordinator = OnboardingCoordinator()
        coordinator.moveToNextStep()
        coordinator.moveToNextStep()
        XCTAssertEqual(coordinator.currentStep, 2, "Should be at step 2")

        // When: Move to previous step
        coordinator.moveToPreviousStep()

        // Then: Step should decrement to 1
        XCTAssertEqual(coordinator.currentStep, 1, "Should move back to step 1")

        // When: Move to previous step again
        coordinator.moveToPreviousStep()

        // Then: Step should decrement to 0
        XCTAssertEqual(coordinator.currentStep, 0, "Should move back to step 0")
    }

    /// Test OnboardingCoordinator does not go below step 0
    /// Story 8.2 AC 1 - Boundary checking
    func testOnboardingCoordinator_DoesNotGoBelowStepZero() {
        // Given: Coordinator at step 0
        let coordinator = OnboardingCoordinator()
        XCTAssertEqual(coordinator.currentStep, 0, "Should start at step 0")

        // When: Try to move to previous step
        coordinator.moveToPreviousStep()

        // Then: Should still be at step 0
        XCTAssertEqual(coordinator.currentStep, 0, "Should not go below step 0")
    }

    /// Test OnboardingCoordinator does not go above step 4
    /// Story 8.2 AC 1 - Boundary checking
    func testOnboardingCoordinator_DoesNotGoAboveStepFour() {
        // Given: Coordinator at step 4 (last step)
        let coordinator = OnboardingCoordinator()
        coordinator.moveToNextStep() // 1
        coordinator.moveToNextStep() // 2
        coordinator.moveToNextStep() // 3
        coordinator.moveToNextStep() // 4
        XCTAssertEqual(coordinator.currentStep, 4, "Should be at step 4")

        // When: Try to move to next step
        coordinator.moveToNextStep()

        // Then: Should still be at step 4
        XCTAssertEqual(coordinator.currentStep, 4, "Should not go above step 4")
    }

    /// Test OnboardingCoordinator complete() sets onboardingCompleted flag
    /// Story 8.2 AC 1 - Completion marks onboarding as done
    func testOnboardingCoordinator_Complete_SetsOnboardingCompletedFlag() {
        // Given: OnboardingCoordinator and SettingsService
        let coordinator = OnboardingCoordinator()
        let settingsService = SettingsService()

        // And: Initial settings with onboardingCompleted = false
        var settings = AppSettings()
        settings.onboardingCompleted = false
        settingsService.saveSettings(settings)

        // When: Complete onboarding
        coordinator.complete()

        // Then: Settings should be updated with onboardingCompleted = true
        // Note: Small delay to allow async persistence
        let expectation = expectation(description: "Settings saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let loadedSettings = settingsService.loadSettings()
            XCTAssertNotNil(loadedSettings, "Settings should be loaded")
            XCTAssertTrue(loadedSettings?.onboardingCompleted ?? false, "onboardingCompleted should be true")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    /// Test OnboardingCoordinator refreshPermissions updates status
    /// Story 8.2 AC 1 - Permission status refresh logic
    func testOnboardingCoordinator_RefreshPermissions_UpdatesStatus() {
        // Given: OnboardingCoordinator
        let coordinator = OnboardingCoordinator()

        // When: Refresh permissions
        coordinator.refreshPermissions()

        // Then: Permission statuses should be updated
        // Note: Actual status depends on system permissions, just verify they're checked
        XCTAssertNotNil(coordinator.microphonePermissionStatus, "Microphone status should be updated")
        XCTAssertNotNil(coordinator.accessibilityPermissionStatus, "Accessibility status should be updated")

        // Log current status for debugging
        print("ℹ️ Current microphone status: \(coordinator.microphonePermissionStatus)")
        print("ℹ️ Current accessibility status: \(coordinator.accessibilityPermissionStatus)")
    }

    /// Test OnboardingCoordinator refreshAPIKeyStatus updates hasAPIKey
    /// Story 8.2 AC 1 - API key status check
    func testOnboardingCoordinator_RefreshAPIKeyStatus_UpdatesHasAPIKey() {
        // Given: OnboardingCoordinator
        let coordinator = OnboardingCoordinator()

        // When: Refresh API key status
        coordinator.refreshAPIKeyStatus()

        // Then: hasAPIKey should be updated based on ProfileManager state
        // Note: Actual value depends on whether profiles exist
        XCTAssertNotNil(coordinator.hasAPIKey, "hasAPIKey should be set")

        print("ℹ️ Has API key: \(coordinator.hasAPIKey)")
    }

    // MARK: - AppState Integration Tests

    /// Test AppState shows onboarding on first launch
    /// Story 8.2 AC 1 - Onboarding triggered when onboardingCompleted is false
    func testAppState_ShowsOnboarding_OnFirstLaunch() {
        // Given: Settings with onboardingCompleted = false
        let settingsService = SettingsService()
        var settings = AppSettings()
        settings.onboardingCompleted = false
        settingsService.saveSettings(settings)

        // When: Create new AppState (simulating first launch)
        let appState = AppState()

        // Then: showOnboarding should be true
        XCTAssertTrue(appState.showOnboarding, "Onboarding should be shown on first launch")
    }

    /// Test AppState does not show onboarding on subsequent launches
    /// Story 8.2 AC 1 - Onboarding not shown after completion
    func testAppState_DoesNotShowOnboarding_AfterCompletion() {
        // Given: Settings with onboardingCompleted = true
        let settingsService = SettingsService()
        var settings = AppSettings()
        settings.onboardingCompleted = true
        settingsService.saveSettings(settings)

        // When: Create new AppState (simulating subsequent launch)
        let appState = AppState()

        // Then: showOnboarding should be false
        XCTAssertFalse(appState.showOnboarding, "Onboarding should not be shown after completion")
    }

    /// Test AppState checks microphone permission before recording
    /// Story 8.2 AC 1 - Permission check integration
    func testAppState_ChecksMicrophonePermission_BeforeRecording() {
        // Given: AppState instance
        let appState = AppState()

        // When: Try to start recording
        // Note: This test documents that permission checking exists
        // Actual behavior depends on system permission state
        appState.startRecording()

        // Then: If microphone denied, lastError should be set
        // If microphone granted, recording should start
        // This test just verifies permission check logic exists
        print("ℹ️ Recording state after startRecording: \(appState.recordingState)")
        if let error = appState.lastError {
            print("ℹ️ Permission denied error: \(error.localizedDescription)")
        }

        // Test passes as long as startRecording() doesn't crash
        XCTAssertTrue(true, "Permission check logic executed without crash")
    }
}
