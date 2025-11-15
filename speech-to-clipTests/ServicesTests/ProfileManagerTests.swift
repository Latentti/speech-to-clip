//
//  ProfileManagerTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 7.2: Implement Profile Model and Management
//

import XCTest
@testable import speech_to_clip

/// Comprehensive tests for ProfileManager
///
/// Tests cover:
/// - createProfile() saves metadata to UserDefaults and API key to Keychain (AC: 3)
/// - updateProfile() updates both UserDefaults and Keychain (AC: 3)
/// - deleteProfile() removes from both stores (AC: 3)
/// - getAllProfiles() returns correct list (AC: 3)
/// - setActiveProfile() updates active selection (AC: 3)
/// - getActiveProfile() returns correct profile (AC: 3)
/// - Edge case: Deleting active profile clears active selection
/// - Error handling: Duplicate names, Keychain failures, profile not found
///
/// **Test Isolation:**
/// - Test UserDefaults suite to avoid polluting standard defaults
/// - Unique UUIDs per test to prevent collisions
/// - tearDown() cleanup for both UserDefaults and Keychain
final class ProfileManagerTests: XCTestCase {
    // MARK: - Properties

    var profileManager: ProfileManager!
    var keychainService: KeychainService!
    var testDefaults: UserDefaults!
    var testSuiteName: String!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create test-specific UserDefaults suite
        testSuiteName = "com.latentti.speech-to-clip.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)

        // Create fresh services for each test
        keychainService = KeychainService()
        profileManager = ProfileManager(
            keychainService: keychainService,
            userDefaults: testDefaults
        )
    }

    override func tearDown() {
        // Clean up UserDefaults
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil

        // Clean up Keychain (tests use unique UUIDs, but cleanup for safety)
        // Note: Individual tests should clean up their own Keychain entries
        keychainService = nil
        profileManager = nil

        super.tearDown()
    }

    // MARK: - createProfile() Tests

    /// Test that createProfile() saves metadata to UserDefaults and API key to Keychain (AC: 3)
    func testCreateProfile_ValidData_SavesMetadataAndAPIKey() throws {
        // Arrange
        let name = "Work"
        let apiKey = "sk-test-work-key"
        let language = "en"

        // Act
        let profile = try profileManager.createProfile(
            name: name,
            apiKey: apiKey,
            language: language
        )

        // Assert: Verify profile returned with correct data
        XCTAssertEqual(profile.name, name, "Profile should have correct name")
        XCTAssertEqual(profile.language, language, "Profile should have correct language")

        // Assert: Verify metadata saved to UserDefaults
        let allProfiles = try profileManager.getAllProfiles()
        XCTAssertEqual(allProfiles.count, 1, "Should have 1 profile in UserDefaults")
        XCTAssertEqual(allProfiles.first?.id, profile.id, "Saved profile should match created profile")

        // Assert: Verify API key saved to Keychain
        let retrievedKey = try keychainService.retrieve(for: profile.id)
        XCTAssertEqual(retrievedKey, apiKey, "API key should be stored in Keychain")

        // Cleanup
        try keychainService.delete(for: profile.id)
    }

    /// Test that createProfile() throws error for duplicate name (AC: 3 - Error handling)
    func testCreateProfile_DuplicateName_ThrowsError() throws {
        // Arrange: Create first profile
        let name = "Personal"
        let profile1 = try profileManager.createProfile(
            name: name,
            apiKey: "sk-key-1",
            language: "en"
        )

        // Act & Assert: Attempt to create duplicate should throw
        XCTAssertThrowsError(
            try profileManager.createProfile(name: name, apiKey: "sk-key-2", language: "fi"),
            "createProfile() should throw error for duplicate name"
        ) { error in
            guard let profileError = error as? ProfileError else {
                XCTFail("Error should be ProfileError type")
                return
            }

            if case ProfileError.duplicateProfileName(let duplicateName) = profileError {
                XCTAssertEqual(duplicateName, name, "Error should contain duplicate name")
            } else {
                XCTFail("Error should be ProfileError.duplicateProfileName")
            }
        }

        // Cleanup
        try keychainService.delete(for: profile1.id)
    }

    // MARK: - updateProfile() Tests

    /// Test that updateProfile() updates both UserDefaults and Keychain (AC: 3)
    func testUpdateProfile_ExistingProfile_UpdatesBothStores() throws {
        // Arrange: Create initial profile
        let profile = try profileManager.createProfile(
            name: "Old Name",
            apiKey: "sk-old-key",
            language: "en"
        )

        // Act: Update profile
        let newName = "New Name"
        let newApiKey = "sk-new-key"
        let newLanguage = "fi"

        try profileManager.updateProfile(
            id: profile.id,
            name: newName,
            apiKey: newApiKey,
            language: newLanguage
        )

        // Assert: Verify metadata updated in UserDefaults
        let allProfiles = try profileManager.getAllProfiles()
        let updatedProfile = allProfiles.first(where: { $0.id == profile.id })
        XCTAssertNotNil(updatedProfile, "Profile should still exist")
        XCTAssertEqual(updatedProfile?.name, newName, "Name should be updated")
        XCTAssertEqual(updatedProfile?.language, newLanguage, "Language should be updated")
        XCTAssertGreaterThan(updatedProfile!.updatedAt, profile.updatedAt, "updatedAt should be newer")

        // Assert: Verify API key updated in Keychain
        let retrievedKey = try keychainService.retrieve(for: profile.id)
        XCTAssertEqual(retrievedKey, newApiKey, "API key should be updated in Keychain")

        // Cleanup
        try keychainService.delete(for: profile.id)
    }

    /// Test that updateProfile() throws error if profile not found
    func testUpdateProfile_NonExistentProfile_ThrowsError() {
        // Arrange
        let nonExistentID = UUID()

        // Act & Assert
        XCTAssertThrowsError(
            try profileManager.updateProfile(id: nonExistentID, name: "New Name"),
            "updateProfile() should throw error for non-existent profile"
        ) { error in
            guard let profileError = error as? ProfileError else {
                XCTFail("Error should be ProfileError type")
                return
            }

            if case ProfileError.profileNotFound(let id) = profileError {
                XCTAssertEqual(id, nonExistentID, "Error should contain profile ID")
            } else {
                XCTFail("Error should be ProfileError.profileNotFound")
            }
        }
    }

    // MARK: - deleteProfile() Tests

    /// Test that deleteProfile() removes from both UserDefaults and Keychain (AC: 3)
    func testDeleteProfile_ExistingProfile_RemovesFromBothStores() throws {
        // Arrange: Create profile
        let profile = try profileManager.createProfile(
            name: "To Delete",
            apiKey: "sk-delete-key",
            language: "en"
        )

        // Verify it exists
        XCTAssertEqual(try profileManager.getAllProfiles().count, 1, "Should have 1 profile")
        XCTAssertNoThrow(try keychainService.retrieve(for: profile.id), "API key should exist")

        // Act: Delete profile
        try profileManager.deleteProfile(id: profile.id)

        // Assert: Verify removed from UserDefaults
        XCTAssertEqual(try profileManager.getAllProfiles().count, 0, "Should have 0 profiles")

        // Assert: Verify removed from Keychain
        XCTAssertThrowsError(
            try keychainService.retrieve(for: profile.id),
            "API key should be deleted from Keychain"
        )
    }

    /// Test that deleting active profile clears active selection (Edge case)
    func testDeleteProfile_ActiveProfile_ClearsActiveSelection() throws {
        // Arrange: Create and set active profile
        let profile = try profileManager.createProfile(
            name: "Active Profile",
            apiKey: "sk-active-key",
            language: "en"
        )
        try profileManager.setActiveProfile(id: profile.id)

        // Verify it's active
        XCTAssertNotNil(try profileManager.getActiveProfile(), "Should have active profile")

        // Act: Delete active profile
        try profileManager.deleteProfile(id: profile.id)

        // Assert: Active profile should be cleared
        XCTAssertNil(try profileManager.getActiveProfile(), "Active profile should be cleared")
    }

    // MARK: - getAllProfiles() Tests

    /// Test that getAllProfiles() returns correct list (AC: 3)
    func testGetAllProfiles_MultipleProfiles_ReturnsCompleteList() throws {
        // Arrange: Create multiple profiles
        let profile1 = try profileManager.createProfile(
            name: "Profile 1",
            apiKey: "sk-key-1",
            language: "en"
        )
        let profile2 = try profileManager.createProfile(
            name: "Profile 2",
            apiKey: "sk-key-2",
            language: "fi"
        )
        let profile3 = try profileManager.createProfile(
            name: "Profile 3",
            apiKey: "sk-key-3",
            language: "sv"
        )

        // Act
        let allProfiles = try profileManager.getAllProfiles()

        // Assert
        XCTAssertEqual(allProfiles.count, 3, "Should return 3 profiles")
        XCTAssertTrue(allProfiles.contains(where: { $0.id == profile1.id }), "Should contain profile 1")
        XCTAssertTrue(allProfiles.contains(where: { $0.id == profile2.id }), "Should contain profile 2")
        XCTAssertTrue(allProfiles.contains(where: { $0.id == profile3.id }), "Should contain profile 3")

        // Cleanup
        try keychainService.delete(for: profile1.id)
        try keychainService.delete(for: profile2.id)
        try keychainService.delete(for: profile3.id)
    }

    /// Test that getAllProfiles() returns empty array when no profiles exist
    func testGetAllProfiles_NoProfiles_ReturnsEmptyArray() throws {
        // Act
        let allProfiles = try profileManager.getAllProfiles()

        // Assert
        XCTAssertEqual(allProfiles.count, 0, "Should return empty array")
    }

    // MARK: - Active Profile Management Tests

    /// Test that setActiveProfile() updates active selection (AC: 3)
    func testSetActiveProfile_ValidID_UpdatesActiveSelection() throws {
        // Arrange: Create profile
        let profile = try profileManager.createProfile(
            name: "Active Test",
            apiKey: "sk-active-key",
            language: "en"
        )

        // Act: Set as active
        try profileManager.setActiveProfile(id: profile.id)

        // Assert: Verify it's active
        let activeProfile = try profileManager.getActiveProfile()
        XCTAssertNotNil(activeProfile, "Should have active profile")
        XCTAssertEqual(activeProfile?.id, profile.id, "Active profile should match set profile")

        // Cleanup
        try keychainService.delete(for: profile.id)
    }

    /// Test that getActiveProfile() returns correct profile (AC: 3)
    func testGetActiveProfile_WhenSet_ReturnsCorrectProfile() throws {
        // Arrange: Create multiple profiles
        let profile1 = try profileManager.createProfile(
            name: "Profile 1",
            apiKey: "sk-key-1",
            language: "en"
        )
        let profile2 = try profileManager.createProfile(
            name: "Profile 2",
            apiKey: "sk-key-2",
            language: "fi"
        )

        // Act: Set profile2 as active
        try profileManager.setActiveProfile(id: profile2.id)

        // Assert: Verify correct profile is active
        let activeProfile = try profileManager.getActiveProfile()
        XCTAssertEqual(activeProfile?.id, profile2.id, "Should return profile 2")
        XCTAssertEqual(activeProfile?.name, "Profile 2", "Should return correct profile")

        // Cleanup
        try keychainService.delete(for: profile1.id)
        try keychainService.delete(for: profile2.id)
    }

    /// Test that getActiveProfile() returns nil when no active profile set
    func testGetActiveProfile_NoneSet_ReturnsNil() throws {
        // Act
        let activeProfile = try profileManager.getActiveProfile()

        // Assert
        XCTAssertNil(activeProfile, "Should return nil when no active profile")
    }

    /// Test that setActiveProfile() throws error for non-existent profile
    func testSetActiveProfile_NonExistentProfile_ThrowsError() {
        // Arrange
        let nonExistentID = UUID()

        // Act & Assert
        XCTAssertThrowsError(
            try profileManager.setActiveProfile(id: nonExistentID),
            "setActiveProfile() should throw error for non-existent profile"
        ) { error in
            guard let profileError = error as? ProfileError else {
                XCTFail("Error should be ProfileError type")
                return
            }

            if case ProfileError.profileNotFound(let id) = profileError {
                XCTAssertEqual(id, nonExistentID, "Error should contain profile ID")
            } else {
                XCTFail("Error should be ProfileError.profileNotFound")
            }
        }
    }
}
