//
//  SettingsServiceTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.4: Implement Settings Persistence
//

import XCTest
import HotKey
@testable import speech_to_clip

/// Comprehensive tests for SettingsService
///
/// Tests cover:
/// - saveSettings() writes to UserDefaults
/// - loadSettings() reads from UserDefaults
/// - Round-trip persistence (save → load → verify)
/// - Graceful failure on missing data (first launch)
/// - Graceful failure on corrupted data (invalid JSON)
/// - All AppSettings properties persist correctly
/// - HotkeyConfig with custom modifiers persists correctly
/// - Complex modifier combinations persist correctly
final class SettingsServiceTests: XCTestCase {
    // MARK: - Properties

    var settingsService: SettingsService!
    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.latentti.speech-to-clip.tests"

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create test-specific UserDefaults suite to avoid polluting real settings
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

    // MARK: - saveSettings() Tests

    /// Test that saveSettings() writes data to UserDefaults (AC: 1, 2)
    func testSaveSettings_WritesToUserDefaults() {
        // Arrange: Create test settings with non-default values
        let testSettings = AppSettings(
            activeProfileID: UUID(),
            launchAtLogin: true,
            showNotifications: false,
            hotkey: HotkeyConfig(key: .a, modifiers: .command)
        )

        // Act: Save settings
        settingsService.saveSettings(testSettings)

        // Assert: Verify data was written to UserDefaults
        let savedData = testUserDefaults.data(forKey: "com.latentti.speech-to-clip.settings")
        XCTAssertNotNil(savedData, "Settings data should be written to UserDefaults")
        XCTAssertTrue(savedData!.count > 0, "Settings data should not be empty")
    }

    // MARK: - loadSettings() Tests

    /// Test that loadSettings() reads data from UserDefaults (AC: 1, 2)
    func testLoadSettings_ReadsFromUserDefaults() {
        // Arrange: Save settings first
        let original = AppSettings(
            activeProfileID: UUID(),
            launchAtLogin: true,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .space, modifiers: [.command, .option])
        )
        settingsService.saveSettings(original)

        // Act: Load settings
        let loaded = settingsService.loadSettings()

        // Assert: Verify settings were loaded
        XCTAssertNotNil(loaded, "Settings should be loaded from UserDefaults")
    }

    /// Test that loadSettings() returns nil when no data exists (AC: 4)
    /// First launch scenario - graceful handling
    func testLoadSettings_ReturnsNilIfNoData() {
        // Arrange: Empty UserDefaults (no data saved)

        // Act: Try to load settings
        let loaded = settingsService.loadSettings()

        // Assert: Should return nil gracefully (not crash)
        XCTAssertNil(loaded, "loadSettings() should return nil when no data exists")
    }

    /// Test that loadSettings() returns nil when data is corrupted (AC: 4)
    /// Invalid JSON scenario - graceful degradation
    func testLoadSettings_ReturnsNilIfCorruptData() {
        // Arrange: Write invalid JSON data to UserDefaults
        let corruptData = "{ invalid json }".data(using: .utf8)!
        testUserDefaults.set(corruptData, forKey: "com.latentti.speech-to-clip.settings")

        // Act: Try to load settings
        let loaded = settingsService.loadSettings()

        // Assert: Should return nil gracefully (not crash)
        XCTAssertNil(loaded, "loadSettings() should return nil when data is corrupted")
    }

    // MARK: - Round-Trip Persistence Tests

    /// Test that save → load preserves all properties (AC: 1)
    /// Verifies complete persistence of all AppSettings fields
    func testRoundTrip_SaveAndLoad_PreservesAllProperties() {
        // Arrange: Create settings with all properties set to non-default values
        let profileID = UUID()
        let original = AppSettings(
            activeProfileID: profileID,
            launchAtLogin: true,
            showNotifications: false,
            hotkey: HotkeyConfig(key: .f5, modifiers: [.command, .shift])
        )

        // Act: Save and then load
        settingsService.saveSettings(original)
        let loaded = settingsService.loadSettings()

        // Assert: All properties should match original
        XCTAssertNotNil(loaded, "Settings should be loaded successfully")
        XCTAssertEqual(loaded!.activeProfileID, profileID, "activeProfileID should persist")
        XCTAssertEqual(loaded!.launchAtLogin, true, "launchAtLogin should persist")
        XCTAssertEqual(loaded!.showNotifications, false, "showNotifications should persist")
        XCTAssertEqual(loaded!.hotkey.key, .f5, "hotkey key should persist")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.command), "hotkey command modifier should persist")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.shift), "hotkey shift modifier should persist")
    }

    /// Test that HotkeyConfig with custom modifiers persists correctly (AC: 1)
    /// Integration test for Story 6.3 Codable implementation
    func testSaveSettings_PreservesHotkeyConfig() {
        // Arrange: Create settings with custom hotkey
        let original = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(key: .downArrow, modifiers: [.option, .control])
        )

        // Act: Save and load
        settingsService.saveSettings(original)
        let loaded = settingsService.loadSettings()

        // Assert: HotkeyConfig should be fully preserved
        XCTAssertNotNil(loaded, "Settings should load successfully")
        XCTAssertEqual(loaded!.hotkey.key, .downArrow, "Custom hotkey key should persist")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.option), "Option modifier should persist")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.control), "Control modifier should persist")
        XCTAssertFalse(loaded!.hotkey.modifiers.contains(.command), "Command modifier should not be present")
    }

    /// Test that complex hotkey with multiple modifiers persists correctly (AC: 1)
    /// Edge case: All four modifiers combined
    func testSaveSettings_HandlesMultipleModifiers() {
        // Arrange: Create hotkey with all four modifiers
        let original = AppSettings(
            activeProfileID: nil,
            launchAtLogin: false,
            showNotifications: true,
            hotkey: HotkeyConfig(
                key: .space,
                modifiers: [.command, .option, .control, .shift]
            )
        )

        // Act: Save and load
        settingsService.saveSettings(original)
        let loaded = settingsService.loadSettings()

        // Assert: All four modifiers should persist
        XCTAssertNotNil(loaded, "Settings should load successfully")
        XCTAssertEqual(loaded!.hotkey.key, .space, "Key should be Space")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.command), "Command should persist")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.option), "Option should persist")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.control), "Control should persist")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.shift), "Shift should persist")
    }

    // MARK: - Default Hotkey Tests

    /// Test that default hotkey (Control+Space) works correctly (AC: 1, 4)
    /// Verifies Story 6.3 default configuration persists
    func testLoadSettings_FallsBackToDefaultHotkey() {
        // Arrange: Create settings with default hotkey
        let original = AppSettings() // Uses default HotkeyConfig

        // Act: Save and load
        settingsService.saveSettings(original)
        let loaded = settingsService.loadSettings()

        // Assert: Default hotkey should persist
        XCTAssertNotNil(loaded, "Settings should load successfully")
        XCTAssertEqual(loaded!.hotkey.key, .space, "Default hotkey key should be Space")
        XCTAssertTrue(loaded!.hotkey.modifiers.contains(.control), "Default should have Control modifier")
        XCTAssertFalse(loaded!.hotkey.modifiers.contains(.command), "Default should not have Command")
    }
}
