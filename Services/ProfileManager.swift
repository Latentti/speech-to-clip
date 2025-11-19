//
//  ProfileManager.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 7.2: Implement Profile Model and Management
//

import Foundation

/// Notification names for profile changes
extension Notification.Name {
    /// Posted when profiles are created, updated, or deleted
    static let profilesDidChange = Notification.Name("profilesDidChange")

    /// Posted when the active profile changes
    static let activeProfileDidChange = Notification.Name("activeProfileDidChange")
}

/// Error type for Profile management operations
///
/// Story 7.2 AC 2, 3 - Comprehensive error handling for profile operations
/// Follows KeychainError pattern from Story 7.1 (LocalizedError conformance)
enum ProfileError: Error, LocalizedError {
    case profileNotFound(UUID)
    case duplicateProfileName(String)
    case keychainError(KeychainError)
    case invalidProfileData
    case noActiveProfile
    case invalidPort(Int)

    /// Human-readable error description
    var errorDescription: String? {
        switch self {
        case .profileNotFound(let id):
            return "Profile not found: \(id)"
        case .duplicateProfileName(let name):
            return "A profile named '\(name)' already exists"
        case .keychainError(let error):
            return "Keychain error: \(error.localizedDescription)"
        case .invalidProfileData:
            return "Profile data is corrupted or invalid"
        case .noActiveProfile:
            return "No active profile selected"
        case .invalidPort(let port):
            return "Invalid server port: \(port). Port must be between 1024-65535."
        }
    }

    /// Recovery suggestion for the error
    var recoverySuggestion: String? {
        switch self {
        case .profileNotFound:
            return "Create a new profile in Settings"
        case .duplicateProfileName:
            return "Choose a different name for your profile"
        case .keychainError:
            return "Check your Keychain settings or create a new profile"
        case .invalidProfileData:
            return "Reset profiles in Settings"
        case .noActiveProfile:
            return "Select an active profile in Settings"
        case .invalidPort:
            return "Choose a port number between 1024 and 65535"
        }
    }
}

/// Service for managing user profiles and API keys
///
/// Coordinates profile metadata storage (UserDefaults) with secure API key
/// storage (Keychain via KeychainService). Provides CRUD operations and
/// active profile management.
///
/// **Data Storage Strategy:**
/// - UserDefaults key "profiles": Array of Profile (metadata only)
/// - UserDefaults key "activeProfileID": UUID of active profile
/// - Keychain: API keys via KeychainService (one per profile UUID)
///
/// **Usage:**
/// ```swift
/// let manager = ProfileManager()
///
/// // Create profile with API key
/// let profile = try manager.createProfile(
///     name: "Work",
///     apiKey: "sk-...",
///     language: "en"
/// )
///
/// // Set as active
/// try manager.setActiveProfile(id: profile.id)
///
/// // Retrieve active profile
/// if let active = try manager.getActiveProfile() {
///     print("Active: \(active.name)")
/// }
/// ```
///
/// - Note: Story 7.2 AC 2, 3 - Profile management with UserDefaults + Keychain
class ProfileManager {
    // MARK: - Properties

    /// Keychain service for secure API key storage
    private let keychainService: KeychainService

    /// UserDefaults for profile metadata storage
    private let userDefaults: UserDefaults

    /// UserDefaults key for profiles array
    private let profilesKey = "profiles"

    /// UserDefaults key for active profile ID
    private let activeProfileIDKey = "activeProfileID"

    // MARK: - Initialization

    /// Create a ProfileManager
    ///
    /// - Parameters:
    ///   - keychainService: Service for Keychain operations (default: new instance)
    ///   - userDefaults: UserDefaults for metadata storage (default: .standard)
    ///
    /// - Note: Dependency injection for testability
    init(
        keychainService: KeychainService = KeychainService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.keychainService = keychainService
        self.userDefaults = userDefaults
    }

    // MARK: - CRUD Operations

    /// Create a new profile with API key
    ///
    /// Creates profile metadata in UserDefaults and stores API key in Keychain.
    /// Both operations must succeed or the entire operation fails atomically.
    ///
    /// - Parameters:
    ///   - name: User-facing profile name
    ///   - apiKey: Whisper API key to store securely
    ///   - language: Default language code (e.g., "en")
    ///   - transcriptionEngine: Transcription engine to use (default: .openai)
    ///   - whisperModelName: Model name for Local Whisper (optional)
    ///   - whisperServerPort: Server port for Local Whisper (default: 8080)
    ///
    /// - Returns: The created Profile
    ///
    /// - Throws:
    ///   - ProfileError.duplicateProfileName: If name already exists
    ///   - ProfileError.invalidPort: If port is outside valid range for Local Whisper
    ///   - ProfileError.keychainError: If API key storage fails
    ///   - ProfileError.invalidProfileData: If profile cannot be saved
    ///
    /// - Note: Story 7.2 AC 3 - createProfile operation
    /// - Note: Story 10.2 AC 1, 3 - Port validation for Local Whisper
    @discardableResult
    func createProfile(
        name: String,
        apiKey: String,
        language: String,
        transcriptionEngine: TranscriptionEngine = .openai,
        whisperModelName: String? = nil,
        whisperServerPort: Int = 8080
    ) throws -> Profile {
        // Check for duplicate name
        let existingProfiles = try getAllProfiles()
        if existingProfiles.contains(where: { $0.name == name }) {
            throw ProfileError.duplicateProfileName(name)
        }

        // Validate Local Whisper configuration (Story 10.2 AC 1)
        if transcriptionEngine == .localWhisper {
            guard (1024...65535).contains(whisperServerPort) else {
                throw ProfileError.invalidPort(whisperServerPort)
            }
        }

        // Create new profile
        let profile = Profile(
            name: name,
            language: language,
            transcriptionEngine: transcriptionEngine,
            whisperModelName: whisperModelName,
            whisperServerPort: whisperServerPort
        )

        // Store API key in Keychain first
        do {
            try keychainService.store(apiKey: apiKey, for: profile.id)
        } catch let error as KeychainError {
            throw ProfileError.keychainError(error)
        }

        // Add to profiles array
        var profiles = existingProfiles
        profiles.append(profile)

        // Save to UserDefaults
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profiles)
            userDefaults.set(data, forKey: profilesKey)
        } catch {
            // Rollback: Remove from Keychain if UserDefaults save fails
            try? keychainService.delete(for: profile.id)
            throw ProfileError.invalidProfileData
        }

        // Post notification that profiles changed
        NotificationCenter.default.post(name: .profilesDidChange, object: nil)

        return profile
    }

    /// Update an existing profile
    ///
    /// Updates profile metadata and/or API key. Only updates provided fields.
    /// Updates updatedAt timestamp automatically.
    ///
    /// - Parameters:
    ///   - id: Profile UUID to update
    ///   - name: New name (optional)
    ///   - apiKey: New API key (optional)
    ///   - language: New language (optional)
    ///   - transcriptionEngine: New transcription engine (optional)
    ///   - whisperModelName: New model name for Local Whisper (optional)
    ///   - whisperServerPort: New server port for Local Whisper (optional)
    ///
    /// - Throws:
    ///   - ProfileError.profileNotFound: If profile doesn't exist
    ///   - ProfileError.duplicateProfileName: If new name conflicts
    ///   - ProfileError.invalidPort: If port is outside valid range for Local Whisper
    ///   - ProfileError.keychainError: If API key update fails
    ///   - ProfileError.invalidProfileData: If save fails
    ///
    /// - Note: Story 7.2 AC 3 - updateProfile operation
    /// - Note: Story 10.2 AC 1, 3 - Port validation for Local Whisper
    func updateProfile(
        id: UUID,
        name: String? = nil,
        apiKey: String? = nil,
        language: String? = nil,
        transcriptionEngine: TranscriptionEngine? = nil,
        whisperModelName: String?? = nil,
        whisperServerPort: Int? = nil
    ) throws {
        var profiles = try getAllProfiles()

        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ProfileError.profileNotFound(id)
        }

        // Check for duplicate name (if changing name)
        if let newName = name, newName != profiles[index].name {
            if profiles.contains(where: { $0.name == newName && $0.id != id }) {
                throw ProfileError.duplicateProfileName(newName)
            }
        }

        // Validate Local Whisper configuration (Story 10.2 AC 1)
        var profile = profiles[index]
        let finalEngine = transcriptionEngine ?? profile.transcriptionEngine
        let finalPort = whisperServerPort ?? profile.whisperServerPort

        if finalEngine == .localWhisper {
            guard (1024...65535).contains(finalPort) else {
                throw ProfileError.invalidPort(finalPort)
            }
        }

        // Update API key in Keychain if provided
        if let newApiKey = apiKey {
            do {
                // Delete old key and store new one
                try keychainService.delete(for: id)
                try keychainService.store(apiKey: newApiKey, for: id)
            } catch let error as KeychainError {
                throw ProfileError.keychainError(error)
            }
        }

        // Update profile metadata
        if let newName = name { profile.name = newName }
        if let newLanguage = language { profile.language = newLanguage }
        if let newEngine = transcriptionEngine { profile.transcriptionEngine = newEngine }
        if let newModelName = whisperModelName { profile.whisperModelName = newModelName }
        if let newPort = whisperServerPort { profile.whisperServerPort = newPort }
        profile.updatedAt = Date()

        profiles[index] = profile

        // Save to UserDefaults
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profiles)
            userDefaults.set(data, forKey: profilesKey)
        } catch {
            throw ProfileError.invalidProfileData
        }

        // Post notification that profiles changed
        NotificationCenter.default.post(name: .profilesDidChange, object: nil)
    }

    /// Delete a profile
    ///
    /// Removes profile from UserDefaults and API key from Keychain.
    /// If the deleted profile is active, clears active profile selection.
    ///
    /// - Parameter id: Profile UUID to delete
    ///
    /// - Throws:
    ///   - ProfileError.profileNotFound: If profile doesn't exist
    ///   - ProfileError.keychainError: If Keychain deletion fails
    ///   - ProfileError.invalidProfileData: If save fails
    ///
    /// - Note: Story 7.2 AC 3 - deleteProfile operation
    func deleteProfile(id: UUID) throws {
        var profiles = try getAllProfiles()

        guard profiles.contains(where: { $0.id == id }) else {
            throw ProfileError.profileNotFound(id)
        }

        // Remove from profiles array
        profiles.removeAll(where: { $0.id == id })

        // Delete from Keychain
        do {
            try keychainService.delete(for: id)
        } catch let error as KeychainError {
            throw ProfileError.keychainError(error)
        }

        // Save to UserDefaults
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profiles)
            userDefaults.set(data, forKey: profilesKey)
        } catch {
            throw ProfileError.invalidProfileData
        }

        // Clear active profile if this was the active one
        if let activeID = userDefaults.string(forKey: activeProfileIDKey),
           UUID(uuidString: activeID) == id {
            userDefaults.removeObject(forKey: activeProfileIDKey)
            NotificationCenter.default.post(name: .activeProfileDidChange, object: nil)
        }

        // Post notification that profiles changed
        NotificationCenter.default.post(name: .profilesDidChange, object: nil)
    }

    /// Get all profiles
    ///
    /// Retrieves all profile metadata from UserDefaults.
    /// Does not include API keys (use KeychainService directly for that).
    ///
    /// - Returns: Array of profiles (empty if none exist)
    ///
    /// - Throws:
    ///   - ProfileError.invalidProfileData: If data is corrupted
    ///
    /// - Note: Story 7.2 AC 3 - getAllProfiles operation
    func getAllProfiles() throws -> [Profile] {
        guard let data = userDefaults.data(forKey: profilesKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Profile].self, from: data)
        } catch {
            throw ProfileError.invalidProfileData
        }
    }

    // MARK: - Active Profile Management

    /// Get the currently active profile
    ///
    /// Returns the profile marked as active in UserDefaults.
    ///
    /// - Returns: Active Profile, or nil if no active profile
    ///
    /// - Throws:
    ///   - ProfileError.invalidProfileData: If profile data is corrupted
    ///
    /// - Note: Story 7.2 AC 3 - getActiveProfile operation
    func getActiveProfile() throws -> Profile? {
        guard let activeIDString = userDefaults.string(forKey: activeProfileIDKey),
              let activeID = UUID(uuidString: activeIDString) else {
            return nil
        }

        let profiles = try getAllProfiles()
        return profiles.first(where: { $0.id == activeID })
    }

    /// Set the active profile
    ///
    /// Marks the specified profile as active in UserDefaults.
    ///
    /// - Parameter id: Profile UUID to set as active
    ///
    /// - Throws:
    ///   - ProfileError.profileNotFound: If profile doesn't exist
    ///   - ProfileError.invalidProfileData: If profile data is corrupted
    ///
    /// - Note: Story 7.2 AC 3 - setActiveProfile operation
    func setActiveProfile(id: UUID) throws {
        let profiles = try getAllProfiles()

        guard profiles.contains(where: { $0.id == id }) else {
            throw ProfileError.profileNotFound(id)
        }

        userDefaults.set(id.uuidString, forKey: activeProfileIDKey)

        // Post notification that active profile changed
        NotificationCenter.default.post(name: .activeProfileDidChange, object: nil)
    }
}
