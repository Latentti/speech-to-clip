//
//  AppSettings.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 1.4: Implement Central AppState
//

import Foundation

/// User preferences and configuration settings
///
/// This model is persisted via SettingsService using UserDefaults.
/// Codable conformance enables easy serialization/deserialization.
struct AppSettings: Codable {
    /// UUID of the currently active API key profile
    /// nil indicates no profile is selected (initial state)
    var activeProfileID: UUID? = nil

    /// Enable translation mode (uses /v1/audio/translations instead of /transcriptions)
    /// When enabled, audio in ANY language is transcribed and translated to English
    /// Note: Whisper /translations endpoint always outputs English
    var enableTranslation: Bool = false

    /// Whether the app should launch automatically at system login
    var launchAtLogin: Bool = false

    /// Whether to show system notifications for transcription results
    var showNotifications: Bool = true

    /// Global hotkey configuration
    /// Story 6.3: Customizable hotkey for starting/stopping recording
    /// Default: Control+Space
    var hotkey: HotkeyConfig = .default

    /// Story 8.2: Tracks whether the user has completed the onboarding flow
    /// Once true, the onboarding window will not be shown again on launch
    var onboardingCompleted: Bool = false

    /// Story 8.2: Tracks whether the user has completed the first-recording tutorial
    /// Used by Story 8.4 to determine if tutorial UI should be shown
    var tutorialCompleted: Bool = false

    /// Story 8.2: Onboarding version identifier for future migration support
    /// If onboarding flow changes significantly, version mismatch can trigger re-onboarding
    var onboardingVersion: String = "1.0"

    /// Default transcription language for new profiles
    /// Story 8.2: Set during onboarding, used as default for API calls when no profile is active
    var defaultLanguage: WhisperLanguage = .english

    /// Story 11.5-1: Enable AI proofreading of transcribed text
    /// When enabled, text is sent to GPT-4o-mini for spelling, punctuation, and capitalization corrections
    /// Default: false (non-breaking for existing users)
    var enableProofreading: Bool = false

    /// Story 11.5-1: Profile ID to use for proofreading API key
    /// If nil, will use first available OpenAI profile or show error if none exist
    /// References a Profile with transcriptionEngine == .openai
    var proofreadingProfileId: UUID? = nil

    // MARK: - Codable (Story 11.5-1 - Backward Compatibility)

    /// Coding keys for Codable conformance
    ///
    /// Required when implementing custom encode/decode methods.
    private enum CodingKeys: String, CodingKey {
        case activeProfileID, enableTranslation, launchAtLogin, showNotifications
        case hotkey, onboardingCompleted, tutorialCompleted, onboardingVersion
        case defaultLanguage, enableProofreading, proofreadingProfileId
    }

    /// Custom Codable implementation for backward compatibility
    ///
    /// Ensures old settings (without proofreading fields) decode
    /// with default values (false, nil).
    ///
    /// - Note: Story 11.5-1 AC 3 - Backward compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode required fields with defaults for backward compatibility
        activeProfileID = try container.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        enableTranslation = try container.decodeIfPresent(Bool.self, forKey: .enableTranslation) ?? false
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? true
        hotkey = try container.decodeIfPresent(HotkeyConfig.self, forKey: .hotkey) ?? .default
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        tutorialCompleted = try container.decodeIfPresent(Bool.self, forKey: .tutorialCompleted) ?? false
        onboardingVersion = try container.decodeIfPresent(String.self, forKey: .onboardingVersion) ?? "1.0"
        defaultLanguage = try container.decodeIfPresent(WhisperLanguage.self, forKey: .defaultLanguage) ?? .english

        // Decode proofreading fields with defaults for backward compatibility
        enableProofreading = try container.decodeIfPresent(Bool.self, forKey: .enableProofreading) ?? false
        proofreadingProfileId = try container.decodeIfPresent(UUID.self, forKey: .proofreadingProfileId)
    }

    /// Custom encode implementation for symmetric Codable conformance
    ///
    /// Encodes all AppSettings fields explicitly to match the custom decoder.
    /// This ensures consistent serialization behavior.
    ///
    /// - Note: Story 11.5-1 - Symmetric Codable implementation
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode all fields
        try container.encodeIfPresent(activeProfileID, forKey: .activeProfileID)
        try container.encode(enableTranslation, forKey: .enableTranslation)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(showNotifications, forKey: .showNotifications)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
        try container.encode(tutorialCompleted, forKey: .tutorialCompleted)
        try container.encode(onboardingVersion, forKey: .onboardingVersion)
        try container.encode(defaultLanguage, forKey: .defaultLanguage)

        // Encode proofreading fields
        try container.encode(enableProofreading, forKey: .enableProofreading)
        try container.encodeIfPresent(proofreadingProfileId, forKey: .proofreadingProfileId)
    }

    /// Default initializer with all default values
    init(
        activeProfileID: UUID? = nil,
        enableTranslation: Bool = false,
        launchAtLogin: Bool = false,
        showNotifications: Bool = true,
        hotkey: HotkeyConfig = .default,
        onboardingCompleted: Bool = false,
        tutorialCompleted: Bool = false,
        onboardingVersion: String = "1.0",
        defaultLanguage: WhisperLanguage = .english,
        enableProofreading: Bool = false,
        proofreadingProfileId: UUID? = nil
    ) {
        self.activeProfileID = activeProfileID
        self.enableTranslation = enableTranslation
        self.launchAtLogin = launchAtLogin
        self.showNotifications = showNotifications
        self.hotkey = hotkey
        self.onboardingCompleted = onboardingCompleted
        self.tutorialCompleted = tutorialCompleted
        self.onboardingVersion = onboardingVersion
        self.defaultLanguage = defaultLanguage
        self.enableProofreading = enableProofreading
        self.proofreadingProfileId = proofreadingProfileId
    }
}
