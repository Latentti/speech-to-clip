//
//  KeychainService.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 7.1: Implement Keychain Service
//

import Foundation
import Security

/// Error type for Keychain operations
///
/// Story 7.1: Type-safe error handling for Keychain operations
/// Follows ValidationResult pattern from Story 6.5 (LocalizedError conformance)
enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedError(OSStatus)
    case unableToConvertToString
    case unableToConvertToData

    /// Human-readable error description
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "API key not found in Keychain"
        case .duplicateItem:
            return "API key already exists for this profile"
        case .unexpectedError(let status):
            return "Keychain error: \(status)"
        case .unableToConvertToString:
            return "Unable to convert Keychain data to string"
        case .unableToConvertToData:
            return "Unable to convert API key to data"
        }
    }

    /// Recovery suggestion for the error
    var recoverySuggestion: String? {
        switch self {
        case .itemNotFound:
            return "Add an API key for this profile in Settings"
        case .duplicateItem:
            return "Use delete() first, then store()"
        case .unexpectedError:
            return "Check macOS Keychain Access app"
        default:
            return nil
        }
    }
}

/// Service for securely storing API keys in macOS Keychain
///
/// Provides secure CRUD operations for API key storage using the Security framework.
/// API keys are stored as Generic Passwords with profile-specific identifiers.
/// Follows SettingsService pattern from Story 6.4 (pure Foundation service).
///
/// **Security Features:**
/// - Keys encrypted by macOS Keychain
/// - Access control: kSecAttrAccessibleAfterFirstUnlock
/// - Keys never logged or exposed in error messages
/// - Per-profile isolation using UUID-based account identifiers
///
/// **Usage:**
/// ```swift
/// let service = KeychainService()
/// let profileID = UUID()
///
/// // Store API key
/// try service.store(apiKey: "sk-...", for: profileID)
///
/// // Retrieve API key
/// let apiKey = try service.retrieve(for: profileID)
///
/// // Delete API key
/// try service.delete(for: profileID)
/// ```
///
/// - Note: Story 7.1 - Secure Keychain storage for API keys
class KeychainService {
    // MARK: - Properties

    /// Service identifier for Keychain items
    /// Used to namespace keys within the Keychain
    private let serviceName = "com.latentti.speech-to-clip"

    // MARK: - Public Methods

    /// Store an API key in the Keychain
    ///
    /// Securely stores the API key as a Generic Password item in macOS Keychain.
    /// The key is encrypted by the system and associated with the profile UUID.
    ///
    /// - Parameters:
    ///   - apiKey: The API key string to store (never logged)
    ///   - profileID: UUID identifying the profile
    ///
    /// - Throws:
    ///   - KeychainError.duplicateItem: If a key already exists for this profile
    ///   - KeychainError.unableToConvertToData: If the string cannot be encoded
    ///   - KeychainError.unexpectedError: For other Keychain failures
    ///
    /// - Complexity: O(1) - Direct Keychain write operation
    ///
    /// **Security:** AC 1 - Stores with proper Keychain attributes
    func store(apiKey: String, for profileID: UUID) throws {
        // Convert API key to Data
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }

        // Build Keychain query with required attributes
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "profile-\(profileID.uuidString)",
            kSecAttrService as String: serviceName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Add item to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        // Handle result
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedError(status)
        }
    }

    /// Retrieve an API key from the Keychain
    ///
    /// Fetches the API key associated with the given profile UUID from Keychain.
    /// Returns the decrypted key as a String.
    ///
    /// - Parameter profileID: UUID identifying the profile
    ///
    /// - Returns: The decrypted API key string
    ///
    /// - Throws:
    ///   - KeychainError.itemNotFound: If no key exists for this profile
    ///   - KeychainError.unableToConvertToString: If data cannot be decoded
    ///   - KeychainError.unexpectedError: For other Keychain failures
    ///
    /// - Complexity: O(1) - Direct Keychain read operation
    ///
    /// **Security:** AC 2 - Retrieves stored API key correctly
    func retrieve(for profileID: UUID) throws -> String {
        // Build query to retrieve data
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "profile-\(profileID.uuidString)",
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Retrieve from Keychain
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // Handle result
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedError(status)
        }

        // Convert data to string
        guard let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.unableToConvertToString
        }

        return apiKey
    }

    /// Delete an API key from the Keychain
    ///
    /// Removes the API key associated with the given profile UUID from Keychain.
    /// Idempotent operation - succeeds even if the item doesn't exist.
    ///
    /// - Parameter profileID: UUID identifying the profile
    ///
    /// - Throws:
    ///   - KeychainError.unexpectedError: For Keychain failures other than itemNotFound
    ///
    /// - Complexity: O(1) - Direct Keychain delete operation
    ///
    /// **Security:** AC 3 - Removes key from Keychain
    /// **Note:** errSecItemNotFound is acceptable (idempotent delete)
    func delete(for profileID: UUID) throws {
        // Build query to identify item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "profile-\(profileID.uuidString)",
            kSecAttrService as String: serviceName
        ]

        // Delete from Keychain
        let status = SecItemDelete(query as CFDictionary)

        // Handle result
        // Note: errSecItemNotFound is acceptable (idempotent delete)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedError(status)
        }
    }
}
