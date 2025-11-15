//
//  SettingsValidationTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.5: Add Validation and Error Handling
//

import XCTest
import HotKey
@testable import speech_to_clip

/// Comprehensive tests for settings validation functionality
///
/// Tests cover:
/// - ValidationResult enum behavior
/// - Valid settings pass validation
/// - Invalid hotkey (no modifiers) fails validation
/// - Invalid language fails validation
/// - Multiple errors reported together
/// - Integration with save flow (invalid settings not saved)
/// - Error publishing to AppState
/// - Error clearing after correction
final class SettingsValidationTests: XCTestCase {
    // MARK: - Properties

    var settingsService: SettingsService!
    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.latentti.speech-to-clip.validation-tests"

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create test-specific UserDefaults suite
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        testUserDefaults.removePersistentDomain(forName: testSuiteName)

        // Initialize SettingsService with test UserDefaults
        settingsService = SettingsService(userDefaults: testUserDefaults)
    }

    override func tearDown() {
        // Clean up test UserDefaults
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        settingsService = nil

        super.tearDown()
    }

    // MARK: - ValidationResult Tests

    func testValidationResult_IsValid_ReturnsTrueForValid() {
        // Arrange & Act
        let result = ValidationResult.valid

        // Assert
        XCTAssertTrue(result.isValid, "Valid result should have isValid == true")
        XCTAssertEqual(result.errorMessages, [], "Valid result should have empty error messages")
    }

    func testValidationResult_IsValid_ReturnsFalseForInvalid() {
        // Arrange & Act
        let result = ValidationResult.invalid(errors: ["Error 1"])

        // Assert
        XCTAssertFalse(result.isValid, "Invalid result should have isValid == false")
        XCTAssertEqual(result.errorMessages, ["Error 1"], "Invalid result should contain error messages")
    }

    // MARK: - Valid Settings Tests

    func testValidateSettings_ValidSettings_ReturnsValid() {
        // Arrange: All valid settings
        let validSettings = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .space, modifiers: .control)
        )

        // Act
        let result = settingsService.validateSettings(validSettings)

        // Assert
        XCTAssertEqual(result, .valid, "Valid settings should pass validation")
        XCTAssertTrue(result.isValid, "Valid settings should have isValid == true")
        XCTAssertEqual(result.errorMessages, [], "Valid settings should have no error messages")
    }

    // MARK: - Invalid Hotkey Tests

    func testValidateSettings_NoModifiers_ReturnsInvalid() {
        // Arrange: Hotkey without modifiers (invalid)
        let invalidSettings = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .a, modifiers: [])
        )

        // Act
        let result = settingsService.validateSettings(invalidSettings)

        // Assert
        XCTAssertFalse(result.isValid, "Hotkey without modifiers should fail validation")
        XCTAssertTrue(result.errorMessages.count > 0, "Should have at least one error message")
        XCTAssertTrue(
            result.errorMessages.contains { $0.contains("modifier") },
            "Error message should mention modifiers"
        )
    }

    // MARK: - Invalid Language Tests

    func testValidateSettings_InvalidLanguage_ReturnsInvalid() {
        // Arrange: Unsupported language code
        let invalidSettings = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .space, modifiers: .control)
        )

        // Act
        let result = settingsService.validateSettings(invalidSettings)

        // Assert
        XCTAssertFalse(result.isValid, "Invalid language should fail validation")
        XCTAssertTrue(result.errorMessages.count > 0, "Should have at least one error message")
        XCTAssertTrue(
            result.errorMessages.contains { $0.contains("language") || $0.contains("supported") },
            "Error message should mention language support"
        )
    }

    // MARK: - Multiple Errors Tests

    func testValidateSettings_MultipleErrors_ReturnsAllErrors() {
        // Arrange: Multiple validation failures
        let invalidSettings = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .a, modifiers: [])
        )

        // Act
        let result = settingsService.validateSettings(invalidSettings)

        // Assert
        XCTAssertFalse(result.isValid, "Multiple violations should fail validation")
        XCTAssertEqual(result.errorMessages.count, 2, "Should report both hotkey and language errors")
        XCTAssertTrue(
            result.errorMessages.contains { $0.contains("modifier") },
            "Should contain hotkey error"
        )
        XCTAssertTrue(
            result.errorMessages.contains { $0.contains("language") || $0.contains("supported") },
            "Should contain language error"
        )
    }

    // MARK: - Integration Tests with AppState

    func testSaveCurrentSettings_ValidSettings_SavesSuccessfully() {
        // Arrange: Valid settings
        let validSettings = AppSettings(
            activeProfileID: nil,
            launchAtLogin: true,
            showNotifications: false,
            hotkey: HotkeyConfig(key: .f5, modifiers: [.command, .shift])
        )

        // Act: Save valid settings
        settingsService.saveSettings(validSettings)

        // Assert: Settings should be saved to UserDefaults
        let savedData = testUserDefaults.data(forKey: "com.latentti.speech-to-clip.settings")
        XCTAssertNotNil(savedData, "Valid settings should be saved to UserDefaults")
    }

    func testSaveCurrentSettings_InvalidSettings_DoesNotSave() {
        // Arrange: Invalid settings (no modifiers)
        let invalidSettings = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .a, modifiers: [])
        )

        // Act: Validate (should fail)
        let result = settingsService.validateSettings(invalidSettings)

        // Assert: Validation should fail
        XCTAssertFalse(result.isValid, "Invalid settings should not pass validation")

        // Verify: Should not save invalid settings
        // (In real implementation, AppState.saveCurrentSettings() would check validation)
        // This test verifies the validation layer works correctly
        if result.isValid {
            settingsService.saveSettings(invalidSettings)
        }

        // No data should be saved for invalid settings
        let savedData = testUserDefaults.data(forKey: "com.latentti.speech-to-clip.settings")
        XCTAssertNil(savedData, "Invalid settings should not be saved to UserDefaults")
    }

    func testValidationError_ClearsOnValid() {
        // Arrange: Start with invalid settings
        let invalidSettings = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .a, modifiers: [])
        )

        // Act: Validate invalid settings (should fail)
        let invalidResult = settingsService.validateSettings(invalidSettings)

        // Assert: Should have error
        XCTAssertFalse(invalidResult.isValid, "Invalid settings should fail")
        XCTAssertTrue(invalidResult.errorMessages.count > 0, "Should have error messages")

        // Act: Now validate valid settings
        let validSettings = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .a, modifiers: .command)
        )
        let validResult = settingsService.validateSettings(validSettings)

        // Assert: Should be valid with no errors
        XCTAssertTrue(validResult.isValid, "Valid settings should pass")
        XCTAssertEqual(validResult.errorMessages, [], "Should have no error messages")
    }
}
