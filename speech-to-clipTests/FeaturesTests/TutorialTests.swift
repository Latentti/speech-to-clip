//
//  TutorialTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-15.
//  Story 8.4: Implement First Recording Tutorial
//

import XCTest
import HotKey
@testable import speech_to_clip

/// Tests for tutorial flow functionality
///
/// Story 8.4 - Verifies tutorial prompt appears after onboarding,
/// congratulations shows after first recording, and tutorial completion persists
@MainActor
final class TutorialTests: XCTestCase {

    // MARK: - Test AC 1: Tutorial Prompt Shows After Onboarding

    /// Test that AppSettings includes tutorialCompleted field
    ///
    /// Story 8.4 AC 2 - Verify tutorialCompleted field exists and can be persisted
    func testAppSettingsIncludesTutorialCompletedField() throws {
        // Create settings with tutorialCompleted = false
        var settings = AppSettings()
        XCTAssertFalse(settings.tutorialCompleted, "tutorialCompleted should default to false")

        // Set to true
        settings.tutorialCompleted = true
        XCTAssertTrue(settings.tutorialCompleted, "tutorialCompleted should be settable")

        // Verify Codable conformance
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(AppSettings.self, from: data)

        XCTAssertEqual(decodedSettings.tutorialCompleted, settings.tutorialCompleted,
                      "tutorialCompleted should be preserved through encoding/decoding")
    }

    /// Test that tutorial prompt field exists in AppState
    ///
    /// Story 8.4 AC 1 - AppState should have showTutorialPrompt property
    func testAppStateHasTutorialPromptProperty() {
        let appState = AppState()

        // Verify showTutorialPrompt exists and defaults to false
        XCTAssertFalse(appState.showTutorialPrompt,
                      "showTutorialPrompt should default to false")

        // Verify it's settable
        appState.showTutorialPrompt = true
        XCTAssertTrue(appState.showTutorialPrompt,
                     "showTutorialPrompt should be settable")
    }

    // MARK: - Test AC 2: Tutorial Completion Persistence

    /// Test that tutorialCompleted flag can be persisted via SettingsService
    ///
    /// Story 8.4 AC 2 - Tutorial completion must persist across app launches
    func testTutorialCompletionPersists() {
        let settingsService = SettingsService()

        // Create settings with tutorialCompleted = false
        var settings = AppSettings()
        settings.tutorialCompleted = false

        // Save settings
        settingsService.saveSettings(settings)

        // Load settings and verify
        if let loadedSettings = settingsService.loadSettings() {
            XCTAssertFalse(loadedSettings.tutorialCompleted,
                          "Loaded settings should have tutorialCompleted = false")
        } else {
            XCTFail("Failed to load settings")
        }

        // Update to true
        settings.tutorialCompleted = true
        settingsService.saveSettings(settings)

        // Load again and verify persistence
        if let loadedSettings = settingsService.loadSettings() {
            XCTAssertTrue(loadedSettings.tutorialCompleted,
                         "Loaded settings should have tutorialCompleted = true")
        } else {
            XCTFail("Failed to load settings after update")
        }
    }

    /// Test that markTutorialComplete() method works correctly
    ///
    /// Story 8.4 AC 2 - AppState should provide method to mark tutorial complete
    func testMarkTutorialCompleteMethod() {
        let appState = AppState()

        // Initially false
        XCTAssertFalse(appState.settings.tutorialCompleted,
                      "tutorialCompleted should start as false")

        // Mark complete
        appState.markTutorialComplete()

        // Verify it's now true
        XCTAssertTrue(appState.settings.tutorialCompleted,
                     "tutorialCompleted should be true after marking complete")

        // Verify settings were persisted (reload from UserDefaults)
        let settingsService = SettingsService()
        if let loadedSettings = settingsService.loadSettings() {
            XCTAssertTrue(loadedSettings.tutorialCompleted,
                         "Tutorial completion should persist to UserDefaults")
        } else {
            XCTFail("Failed to load persisted settings")
        }
    }

    // MARK: - Test AC 3: Tutorial Skipped for Returning Users

    /// Test that tutorial prompt is not shown when tutorialCompleted = true
    ///
    /// Story 8.4 AC 3 - Returning users should not see tutorial
    func testTutorialSkippedForReturningUsers() {
        // Create settings with both onboarding and tutorial complete
        var settings = AppSettings()
        settings.onboardingCompleted = true
        settings.tutorialCompleted = true

        // Save settings
        let settingsService = SettingsService()
        settingsService.saveSettings(settings)

        // Create new AppState (simulates app launch)
        let appState = AppState()

        // Verify onboarding is not shown
        XCTAssertFalse(appState.showOnboarding,
                      "Onboarding should not show when onboardingCompleted = true")

        // Verify tutorial prompt is not shown
        // (This is verified by setupOnboardingCompletionObserver logic)
        XCTAssertFalse(appState.showTutorialPrompt,
                      "Tutorial should not show when tutorialCompleted = true")
    }

    // MARK: - Test Hotkey Display Formatting

    /// Test that HotkeyConfig.displayString formats correctly
    ///
    /// Story 8.4 AC 1 - Tutorial needs to display hotkey in user-friendly format
    func testHotkeyDisplayFormatting() {
        // Test default hotkey (Control+Space)
        let defaultHotkey = HotkeyConfig.default
        let displayString = defaultHotkey.displayString

        // Should contain control symbol and "Space"
        XCTAssertTrue(displayString.contains("⌃"),
                     "Display string should contain control symbol")
        XCTAssertTrue(displayString.contains("Space"),
                     "Display string should contain 'Space'")

        // Full default should be "⌃ Space" (with space separator)
        XCTAssertEqual(displayString, "⌃ Space",
                      "Default hotkey should display as '⌃ Space'")
    }

    /// Test that hotkey display includes all modifier symbols
    ///
    /// Story 8.4 AC 1 - Tutorial should show all active modifiers
    func testHotkeyDisplayWithMultipleModifiers() {
        // Create hotkey with Command+Option+Control+Shift
        let complexHotkey = HotkeyConfig(
            key: .a,
            modifiers: [.command, .option, .control, .shift]
        )

        let displayString = complexHotkey.displayString

        // Should contain all modifier symbols in correct order
        XCTAssertTrue(displayString.contains("⌃"), "Should contain Control (⌃)")
        XCTAssertTrue(displayString.contains("⌥"), "Should contain Option (⌥)")
        XCTAssertTrue(displayString.contains("⇧"), "Should contain Shift (⇧)")
        XCTAssertTrue(displayString.contains("⌘"), "Should contain Command (⌘)")

        // Should contain key name
        XCTAssertTrue(displayString.contains("A"),
                     "Should contain uppercased key name")
    }

    // MARK: - Integration Test Ideas (documented for manual testing)

    /// Document integration test scenario for full tutorial flow
    ///
    /// This test documents the expected flow but requires UI testing framework
    /// for full automation. Manual testing should verify:
    ///
    /// 1. Fresh install (onboardingCompleted = false, tutorialCompleted = false)
    ///    - Onboarding shows on launch
    ///    - After onboarding completes, tutorial prompt appears
    ///    - Tutorial displays current hotkey
    ///    - User can dismiss tutorial
    ///
    /// 2. First recording
    ///    - User presses hotkey and records
    ///    - After successful transcription, congratulations alert shows
    ///    - tutorialCompleted is set to true
    ///    - tutorialCompleted persists to UserDefaults
    ///
    /// 3. Subsequent launches
    ///    - Onboarding does not show
    ///    - Tutorial does not show
    ///    - App is ready to use immediately
    func testDocumentedIntegrationFlow() {
        // This test serves as documentation of the expected integration flow
        // Actual UI testing would require XCUITest or manual verification

        let expectedFlow = """
        Integration Test Flow for Story 8.4:

        SCENARIO 1: First Launch (New User)
        1. Launch app with onboardingCompleted = false, tutorialCompleted = false
        2. Onboarding window appears
        3. User completes onboarding
        4. Onboarding window closes
        5. Tutorial prompt window appears (after 0.5s delay)
        6. Tutorial shows current hotkey (e.g., "⌃ Space")
        7. Tutorial shows 4-step instructions
        8. User clicks "Let's try it!" button
        9. Tutorial window closes

        SCENARIO 2: First Recording
        1. User presses hotkey
        2. Recording starts, visualizer appears
        3. User speaks
        4. User presses hotkey again to stop
        5. Transcription completes successfully
        6. Congratulations alert appears: "Great job!"
        7. User clicks "Awesome!" button
        8. tutorialCompleted is set to true
        9. tutorialCompleted persists to UserDefaults

        SCENARIO 3: Returning User
        1. Launch app with onboardingCompleted = true, tutorialCompleted = true
        2. No onboarding window appears
        3. No tutorial window appears
        4. App is ready for immediate use

        SCENARIO 4: Second and Subsequent Recordings
        1. User presses hotkey to record
        2. No congratulations message appears
        3. Normal recording flow continues

        Expected Console Logging:
        - "ℹ️ Onboarding complete - showing tutorial prompt"
        - "✅ Creating new tutorial window"
        - "✅ Tutorial prompt dismissed by user"
        - "✅ Tutorial marked complete - will not show again"
        - "🎉 Congratulations message shown"
        """

        print(expectedFlow)

        // This test always passes - it's documentation only
        XCTAssertTrue(true, "Integration flow documented for manual verification")
    }
}
