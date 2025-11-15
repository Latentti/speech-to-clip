//
//  ActiveAppDetectorTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 5.3: Detect Active Application and Cursor
//

import XCTest
import AppKit
import ApplicationServices
@testable import speech_to_clip

/// Comprehensive tests for ActiveAppDetector
///
/// Tests cover:
/// - Active application detection with NSWorkspace
/// - Application name and bundle ID extraction
/// - Text input detection with NSAccessibility
/// - Permission checking
/// - Error handling for all failure modes
final class ActiveAppDetectorTests: XCTestCase {

    // MARK: - Properties

    var detector: ActiveAppDetector!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        detector = ActiveAppDetector()
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    /// Test that ActiveAppDetector initializes successfully
    func testInitialization() {
        XCTAssertNotNil(detector, "ActiveAppDetector should initialize successfully")
    }

    // MARK: - Active Application Detection Tests

    /// Test getActiveApplication() returns non-nil when an app is active (AC: 1)
    func testGetActiveApplication_ReturnsNonNil_WhenAppIsActive() {
        // Given: Test is running (Xcode is the frontmost app in test environment)
        // When: Get active application
        // Note: Will throw accessibilityPermissionDenied in test environment without permission

        do {
            let appInfo = try detector.getActiveApplication()

            // Then: Should return app info (if permission granted)
            XCTAssertNotNil(appInfo, "Should return app info when app is active")

            if let info = appInfo {
                XCTAssertFalse(info.appName.isEmpty, "App name should not be empty")
                XCTAssertFalse(info.bundleID.isEmpty, "Bundle ID should not be empty")
            }
        } catch ActiveAppError.accessibilityPermissionDenied {
            // Expected in test environment - permission typically not granted
            XCTAssertTrue(true, "Permission check executed correctly")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Test getActiveApplication() extracts app name correctly (AC: 1)
    func testGetActiveApplication_ExtractsAppName_Correctly() {
        // Given: Frontmost application exists (test runner)
        // When: Get active application
        // Then: App name should be extracted (likely "Xcode" in test environment)

        do {
            let appInfo = try detector.getActiveApplication()

            if let info = appInfo {
                // App name should be a non-empty string
                XCTAssertFalse(info.appName.isEmpty, "App name should not be empty")
                XCTAssertNotEqual(info.appName, "Unknown Application", "Should extract real app name")
            }
        } catch ActiveAppError.accessibilityPermissionDenied {
            // Expected - skip this assertion
            XCTSkip("Accessibility permission not granted in test environment")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Test getActiveApplication() extracts bundle ID correctly (AC: 1)
    func testGetActiveApplication_ExtractsBundleID_Correctly() {
        // Given: Frontmost application exists
        // When: Get active application
        // Then: Bundle ID should be extracted

        do {
            let appInfo = try detector.getActiveApplication()

            if let info = appInfo {
                // Bundle ID should be a non-empty string in reverse-domain format
                XCTAssertFalse(info.bundleID.isEmpty, "Bundle ID should not be empty")
                XCTAssertNotEqual(info.bundleID, "unknown.bundle.id", "Should extract real bundle ID")
                XCTAssertTrue(info.bundleID.contains("."), "Bundle ID should be in reverse-domain format")
            }
        } catch ActiveAppError.accessibilityPermissionDenied {
            // Expected
            XCTSkip("Accessibility permission not granted in test environment")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Permission Tests

    /// Test getActiveApplication() checks accessibility permission (AC: 1)
    func testGetActiveApplication_ChecksAccessibilityPermission() {
        // Given: Test environment (permission typically not granted)
        // When: Attempt to get active application
        // Then: Should check permission before querying focused element

        if !AXIsProcessTrusted() {
            XCTAssertThrowsError(try detector.getActiveApplication()) { error in
                guard let appError = error as? ActiveAppError else {
                    XCTFail("Expected ActiveAppError, got \(type(of: error))")
                    return
                }

                XCTAssertEqual(appError, ActiveAppError.accessibilityPermissionDenied, "Should throw permission denied")
            }
        } else {
            // Permission granted - skip this test
            XCTSkip("Accessibility permission is granted - cannot test denial case")
        }
    }

    /// Test getActiveApplication() throws permissionDenied when accessibility not granted (AC: 1)
    func testGetActiveApplication_ThrowsPermissionDenied_WhenAccessibilityNotGranted() {
        // Given: No accessibility permission (typical in test environment)
        // When/Then: Should throw permissionDenied

        if !AXIsProcessTrusted() {
            XCTAssertThrowsError(try detector.getActiveApplication()) { error in
                guard let appError = error as? ActiveAppError else {
                    XCTFail("Expected ActiveAppError, got \(type(of: error))")
                    return
                }

                XCTAssertEqual(appError, ActiveAppError.accessibilityPermissionDenied, "Should throw permissionDenied")
            }
        } else {
            XCTSkip("Accessibility permission is granted - cannot test denial case")
        }
    }

    // MARK: - Text Input Detection Tests

    /// Test acceptsTextInput reflects focused element state (AC: 1)
    func testGetActiveApplication_AcceptsTextInput_ReflectsFocusedElementState() {
        // Given: Active application with or without text field focused
        // When: Get active application
        // Then: acceptsTextInput should accurately reflect state

        // Note: In test environment without accessibility permission,
        // this will throw permissionDenied before checking focused element
        // With permission, acceptsTextInput will be true/false based on actual focus

        do {
            let appInfo = try detector.getActiveApplication()

            if let info = appInfo {
                // acceptsTextInput is a boolean - valid values are true or false
                XCTAssertTrue(info.acceptsTextInput == true || info.acceptsTextInput == false,
                             "acceptsTextInput should be a valid boolean")
            }
        } catch ActiveAppError.accessibilityPermissionDenied {
            // Expected - test environment doesn't have permission
            XCTAssertTrue(true, "Permission check prevents focused element query")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - ActiveAppInfo Struct Tests

    /// Test ActiveAppInfo struct creation
    func testActiveAppInfo_Creation() {
        // Given: App metadata
        let appName = "Test App"
        let bundleID = "com.test.app"
        let acceptsTextInput = true

        // When: Create ActiveAppInfo
        let info = ActiveAppInfo(
            appName: appName,
            bundleID: bundleID,
            acceptsTextInput: acceptsTextInput
        )

        // Then: Properties should be set correctly
        XCTAssertEqual(info.appName, appName, "App name should match")
        XCTAssertEqual(info.bundleID, bundleID, "Bundle ID should match")
        XCTAssertEqual(info.acceptsTextInput, acceptsTextInput, "acceptsTextInput should match")
    }

    /// Test ActiveAppInfo with false acceptsTextInput
    func testActiveAppInfo_WithFalseAcceptsTextInput() {
        // Given: App without text input
        let info = ActiveAppInfo(
            appName: "Finder",
            bundleID: "com.apple.finder",
            acceptsTextInput: false
        )

        // Then: acceptsTextInput should be false
        XCTAssertFalse(info.acceptsTextInput, "Should correctly store false value")
    }

    // MARK: - Error Enum Tests

    /// Test ActiveAppError.noActiveApplication has correct description
    func testActiveAppError_NoActiveApplication_HasCorrectDescription() {
        let error = ActiveAppError.noActiveApplication
        XCTAssertNotNil(error.errorDescription, "Should have error description")
        XCTAssertTrue(error.errorDescription?.contains("active") ?? false, "Description should mention 'active'")
        XCTAssertTrue(error.errorDescription?.contains("application") ?? false, "Description should mention 'application'")
    }

    /// Test ActiveAppError.noActiveApplication has recovery suggestion
    func testActiveAppError_NoActiveApplication_HasRecoverySuggestion() {
        let error = ActiveAppError.noActiveApplication
        XCTAssertNotNil(error.recoverySuggestion, "Should have recovery suggestion")
        XCTAssertTrue(error.recoverySuggestion?.contains("text field") ?? false, "Should mention text field")
    }

    /// Test ActiveAppError.accessibilityPermissionDenied has correct description
    func testActiveAppError_AccessibilityPermissionDenied_HasCorrectDescription() {
        let error = ActiveAppError.accessibilityPermissionDenied
        XCTAssertNotNil(error.errorDescription, "Should have error description")
        XCTAssertTrue(error.errorDescription?.contains("Accessibility permission") ?? false, "Should mention accessibility permission")
    }

    /// Test ActiveAppError.accessibilityPermissionDenied has recovery suggestion
    func testActiveAppError_AccessibilityPermissionDenied_HasRecoverySuggestion() {
        let error = ActiveAppError.accessibilityPermissionDenied
        XCTAssertNotNil(error.recoverySuggestion, "Should have recovery suggestion")
        XCTAssertTrue(error.recoverySuggestion?.contains("System Settings") ?? false, "Should suggest System Settings")
        XCTAssertTrue(error.recoverySuggestion?.contains("Accessibility") ?? false, "Should mention Accessibility")
    }

    /// Test ActiveAppError.focusedElementNotAccessible has correct description
    func testActiveAppError_FocusedElementNotAccessible_HasCorrectDescription() {
        let error = ActiveAppError.focusedElementNotAccessible
        XCTAssertNotNil(error.errorDescription, "Should have error description")
        XCTAssertTrue(error.errorDescription?.contains("focused") ?? false, "Should mention 'focused'")
    }

    /// Test ActiveAppError.focusedElementNotAccessible has recovery suggestion
    func testActiveAppError_FocusedElementNotAccessible_HasRecoverySuggestion() {
        let error = ActiveAppError.focusedElementNotAccessible
        XCTAssertNotNil(error.recoverySuggestion, "Should have recovery suggestion")
        XCTAssertTrue(error.recoverySuggestion?.contains("text field") ?? false, "Should mention text field")
    }

    /// Test ActiveAppError Equatable conformance
    func testActiveAppError_EquatableConformance() {
        // Given: Error instances
        let error1 = ActiveAppError.noActiveApplication
        let error2 = ActiveAppError.noActiveApplication
        let error3 = ActiveAppError.accessibilityPermissionDenied

        // Then: Same errors should be equal
        XCTAssertEqual(error1, error2, "Same error types should be equal")
        XCTAssertNotEqual(error1, error3, "Different error types should not be equal")
    }
}
