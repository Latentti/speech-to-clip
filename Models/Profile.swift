//
//  Profile.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 7.2: Implement Profile Model and Management
//

import Foundation

/// Transcription engine type for profile configuration
///
/// Specifies which transcription service a profile should use.
/// Each profile can be configured with either cloud-based (OpenAI API)
/// or local (whisper.cpp) transcription.
///
/// **Usage:**
/// ```swift
/// let profile = Profile(
///     name: "Work",
///     language: "en",
///     transcriptionEngine: .openai
/// )
/// ```
///
/// - Note: Story 10.1 AC - TranscriptionEngine enum with String, Codable, CaseIterable conformance
enum TranscriptionEngine: String, Codable, CaseIterable {
    /// Cloud-based transcription via OpenAI Whisper API
    case openai = "OpenAI API"

    /// Local transcription via whisper.cpp server
    case localWhisper = "Local Whisper"
}

/// API key profile model
///
/// Represents a user profile containing API key metadata and language preferences.
/// Profile metadata is stored in UserDefaults while API keys are securely stored
/// in Keychain via KeychainService (Story 7.1).
///
/// **Data Separation:**
/// - UserDefaults: id, name, language, createdAt, updatedAt, transcriptionEngine, whisperModelName, whisperServerPort
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

    // MARK: - Transcription Engine Configuration (Story 10.1)

    /// Transcription engine to use for this profile
    ///
    /// Defaults to `.openai` for backward compatibility with existing profiles.
    /// Can be set to `.localWhisper` to use local whisper.cpp server instead.
    ///
    /// - Note: Story 10.1 AC - transcriptionEngine field with default .openai
    var transcriptionEngine: TranscriptionEngine = .openai

    /// Model name for Local Whisper transcription
    ///
    /// Used only when `transcriptionEngine == .localWhisper`.
    /// If nil, runtime will default to "base" model.
    /// Common values: "tiny", "base", "small", "medium", "large"
    ///
    /// - Note: Story 10.1 AC - whisperModelName optional field
    var whisperModelName: String? = nil

    /// Server port for Local Whisper (whisper.cpp)
    ///
    /// Used only when `transcriptionEngine == .localWhisper`.
    /// Defaults to 8080, the standard whisper.cpp server port.
    ///
    /// - Note: Story 10.1 AC - whisperServerPort field with default 8080
    var whisperServerPort: Int = 8080

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
    ///   - transcriptionEngine: Transcription engine to use (defaults to .openai)
    ///   - whisperModelName: Model name for Local Whisper (optional, defaults to nil)
    ///   - whisperServerPort: Server port for Local Whisper (defaults to 8080)
    ///
    /// - Note: Story 10.1 - Updated init to include new transcription engine fields
    init(
        id: UUID = UUID(),
        name: String,
        language: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        transcriptionEngine: TranscriptionEngine = .openai,
        whisperModelName: String? = nil,
        whisperServerPort: Int = 8080
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transcriptionEngine = transcriptionEngine
        self.whisperModelName = whisperModelName
        self.whisperServerPort = whisperServerPort
    }

    // MARK: - Codable (Story 10.1 - Backward Compatibility)

    /// Coding keys for Codable conformance
    ///
    /// Required when implementing custom encode/decode methods.
    private enum CodingKeys: String, CodingKey {
        case id, name, language, createdAt, updatedAt
        case transcriptionEngine, whisperModelName, whisperServerPort
    }

    /// Custom Codable implementation for backward compatibility
    ///
    /// Ensures old profiles (without transcription engine fields) decode
    /// with default values (.openai, nil, 8080).
    ///
    /// - Note: Story 10.1 AC - Backward compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode required fields
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        language = try container.decode(String.self, forKey: .language)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Decode transcription engine fields with defaults for backward compatibility
        transcriptionEngine = try container.decodeIfPresent(TranscriptionEngine.self, forKey: .transcriptionEngine) ?? .openai
        whisperModelName = try container.decodeIfPresent(String.self, forKey: .whisperModelName)
        whisperServerPort = try container.decodeIfPresent(Int.self, forKey: .whisperServerPort) ?? 8080
    }

    /// Custom encode implementation for symmetric Codable conformance
    ///
    /// Encodes all Profile fields explicitly to match the custom decoder.
    /// This ensures consistent serialization behavior.
    ///
    /// - Note: Story 10.1 Review Follow-up - Symmetric Codable implementation
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode all fields
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(language, forKey: .language)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)

        // Encode transcription engine fields
        try container.encode(transcriptionEngine, forKey: .transcriptionEngine)
        try container.encodeIfPresent(whisperModelName, forKey: .whisperModelName)
        try container.encode(whisperServerPort, forKey: .whisperServerPort)
    }
}
