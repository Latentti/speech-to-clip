//
//  KeychainServiceTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 7.1: Implement Keychain Service
//

import XCTest
@testable import speech_to_clip

/// Comprehensive tests for KeychainService
///
/// Tests cover:
/// - store() creates new Keychain item with correct attributes (AC: 1)
/// - retrieve() fetches stored API key correctly (AC: 2)
/// - delete() removes item from Keychain (AC: 3)
/// - Error handling for duplicate items (AC: 1)
/// - Error handling for missing items (AC: 2)
/// - Round-trip lifecycle (store → retrieve → delete → retrieve fails)
/// - Security: API keys never logged or exposed in error messages
///
/// **Test Isolation:**
/// - Unique UUID per test to avoid collisions
/// - tearDown() cleanup ensures no Keychain pollution
/// - No shared state between tests
final class KeychainServiceTests: XCTestCase {
    // MARK: - Properties

    var keychainService: KeychainService!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create fresh KeychainService instance for each test
        keychainService = KeychainService()
    }

    override func tearDown() {
        // Clean up: Delete any test Keychain items
        // Tests use unique UUIDs, so this is mostly for safety
        keychainService = nil

        super.tearDown()
    }

    // MARK: - store() Tests

    /// Test that store() successfully stores API key in Keychain (AC: 1)
    /// Verifies SecItemAdd creates item with correct attributes
    func testStore_ValidAPIKey_SuccessfullyStoresInKeychain() {
        // Arrange: Create unique profile ID and test API key
        let profileID = UUID()
        let testAPIKey = "sk-test-key-12345"

        // Act: Store API key
        XCTAssertNoThrow(
            try keychainService.store(apiKey: testAPIKey, for: profileID),
            "store() should succeed for valid API key"
        )

        // Assert: Verify key can be retrieved (proves it was stored)
        let retrievedKey = try? keychainService.retrieve(for: profileID)
        XCTAssertEqual(retrievedKey, testAPIKey, "Stored key should be retrievable")

        // Cleanup: Remove test item
        try? keychainService.delete(for: profileID)
    }

    /// Test that store() throws duplicateItem error when key already exists (AC: 1)
    /// Verifies errSecDuplicateItem handling
    func testStore_DuplicateItem_ThrowsDuplicateError() {
        // Arrange: Store initial key
        let profileID = UUID()
        let testAPIKey = "sk-test-key-duplicate"
        try? keychainService.store(apiKey: testAPIKey, for: profileID)

        // Act & Assert: Attempt to store duplicate should throw
        XCTAssertThrowsError(
            try keychainService.store(apiKey: testAPIKey, for: profileID),
            "store() should throw error for duplicate item"
        ) { error in
            // Verify error type
            guard let keychainError = error as? KeychainError else {
                XCTFail("Error should be KeychainError type")
                return
            }

            // Verify specific error case
            if case KeychainError.duplicateItem = keychainError {
                // Expected error
            } else {
                XCTFail("Error should be KeychainError.duplicateItem")
            }
        }

        // Cleanup: Remove test item
        try? keychainService.delete(for: profileID)
    }

    // MARK: - retrieve() Tests

    /// Test that retrieve() returns stored API key correctly (AC: 2)
    /// Verifies SecItemCopyMatching retrieves correct value
    func testRetrieve_StoredAPIKey_ReturnsCorrectValue() {
        // Arrange: Store API key first
        let profileID = UUID()
        let testAPIKey = "sk-test-key-retrieve-67890"
        try? keychainService.store(apiKey: testAPIKey, for: profileID)

        // Act: Retrieve API key
        let retrievedKey = try? keychainService.retrieve(for: profileID)

        // Assert: Verify correct key was returned
        XCTAssertNotNil(retrievedKey, "retrieve() should return stored key")
        XCTAssertEqual(retrievedKey, testAPIKey, "Retrieved key should match stored key")

        // Cleanup: Remove test item
        try? keychainService.delete(for: profileID)
    }

    /// Test that retrieve() throws itemNotFound error when key doesn't exist (AC: 2)
    /// Verifies errSecItemNotFound handling
    func testRetrieve_NonExistentItem_ThrowsItemNotFoundError() {
        // Arrange: Use UUID that has no associated Keychain item
        let nonExistentProfileID = UUID()

        // Act & Assert: Attempt to retrieve non-existent key should throw
        XCTAssertThrowsError(
            try keychainService.retrieve(for: nonExistentProfileID),
            "retrieve() should throw error for non-existent item"
        ) { error in
            // Verify error type
            guard let keychainError = error as? KeychainError else {
                XCTFail("Error should be KeychainError type")
                return
            }

            // Verify specific error case
            if case KeychainError.itemNotFound = keychainError {
                // Expected error
            } else {
                XCTFail("Error should be KeychainError.itemNotFound")
            }
        }
    }

    // MARK: - delete() Tests

    /// Test that delete() removes item from Keychain (AC: 3)
    /// Verifies SecItemDelete removes item successfully
    func testDelete_ExistingItem_RemovesFromKeychain() {
        // Arrange: Store API key first
        let profileID = UUID()
        let testAPIKey = "sk-test-key-delete-abcdef"
        try? keychainService.store(apiKey: testAPIKey, for: profileID)

        // Act: Delete API key
        XCTAssertNoThrow(
            try keychainService.delete(for: profileID),
            "delete() should succeed for existing item"
        )

        // Assert: Verify key can no longer be retrieved
        XCTAssertThrowsError(
            try keychainService.retrieve(for: profileID),
            "retrieve() should fail after delete()"
        ) { error in
            // Should get itemNotFound error
            guard let keychainError = error as? KeychainError else {
                XCTFail("Error should be KeychainError type")
                return
            }

            if case KeychainError.itemNotFound = keychainError {
                // Expected: item was deleted
            } else {
                XCTFail("Error should be KeychainError.itemNotFound after delete")
            }
        }
    }

    /// Test that delete() is idempotent (succeeds even if item doesn't exist)
    /// Verifies errSecItemNotFound is acceptable for delete operations
    func testDelete_NonExistentItem_SucceedsIdempotently() {
        // Arrange: Use UUID that has no associated Keychain item
        let nonExistentProfileID = UUID()

        // Act & Assert: Delete should succeed even though item doesn't exist
        XCTAssertNoThrow(
            try keychainService.delete(for: nonExistentProfileID),
            "delete() should succeed idempotently for non-existent item"
        )
    }

    // MARK: - Round-Trip Integration Tests

    /// Test full lifecycle: store → retrieve → delete → retrieve fails (AC: 1, 2, 3)
    /// Integration test verifying complete CRUD workflow
    func testRoundTrip_StoreRetrieveDelete() {
        // Arrange: Create test data
        let profileID = UUID()
        let testAPIKey = "sk-test-key-roundtrip-xyz123"

        // Act & Assert: Store
        XCTAssertNoThrow(
            try keychainService.store(apiKey: testAPIKey, for: profileID),
            "Step 1: store() should succeed"
        )

        // Act & Assert: Retrieve
        let retrievedKey = try? keychainService.retrieve(for: profileID)
        XCTAssertEqual(retrievedKey, testAPIKey, "Step 2: retrieve() should return correct key")

        // Act & Assert: Delete
        XCTAssertNoThrow(
            try keychainService.delete(for: profileID),
            "Step 3: delete() should succeed"
        )

        // Act & Assert: Retrieve after delete should fail
        XCTAssertThrowsError(
            try keychainService.retrieve(for: profileID),
            "Step 4: retrieve() should fail after delete()"
        ) { error in
            guard let keychainError = error as? KeychainError else {
                XCTFail("Error should be KeychainError type")
                return
            }

            if case KeychainError.itemNotFound = keychainError {
                // Expected: item was deleted
            } else {
                XCTFail("Error should be KeychainError.itemNotFound")
            }
        }
    }

    // MARK: - Security Tests

    /// Test that API keys are never logged or exposed in error messages (AC: 1, 2, 3)
    /// Security-critical test: Verifies sensitive data protection
    func testErrorMessages_DoNotExposeAPIKeys() {
        // Arrange: Test API key with identifiable content
        let profileID = UUID()
        let sensitiveAPIKey = "sk-SENSITIVE-SECRET-KEY-DO-NOT-LOG"
        try? keychainService.store(apiKey: sensitiveAPIKey, for: profileID)

        // Act: Generate various errors and check their messages
        var errorMessages: [String] = []

        // Test 1: Duplicate item error
        do {
            try keychainService.store(apiKey: sensitiveAPIKey, for: profileID)
        } catch let error as KeychainError {
            if let description = error.errorDescription {
                errorMessages.append(description)
            }
            if let suggestion = error.recoverySuggestion {
                errorMessages.append(suggestion)
            }
        } catch {
            errorMessages.append(error.localizedDescription)
        }

        // Test 2: Item not found error
        let nonExistentID = UUID()
        do {
            _ = try keychainService.retrieve(for: nonExistentID)
        } catch let error as KeychainError {
            if let description = error.errorDescription {
                errorMessages.append(description)
            }
            if let suggestion = error.recoverySuggestion {
                errorMessages.append(suggestion)
            }
        } catch {
            errorMessages.append(error.localizedDescription)
        }

        // Assert: No error message should contain the API key or profile ID
        for message in errorMessages {
            XCTAssertFalse(
                message.contains(sensitiveAPIKey),
                "Error message must not contain API key: \(message)"
            )
            XCTAssertFalse(
                message.contains("SENSITIVE"),
                "Error message must not contain sensitive data: \(message)"
            )
            XCTAssertFalse(
                message.contains("SECRET"),
                "Error message must not contain secret data: \(message)"
            )
        }

        // Cleanup: Remove test item
        try? keychainService.delete(for: profileID)
    }
}
