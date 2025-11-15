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

    /// Default initializer with all default values
    init(
        activeProfileID: UUID? = nil,
        enableTranslation: Bool = false,
        launchAtLogin: Bool = false,
        showNotifications: Bool = true,
        hotkey: HotkeyConfig = .default,
        onboardingCompleted: Bool = false,
        tutorialCompleted: Bool = false,
        onboardingVersion: String = "1.0"
    ) {
        self.activeProfileID = activeProfileID
        self.enableTranslation = enableTranslation
        self.launchAtLogin = launchAtLogin
        self.showNotifications = showNotifications
        self.hotkey = hotkey
        self.onboardingCompleted = onboardingCompleted
        self.tutorialCompleted = tutorialCompleted
        self.onboardingVersion = onboardingVersion
    }
}
