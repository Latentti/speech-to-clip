//
//  Profile.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 7.2: Implement Profile Model and Management
//

import Foundation

/// API key profile model
///
/// Represents a user profile containing API key metadata and language preferences.
/// Profile metadata is stored in UserDefaults while API keys are securely stored
/// in Keychain via KeychainService (Story 7.1).
///
/// **Data Separation:**
/// - UserDefaults: id, name, language, createdAt, updatedAt
/// - Keychain: API key (via KeychainService using profile ID)
///
/// **Usage:**
/// ```swift
/// let profile = Profile(
///     id: UUID(),
///     name: "Work",
///     language: "en"
/// )
///
/// // Get Keychain key for this profile
/// let key = profile.keychainKey // "profile-{UUID}"
/// ```
///
/// - Note: Story 7.2 AC 1, 2 - Profile model with metadata and Keychain integration
struct Profile: Identifiable, Codable, Equatable {
    // MARK: - Properties

    /// Unique identifier for the profile
    let id: UUID

    /// User-facing name (e.g., "Personal", "Work")
    var name: String

    /// Default language for this profile (e.g., "en", "fi")
    var language: String

    /// Timestamp when profile was created
    let createdAt: Date

    /// Timestamp when profile was last modified
    var updatedAt: Date

    // MARK: - Computed Properties

    /// Keychain account identifier for this profile's API key
    ///
    /// Returns the Keychain account key in the format "profile-{UUID}"
    /// matching KeychainService expectations.
    ///
    /// - Returns: String in format "profile-{uuidString}"
    ///
    /// - Note: Story 7.2 AC 1 - Computed property for Keychain lookup
    var keychainKey: String {
        "profile-\(id.uuidString)"
    }

    // MARK: - Initialization

    /// Create a new profile
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: User-facing name
    ///   - language: Default language code
    ///   - createdAt: Creation timestamp (defaults to now)
    ///   - updatedAt: Last update timestamp (defaults to now)
    init(
        id: UUID = UUID(),
        name: String,
        language: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
