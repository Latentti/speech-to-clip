//
//  AppStateTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 1.5: Set Up Testing Infrastructure
//

import XCTest
@testable import speech_to_clip

/// Unit tests for AppState initialization and default values
///
/// @MainActor is required because AppState is marked with @MainActor
/// for thread safety. This ensures all test methods run on the main actor.
@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Initialization Tests

    /// Test that AppState initializes with correct default values
    ///
    /// Verifies:
    /// - recordingState defaults to .idle
    /// - currentProfile is nil (no profile selected)
    /// - isProcessing is false (no operations in progress)
    /// - lastError is nil (no errors)
    /// - settings has correct defaults (no active profile, launch at login off, notifications on)
    func testInitialization() async throws {
        // Given: Create a new AppState instance
        let appState = AppState()

        // Then: Verify all properties have correct default values

        // Recording state should be idle (not recording)
        XCTAssertEqual(appState.recordingState, .idle,
                      "AppState should initialize with .idle recording state")

        // No profile should be selected initially
        XCTAssertNil(appState.currentProfile,
                    "AppState should initialize with no active profile")

        // No operations in progress
        XCTAssertFalse(appState.isProcessing,
                      "AppState should initialize with isProcessing = false")

        // No errors initially
        XCTAssertNil(appState.lastError,
                    "AppState should initialize with no error")

        // Verify settings defaults
        XCTAssertNil(appState.settings.activeProfileID,
                    "Settings should initialize with no active profile ID")

        XCTAssertFalse(appState.settings.launchAtLogin,
                      "Settings should initialize with launchAtLogin = false")

        XCTAssertTrue(appState.settings.showNotifications,
                     "Settings should initialize with showNotifications = true")
    }

    // MARK: - Future Test Ideas
    // These will be implemented in future stories as functionality is added:

    // func testRecordingStateTransitions() async throws
    // func testPublishedPropertyUpdates() async throws
    // func testErrorHandling() async throws
    // func testProfileSwitching() async throws
}
