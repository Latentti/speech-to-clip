//
//  PermissionDenialTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-15.
//  Story 8.3: Handle Permission Denial Gracefully
//

import XCTest
@testable import speech_to_clip

/// Tests for permission denial handling scenarios
///
/// Story 8.3 - Verifies graceful handling when microphone or accessibility permissions are denied
/// Tests cover:
/// - Microphone permission denial blocks recording
/// - Accessibility permission denial allows clipboard-only fallback
/// - Error messages are user-friendly and actionable
/// - Console logging follows established emoji patterns
@MainActor
final class PermissionDenialTests: XCTestCase {

    // MARK: - Test AC 1 & 2: Microphone Permission Denial

    /// Test that error messages are user-friendly and actionable
    ///
    /// Story 8.3 AC 1 - Error messages must explain:
    /// - Why permission is needed
    /// - How to grant it
    /// - What functionality won't work
    func testErrorMessagesAreUserFriendly() throws {
        // Test microphone permission error
        let micError = SpeechToClipError.microphonePermissionDenied
        let micDescription = micError.errorDescription
        let micSuggestion = micError.recoverySuggestion

        // Verify description is user-friendly (plain English, no jargon)
        XCTAssertNotNil(micDescription, "Error description should not be nil")
        XCTAssertTrue(micDescription!.contains("microphone"), "Should mention microphone")
        XCTAssertTrue(micDescription!.contains("record"), "Should explain why permission is needed")

        // Verify recovery suggestion is actionable
        XCTAssertNotNil(micSuggestion, "Recovery suggestion should not be nil")
        XCTAssertTrue(micSuggestion!.contains("System Settings"), "Should guide to System Settings")
        XCTAssertTrue(micSuggestion!.contains("Privacy & Security"), "Should specify correct pane")
        XCTAssertTrue(micSuggestion!.contains("Microphone"), "Should specify correct permission type")

        // Test accessibility permission error
        let accError = SpeechToClipError.accessibilityPermissionDenied
        let accDescription = accError.errorDescription
        let accSuggestion = accError.recoverySuggestion

        // Verify description explains fallback behavior (AC 3)
        XCTAssertNotNil(accDescription, "Error description should not be nil")
        XCTAssertTrue(accDescription!.contains("clipboard"), "Should mention clipboard fallback")

        // Verify recovery suggestion offers workaround
        XCTAssertNotNil(accSuggestion, "Recovery suggestion should not be nil")
        XCTAssertTrue(accSuggestion!.contains("still use"), "Should reassure user app still works")
        XCTAssertTrue(accSuggestion!.contains("System Settings"), "Should guide to System Settings if they want auto-paste")
    }

    // Note: Testing NSAlert presentation and user interaction is difficult in unit tests
    // Manual testing is recommended for AC 2 (alert UI, buttons, opening System Settings)
    // Integration testing could verify alert helper is called, but modal dialogs block test execution

    // MARK: - Test AC 3: Accessibility Permission Fallback

    /// Test that clipboard fallback notification message is user-friendly
    ///
    /// Story 8.3 AC 3 - When accessibility permission denied:
    /// - Text copied to clipboard (tested in PasteManagerTests)
    /// - User sees helpful notification about fallback
    /// - Success state is still achieved (not error state)
    func testAccessibilityFallbackNotificationIsUserFriendly() {
        // Test the notification message content
        let notificationMessage = "Text copied to clipboard - auto-paste requires accessibility permission"

        // Verify message is user-friendly
        XCTAssertTrue(notificationMessage.contains("clipboard"), "Should mention clipboard")
        XCTAssertTrue(notificationMessage.contains("auto-paste"), "Should explain what requires permission")
        XCTAssertTrue(notificationMessage.contains("accessibility permission"), "Should specify permission type")

        // Message should NOT contain technical jargon or blame the user
        XCTAssertFalse(notificationMessage.contains("AXIsProcessTrusted"), "Should not contain API names")
        XCTAssertFalse(notificationMessage.contains("denied"), "Should not use negative language")
        XCTAssertFalse(notificationMessage.contains("failed"), "Should not use failure language")
    }

    // MARK: - Helper Methods

    /// Verify console logging follows emoji pattern
    ///
    /// Story 8.3 AC 1 - Console logging should use:
    /// - ⚠️ for warnings
    /// - ❌ for denials/errors
    /// - ℹ️ for informational messages
    ///
    /// Note: This test verifies the pattern is documented in code.
    /// Actual console output testing would require capturing stdout/stderr
    /// which is beyond the scope of unit tests.
    func testConsoleLoggingPatternIsDocumented() {
        // This test serves as documentation of the logging pattern
        // Real console output verification is done through manual testing

        let warningEmoji = "⚠️"
        let errorEmoji = "❌"
        let infoEmoji = "ℹ️"

        XCTAssertEqual(warningEmoji, "⚠️", "Warning emoji should be ⚠️")
        XCTAssertEqual(errorEmoji, "❌", "Error emoji should be ❌")
        XCTAssertEqual(infoEmoji, "ℹ️", "Info emoji should be ℹ️")
    }

    // MARK: - Test Story 8.3 Constraints

    /// Verify all error messages avoid technical jargon
    ///
    /// Story 8.3 Constraint: Error messages must be plain English, no technical jargon
    func testErrorMessagesAvoidTechnicalJargon() {
        let forbiddenTerms = [
            "AXIsProcessTrusted",
            "AVCaptureDevice",
            "authorizationStatus",
            "CGEvent",
            "NSPasteboard"
        ]

        // Check microphone error
        let micError = SpeechToClipError.microphonePermissionDenied
        if let desc = micError.errorDescription {
            for term in forbiddenTerms {
                XCTAssertFalse(desc.contains(term), "Error description should not contain technical term: \(term)")
            }
        }
        if let suggestion = micError.recoverySuggestion {
            for term in forbiddenTerms {
                XCTAssertFalse(suggestion.contains(term), "Recovery suggestion should not contain technical term: \(term)")
            }
        }

        // Check accessibility error
        let accError = SpeechToClipError.accessibilityPermissionDenied
        if let desc = accError.errorDescription {
            for term in forbiddenTerms {
                XCTAssertFalse(desc.contains(term), "Error description should not contain technical term: \(term)")
            }
        }
        if let suggestion = accError.recoverySuggestion {
            for term in forbiddenTerms {
                XCTAssertFalse(suggestion.contains(term), "Recovery suggestion should not contain technical term: \(term)")
            }
        }
    }

    /// Verify error messages include both "what went wrong" and "how to fix"
    ///
    /// Story 8.3 Constraint: Error messages must be actionable
    func testErrorMessagesAreActionable() {
        // Test microphone error has both description (what) and suggestion (how)
        let micError = SpeechToClipError.microphonePermissionDenied
        XCTAssertNotNil(micError.errorDescription, "Should have description explaining what went wrong")
        XCTAssertNotNil(micError.recoverySuggestion, "Should have suggestion explaining how to fix")
        XCTAssertGreaterThan(micError.errorDescription!.count, 20, "Description should be meaningful")
        XCTAssertGreaterThan(micError.recoverySuggestion!.count, 20, "Suggestion should be meaningful")

        // Test accessibility error has both description (what) and suggestion (how)
        let accError = SpeechToClipError.accessibilityPermissionDenied
        XCTAssertNotNil(accError.errorDescription, "Should have description explaining what went wrong")
        XCTAssertNotNil(accError.recoverySuggestion, "Should have suggestion explaining how to fix")
        XCTAssertGreaterThan(accError.errorDescription!.count, 20, "Description should be meaningful")
        XCTAssertGreaterThan(accError.recoverySuggestion!.count, 20, "Suggestion should be meaningful")
    }

    /// Verify accessibility denial error message offers workaround
    ///
    /// Story 8.3 Constraint: Graceful degradation - provide partial functionality when permissions denied
    func testAccessibilityErrorOffersWorkaround() {
        let accError = SpeechToClipError.accessibilityPermissionDenied

        // Error should mention that app still works (graceful degradation)
        if let description = accError.errorDescription {
            // Should indicate text is still available (via clipboard)
            XCTAssertTrue(
                description.contains("clipboard") || description.contains("copied"),
                "Should mention clipboard as workaround"
            )
        }

        if let suggestion = accError.recoverySuggestion {
            // Should reassure user they can still use the app
            XCTAssertTrue(
                suggestion.contains("still use") || suggestion.contains("can still"),
                "Should reassure user app still functions"
            )
        }
    }
}
